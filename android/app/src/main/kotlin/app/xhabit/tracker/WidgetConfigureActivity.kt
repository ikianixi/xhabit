package app.xhabit.tracker

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.text.InputType
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject

/**
 * Native Android AppWidget configuration & reconfiguration activity.
 * Triggered automatically when a user adds a widget OR holds any placed widget and taps
 * Settings/Reconfigure, enabling independent habit/list/theme setup per `appWidgetId`.
 */
class WidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var widgetKind = "adaptive" // "adaptive" | "daily_list" | "todo_list" | "day_mode"
    private var isFa = true
    private var isDarkUi = true

    private var selectedAdaptiveId: String? = null
    private var listUseAll = true
    private val selectedListIds = LinkedHashSet<String>()
    private var todoHideCompleted = false
    private var dayModeIncludeAll = true
    private var selectedThemeMode = "follow"
    private var titleInput: EditText? = null

    private data class HabitItem(
        val id: String,
        val title: String,
        val color: Int,
        val iconCodePoint: Int,
        val style: String,
        val streak: Int,
        val isDueToday: Boolean,
    )

    private var catalog: List<HabitItem> = emptyList()

    private val habitRowContainers = ArrayList<LinearLayout>()
    private val habitRowIndicators = ArrayList<View>()
    private var themeChipViews: List<Pair<String, TextView>> = emptyList()
    private var modeAllChip: TextView? = null
    private var modeManualChip: TextView? = null
    private var todoAllChip: TextView? = null
    private var todoPendingChip: TextView? = null
    private var dayModeIncludeChip: TextView? = null
    private var dayModeOnlyModesChip: TextView? = null
    private var quickActionRow: LinearLayout? = null
    private var listCountBadge: TextView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        val cancelResult = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_CANCELED, cancelResult)

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val prefs = getSharedPreferences(WidgetConfigStore.PREFS_NAME, MODE_PRIVATE)
        isFa = (prefs.getString("widget_locale", "fa") ?: "fa") == "fa"
        isDarkUi = (prefs.getString("widget_theme", "dark") ?: "dark") == "dark"

        val manager = AppWidgetManager.getInstance(this)
        val providerName = manager.getAppWidgetInfo(appWidgetId)?.provider?.className
        widgetKind = when (providerName) {
            DailyListWidgetProvider::class.java.name -> "daily_list"
            ToDoListWidgetProvider::class.java.name -> "todo_list"
            DayModeWidgetProvider::class.java.name -> "day_mode"
            AdaptiveHabitWidgetProvider::class.java.name -> "adaptive"
            else -> intent?.getStringExtra("widget_kind") ?: "adaptive"
        }

        catalog = loadCatalog(prefs)
        loadExistingConfig(prefs)

        configureSystemBars()
        setContentView(buildContentView())
    }

    private fun loadCatalog(prefs: android.content.SharedPreferences): List<HabitItem> {
        val listRoot = WidgetConfigStore.readDailyListCatalog(prefs)
        val arr = listRoot.optJSONArray("allHabits")
        if (arr != null && arr.length() > 0) {
            val out = ArrayList<HabitItem>(arr.length())
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val id = o.optString("id", "")
                if (id.isEmpty()) continue
                out.add(
                    HabitItem(
                        id = id,
                        title = o.optString("title", "XHabit"),
                        color = o.optInt("color", Color.parseColor("#84CC16")),
                        iconCodePoint = o.optInt("iconCodePoint", 0),
                        style = o.optString("style", "boolean"),
                        streak = o.optInt("streak", 0),
                        isDueToday = o.optBoolean("isDueToday", true),
                    ),
                )
            }
            return out
        }

        val adList = WidgetConfigStore.readAdaptiveHabitsCatalog(prefs)
        return adList.mapNotNull { o ->
            val id = o.optString("id", "")
            if (id.isEmpty()) return@mapNotNull null
            HabitItem(
                id = id,
                title = o.optString("title", "XHabit"),
                color = o.optInt("color", Color.parseColor("#84CC16")),
                iconCodePoint = o.optInt("iconCodePoint", 0),
                style = o.optString("style", "boolean"),
                streak = o.optInt("streak", 0),
                isDueToday = true,
            )
        }
    }

    private fun loadExistingConfig(prefs: android.content.SharedPreferences) {
        selectedThemeMode = WidgetConfigStore.getWidgetThemeMode(prefs, appWidgetId)

        when (widgetKind) {
            "adaptive" -> {
                val existing = WidgetConfigStore.getAdaptiveHabitId(prefs, appWidgetId)
                val pending = if (existing == null) WidgetConfigStore.consumePendingAdaptivePreset(prefs) else null
                val defId = WidgetConfigStore.resolveAdaptiveDefaultId(prefs)
                selectedAdaptiveId = existing ?: pending ?: defId.takeIf { it.isNotEmpty() } ?: catalog.firstOrNull()?.id
            }
            "daily_list" -> {
                val sel = WidgetConfigStore.getDailyListSelection(prefs, appWidgetId)
                if (sel.mode == "default") {
                    val pending = WidgetConfigStore.consumePendingListPreset(prefs)
                    if (pending != null) {
                        listUseAll = pending.mode != "custom"
                        selectedListIds.addAll(pending.selectedIds)
                        initialTitle = pending.customTitle
                    } else {
                        val listRoot = WidgetConfigStore.readDailyListCatalog(prefs)
                        val useDefAll = listRoot.optBoolean("useDefaultAll", true)
                        listUseAll = useDefAll
                        if (!useDefAll) {
                            val defArr = listRoot.optJSONArray("defaultIds") ?: JSONArray()
                            for (i in 0 until defArr.length()) {
                                val id = defArr.optString(i, "")
                                if (id.isNotEmpty()) selectedListIds.add(id)
                            }
                        }
                        initialTitle = sel.customTitle
                    }
                } else {
                    listUseAll = sel.mode == "all"
                    selectedListIds.addAll(sel.selectedIds)
                    initialTitle = sel.customTitle
                }
                if (!listUseAll && selectedListIds.isEmpty()) {
                    catalog.forEach { selectedListIds.add(it.id) }
                }
            }
            "todo_list" -> {
                if (WidgetConfigStore.hasToDoConfig(prefs, appWidgetId)) {
                    todoHideCompleted = WidgetConfigStore.getToDoHideCompleted(prefs, appWidgetId)
                    initialTitle = WidgetConfigStore.getCustomTitle(prefs, appWidgetId)
                } else {
                    val pending = WidgetConfigStore.consumePendingToDoPreset(prefs)
                    if (pending != null) {
                        todoHideCompleted = pending.first
                        initialTitle = pending.second
                    }
                }
            }
            "day_mode" -> {
                if (WidgetConfigStore.hasDayModeConfig(prefs, appWidgetId)) {
                    dayModeIncludeAll = WidgetConfigStore.getDayModeIncludeAll(prefs, appWidgetId)
                } else {
                    dayModeIncludeAll = WidgetConfigStore.consumePendingDayModePreset(prefs) ?: true
                }
            }
        }
    }

    private var initialTitle: String = ""

    private fun dp(v: Float): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        v,
        resources.displayMetrics,
    ).toInt()

    private fun roundedBg(fill: Int, radiusDp: Float, strokeColor: Int = Color.TRANSPARENT, strokeWidthDp: Float = 0f): GradientDrawable {
        return GradientDrawable().apply {
            setColor(fill)
            cornerRadius = dp(radiusDp).toFloat()
            if (strokeColor != Color.TRANSPARENT && strokeWidthDp > 0f) {
                setStroke(dp(strokeWidthDp).coerceAtLeast(1), strokeColor)
            }
        }
    }

    private fun tr(fa: String, en: String): String = if (isFa) fa else en

    private fun styleLabel(style: String): String = when (style) {
        "count" -> tr("هدف شمارشی", "Count goal")
        "checklist" -> tr("چک‌لیست مرحله‌ای", "Checklist")
        else -> tr("ثبت روزانه", "Daily tick")
    }

    @Suppress("DEPRECATION")
    private fun configureSystemBars() {
        val bg = if (isDarkUi) Color.parseColor("#000000") else Color.parseColor("#F5F6F8")
        window.statusBarColor = bg
        window.navigationBarColor = bg
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val flags = window.decorView.systemUiVisibility
            window.decorView.systemUiVisibility = if (isDarkUi) {
                flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
            } else {
                flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            }
        }
    }

    private fun buildContentView(): View {
        val bgCol = if (isDarkUi) Color.parseColor("#000000") else Color.parseColor("#F5F6F8")
        val cardCol = if (isDarkUi) Color.parseColor("#111318") else Color.WHITE
        val card2Col = if (isDarkUi) Color.parseColor("#181B22") else Color.parseColor("#EEF1F5")
        val txtCol = if (isDarkUi) Color.WHITE else Color.parseColor("#0F172A")
        val mutedCol = if (isDarkUi) Color.parseColor("#94A3B8") else Color.parseColor("#64748B")
        val borderCol = if (isDarkUi) Color.parseColor("#242936") else Color.parseColor("#DCE2EC")
        val limeCol = if (isDarkUi) Color.parseColor("#8CFF26") else Color.parseColor("#65A30D")
        val onLimeCol = if (isDarkUi) Color.BLACK else Color.WHITE

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bgCol)
            layoutDirection = if (isFa) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
            fitsSystemWindows = true
        }

        // Top Bar
        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16f), dp(14f), dp(16f), dp(10f))
        }

        val closeBtn = TextView(this).apply {
            text = "✕"
            textSize = 15f
            setTextColor(txtCol)
            gravity = Gravity.CENTER
            background = roundedBg(cardCol, 12f, borderCol, 1f)
            setOnClickListener { finish() }
        }
        topBar.addView(closeBtn, LinearLayout.LayoutParams(dp(38f), dp(38f)))

        val titleCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12f), 0, dp(12f), 0)
        }
        titleCol.addView(
            TextView(this).apply {
                text = when (widgetKind) {
                    "daily_list" -> tr("تنظیم ویجت لیست روزانه", "Configure Daily List Widget")
                    "todo_list" -> tr("تنظیم ویجت لیست کارها", "Configure To Do List Widget")
                    "day_mode" -> tr("تنظیم ویجت مود روزانه", "Configure Day Mode Widget")
                    else -> tr("تنظیم ویجت تطبیق‌پذیر", "Configure Adaptive Widget")
                }
                textSize = 16.5f
                setTextColor(txtCol)
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 2)
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
            },
        )
        titleCol.addView(
            TextView(this).apply {
                text = when (widgetKind) {
                    "daily_list" -> tr("انتخاب مستقل عادت‌ها و عنوان برای این ویجت (#$appWidgetId)", "Independent habits & label for widget #$appWidgetId")
                    "todo_list" -> tr("تنظیم فیلتر و عنوان لیست کارها برای ویجت #$appWidgetId", "Filter & title for To Do widget #$appWidgetId")
                    "day_mode" -> tr("تنظیمات سوییچر سریع مود روزانه (#$appWidgetId)", "Quick Day Mode switcher settings (#$appWidgetId)")
                    else -> tr("تعیین عادت اختصاصی این ویجت (#$appWidgetId)", "Dedicated habit for widget #$appWidgetId")
                }
                textSize = 11.5f
                setTextColor(mutedCol)
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 0)
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
            },
        )
        topBar.addView(titleCol, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        root.addView(topBar)

        val needsHabitCatalog = widgetKind == "adaptive" || widgetKind == "daily_list"
        if (needsHabitCatalog && catalog.isEmpty()) {
            val emptyBox = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(dp(24f), dp(28f), dp(24f), dp(28f))
                background = roundedBg(cardCol, 18f, borderCol, 1f)
            }
            emptyBox.addView(
                TextView(this).apply {
                    text = tr(
                        "هنوز عادتی در XHabit ساخته نشده است.\nابتدا وارد برنامه شوید و حداقل یک عادت بسازید تا بتوانید آن را روی ویجت نمایش دهید.",
                        "You haven't created any habits yet.\nOpen XHabit to add a habit first, then configure this widget.",
                    )
                    textSize = 13.5f
                    setTextColor(mutedCol)
                    gravity = Gravity.CENTER
                    typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 0)
                },
            )
            val openAppBtn = TextView(this).apply {
                text = tr("باز کردن XHabit", "Open XHabit")
                textSize = 13.5f
                setTextColor(onLimeCol)
                gravity = Gravity.CENTER
                setPadding(dp(18f), dp(12f), dp(18f), dp(12f))
                background = roundedBg(limeCol, 13f)
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 2)
                setOnClickListener {
                    startActivity(
                        Intent(this@WidgetConfigureActivity, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        },
                    )
                    finish()
                }
            }
            val btnLp = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(18f)
            }
            emptyBox.addView(openAppBtn, btnLp)

            val padLp = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                setMargins(dp(16f), dp(36f), dp(16f), dp(16f))
            }
            root.addView(emptyBox, padLp)
            return root
        }

        // Scrollable Body
        val scroll = ScrollView(this).apply {
            isFillViewport = true
        }
        val body = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16f), dp(4f), dp(16f), dp(18f))
        }

        // Theme Override Card (compact single row)
        val themeCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14f), dp(12f), dp(14f), dp(12f))
            background = roundedBg(cardCol, 16f, borderCol, 1f)
        }
        themeCard.addView(
            TextView(this).apply {
                text = tr("پوسته این ویجت", "Widget Appearance")
                textSize = 12f
                setTextColor(mutedCol)
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
            },
        )
        val themeRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(8f), 0, 0)
        }
        val themeOptions = listOf(
            "follow" to tr("همگام با اپ", "Auto"),
            "dark" to tr("تیره", "Dark"),
            "light" to tr("روشن", "Light"),
        )
        val builtThemeChips = ArrayList<Pair<String, TextView>>()
        themeOptions.forEachIndexed { idx, (key, label) ->
            val chip = TextView(this).apply {
                text = label
                textSize = 12f
                gravity = Gravity.CENTER
                setPadding(dp(8f), dp(8f), dp(8f), dp(8f))
                typeface = WidgetCanvasHelper.typefaceForText(context, label, 1)
                setOnClickListener {
                    selectedThemeMode = key
                    refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
                }
            }
            val lp = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                if (idx > 0) marginStart = dp(6f)
            }
            themeRow.addView(chip, lp)
            builtThemeChips.add(key to chip)
        }
        themeChipViews = builtThemeChips
        themeCard.addView(themeRow)
        body.addView(
            themeCard,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                bottomMargin = dp(10f)
            },
        )

        // Daily List extra controls: Custom title + All/Manual toggle
        if (widgetKind == "daily_list") {
            val listCard = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(14f), dp(12f), dp(14f), dp(12f))
                background = roundedBg(cardCol, 16f, borderCol, 1f)
            }
            listCard.addView(
                TextView(this).apply {
                    text = tr("عنوان بالای ویجت (اختیاری)", "Widget Header Title (Optional)")
                    textSize = 12f
                    setTextColor(mutedCol)
                    typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                },
            )
            val et = EditText(this).apply {
                setText(initialTitle)
                hint = tr("مثلاً: برنامه صبح (پیش‌فرض: امروز)", "e.g. Morning Routine (default: Today)")
                setHintTextColor(mutedCol)
                setTextColor(txtCol)
                textSize = 13f
                inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
                setSingleLine(true)
                setPadding(dp(12f), dp(10f), dp(12f), dp(10f))
                background = roundedBg(card2Col, 11f, borderCol, 1f)
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString().ifEmpty { hint.toString() }, 0)
            }
            titleInput = et
            listCard.addView(
                et,
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    topMargin = dp(8f)
                    bottomMargin = dp(12f)
                },
            )

            listCard.addView(
                TextView(this).apply {
                    text = tr("محتوای نمایشی ویجت", "Habits to Display")
                    textSize = 12f
                    setTextColor(mutedCol)
                    typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                },
            )
            val modeRow = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, dp(8f), 0, 0)
            }
            modeAllChip = TextView(this).apply {
                text = tr("همه عادت‌های امروز", "All Due Today")
                textSize = 12f
                gravity = Gravity.CENTER
                setPadding(dp(8f), dp(9f), dp(8f), dp(9f))
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                setOnClickListener {
                    listUseAll = true
                    refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
                }
            }
            modeManualChip = TextView(this).apply {
                text = tr("انتخاب دستی", "Pick Specific")
                textSize = 12f
                gravity = Gravity.CENTER
                setPadding(dp(8f), dp(9f), dp(8f), dp(9f))
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                setOnClickListener {
                    listUseAll = false
                    refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
                }
            }
            modeRow.addView(modeAllChip, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            modeRow.addView(
                modeManualChip,
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginStart = dp(6f)
                },
            )
            listCard.addView(modeRow)
            body.addView(
                listCard,
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    bottomMargin = dp(12f)
                },
            )
        }

        // To-Do List controls: Optional custom title + Show all vs Pending only
        if (widgetKind == "todo_list") {
            val todoCard = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(14f), dp(12f), dp(14f), dp(12f))
                background = roundedBg(cardCol, 16f, borderCol, 1f)
            }
            todoCard.addView(
                TextView(this).apply {
                    text = tr("عنوان بالای ویجت (اختیاری)", "Widget Header Title (Optional)")
                    textSize = 12f
                    setTextColor(mutedCol)
                    typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                },
            )
            val et = EditText(this).apply {
                setText(initialTitle)
                hint = tr("مثلاً: کارهای فوری (پیش‌فرض: لیست کارها)", "e.g. Errands (default: To Do List)")
                setHintTextColor(mutedCol)
                setTextColor(txtCol)
                textSize = 13f
                inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
                setSingleLine(true)
                setPadding(dp(12f), dp(10f), dp(12f), dp(10f))
                background = roundedBg(card2Col, 11f, borderCol, 1f)
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString().ifEmpty { hint.toString() }, 0)
            }
            titleInput = et
            todoCard.addView(
                et,
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    topMargin = dp(8f)
                    bottomMargin = dp(12f)
                },
            )
            todoCard.addView(
                TextView(this).apply {
                    text = tr("فیلتر نمایش کارها", "Tasks Display Filter")
                    textSize = 12f
                    setTextColor(mutedCol)
                    typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                },
            )
            val modeRow = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, dp(8f), 0, 0)
            }
            todoAllChip = TextView(this).apply {
                text = tr("نمایش همه کارها", "Show All Tasks")
                textSize = 12f
                gravity = Gravity.CENTER
                setPadding(dp(8f), dp(9f), dp(8f), dp(9f))
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                setOnClickListener {
                    todoHideCompleted = false
                    refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
                }
            }
            todoPendingChip = TextView(this).apply {
                text = tr("فقط کارهای باقیمانده", "Pending Only")
                textSize = 12f
                gravity = Gravity.CENTER
                setPadding(dp(8f), dp(9f), dp(8f), dp(9f))
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                setOnClickListener {
                    todoHideCompleted = true
                    refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
                }
            }
            modeRow.addView(todoAllChip, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            modeRow.addView(
                todoPendingChip,
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginStart = dp(6f)
                },
            )
            todoCard.addView(modeRow)
            body.addView(
                todoCard,
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    bottomMargin = dp(12f)
                },
            )
        }

        // Quick Day Mode Switcher controls
        if (widgetKind == "day_mode") {
            val dmCard = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(14f), dp(12f), dp(14f), dp(12f))
                background = roundedBg(cardCol, 16f, borderCol, 1f)
            }
            dmCard.addView(
                TextView(this).apply {
                    text = tr("گزینه‌های جابه‌جایی سریع با فلش‌ها", "Quick Arrow Cycling Options")
                    textSize = 12f
                    setTextColor(mutedCol)
                    typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                },
            )
            val dmRow = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, dp(8f), 0, 0)
            }
            dayModeIncludeChip = TextView(this).apply {
                text = tr("شامل «همه مودها»", "Include 'All Modes'")
                textSize = 12f
                gravity = Gravity.CENTER
                setPadding(dp(8f), dp(9f), dp(8f), dp(9f))
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                setOnClickListener {
                    dayModeIncludeAll = true
                    refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
                }
            }
            dayModeOnlyModesChip = TextView(this).apply {
                text = tr("فقط مودهای فعال", "Active Modes Only")
                textSize = 12f
                gravity = Gravity.CENTER
                setPadding(dp(8f), dp(9f), dp(8f), dp(9f))
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                setOnClickListener {
                    dayModeIncludeAll = false
                    refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
                }
            }
            dmRow.addView(dayModeIncludeChip, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            dmRow.addView(
                dayModeOnlyModesChip,
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginStart = dp(6f)
                },
            )
            dmCard.addView(dmRow)
            dmCard.addView(
                TextView(this).apply {
                    text = tr(
                        "با زدن فلش‌های چپ و راست روی این ویجت، مود روزانه بلافاصله تغییر کرده و لیست عادت‌های ویجت‌های خانه نیز هماهنگ می‌شود.",
                        "Tapping left/right arrows immediately switches your active Day Mode and updates your Home Screen Daily List widgets.",
                    )
                    textSize = 11f
                    setTextColor(mutedCol)
                    setPadding(0, dp(10f), 0, 0)
                    typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 0)
                },
            )
            body.addView(
                dmCard,
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    bottomMargin = dp(12f)
                },
            )
        }

        // Section Header + Habit Selection (only for Adaptive & Daily List)
        habitRowContainers.clear()
        habitRowIndicators.clear()
        if (needsHabitCatalog) {
        val secHeader = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(2f), dp(4f), dp(2f), dp(8f))
        }
        secHeader.addView(
            TextView(this).apply {
                text = if (widgetKind == "daily_list") {
                    tr("فهرست عادت‌ها", "Habits List")
                } else {
                    tr("عادت مورد نظر را انتخاب کنید", "Select Habit")
                }
                textSize = 13f
                setTextColor(txtCol)
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 2)
            },
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        if (widgetKind == "daily_list") {
            listCountBadge = TextView(this).apply {
                textSize = 11.5f
                setTextColor(mutedCol)
                typeface = WidgetCanvasHelper.typefaceForText(context, "0", 1)
            }
            secHeader.addView(listCountBadge)
        }
        body.addView(secHeader)

        if (widgetKind == "daily_list") {
            val qRow = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, 0, 0, dp(8f))
            }
            val selectAllBtn = TextView(this).apply {
                text = tr("انتخاب همه", "Select All")
                textSize = 11.5f
                setTextColor(txtCol)
                setPadding(dp(12f), dp(6f), dp(12f), dp(6f))
                background = roundedBg(cardCol, 10f, borderCol, 1f)
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                setOnClickListener {
                    listUseAll = false
                    catalog.forEach { selectedListIds.add(it.id) }
                    refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
                }
            }
            val clearBtn = TextView(this).apply {
                text = tr("پاک کردن انتخاب", "Clear")
                textSize = 11.5f
                setTextColor(mutedCol)
                setPadding(dp(12f), dp(6f), dp(12f), dp(6f))
                background = roundedBg(cardCol, 10f, borderCol, 1f)
                typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 1)
                setOnClickListener {
                    listUseAll = false
                    selectedListIds.clear()
                    refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
                }
            }
            qRow.addView(selectAllBtn)
            qRow.addView(
                clearBtn,
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    marginStart = dp(8f)
                },
            )
            quickActionRow = qRow
            body.addView(qRow)
        }

        // Habit Selection Rows
        for (h in catalog) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(12f), dp(11f), dp(12f), dp(11f))
                tag = h.id
                setOnClickListener {
                    if (widgetKind != "daily_list") {
                        selectedAdaptiveId = h.id
                    } else {
                        listUseAll = false
                        if (selectedListIds.contains(h.id)) {
                            selectedListIds.remove(h.id)
                        } else {
                            selectedListIds.add(h.id)
                        }
                    }
                    refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
                }
            }

            val iconView = ImageView(this).apply {
                setImageBitmap(
                    WidgetCanvasHelper.renderHabitIconBadgeBitmap(
                        context = this@WidgetConfigureActivity,
                        accent = h.color,
                        iconCodePoint = h.iconCodePoint,
                        dpSize = 32f,
                    ),
                )
            }
            row.addView(iconView, LinearLayout.LayoutParams(dp(32f), dp(32f)))

            val txtBox = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(10f), 0, dp(10f), 0)
            }
            txtBox.addView(
                TextView(this).apply {
                    text = h.title
                    textSize = 13.5f
                    setTextColor(txtCol)
                    typeface = WidgetCanvasHelper.typefaceForText(context, h.title, 1)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                },
            )
            val subText = if (widgetKind == "daily_list") {
                styleLabel(h.style) + if (!h.isDueToday) tr(" • خارج از برنامه امروز", " • off today") else ""
            } else {
                val streakPart = if (h.streak > 0) tr(" • استریک ${h.streak} روز", " • ${h.streak}d streak") else ""
                styleLabel(h.style) + streakPart
            }
            txtBox.addView(
                TextView(this).apply {
                    text = subText
                    textSize = 11f
                    setTextColor(mutedCol)
                    typeface = WidgetCanvasHelper.typefaceForText(context, subText, 0)
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                },
            )
            row.addView(txtBox, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

            val checkBox = TextView(this).apply {
                gravity = Gravity.CENTER
                textSize = 12f
                typeface = WidgetCanvasHelper.typefaceForText(context, "✓", 2)
            }
            row.addView(checkBox, LinearLayout.LayoutParams(dp(22f), dp(22f)))

            habitRowContainers.add(row)
            habitRowIndicators.add(checkBox)
            body.addView(
                row,
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    bottomMargin = dp(8f)
                },
            )
        }
        }

        scroll.addView(body)
        root.addView(scroll, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))

        // Bottom Save Bar
        val bottomBar = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16f), dp(10f), dp(16f), dp(16f))
            setBackgroundColor(bgCol)
        }
        val saveBtn = TextView(this).apply {
            text = tr("ذخیره و اعمال روی ویجت", "Save & Apply Widget")
            textSize = 14f
            setTextColor(onLimeCol)
            gravity = Gravity.CENTER
            setPadding(dp(16f), dp(13f), dp(16f), dp(13f))
            background = roundedBg(limeCol, 14f)
            typeface = WidgetCanvasHelper.typefaceForText(context, text.toString(), 2)
            setOnClickListener { handleSave() }
        }
        bottomBar.addView(saveBtn, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        root.addView(bottomBar)

        refreshSelectionStates(cardCol, card2Col, txtCol, mutedCol, borderCol, limeCol, onLimeCol)
        return root
    }

    private fun refreshSelectionStates(
        cardCol: Int,
        card2Col: Int,
        txtCol: Int,
        mutedCol: Int,
        borderCol: Int,
        limeCol: Int,
        onLimeCol: Int,
    ) {
        val limeTint = WidgetCanvasHelper.tintWithAlpha(limeCol, 0.14f)
        for ((key, chip) in themeChipViews) {
            val active = selectedThemeMode == key
            chip.background = roundedBg(
                fill = if (active) limeTint else card2Col,
                radiusDp = 10f,
                strokeColor = if (active) limeCol else borderCol,
                strokeWidthDp = 1f,
            )
            chip.setTextColor(if (active) limeCol else txtCol)
        }

        if (widgetKind == "daily_list") {
            modeAllChip?.let { c ->
                c.background = roundedBg(
                    fill = if (listUseAll) limeTint else card2Col,
                    radiusDp = 10f,
                    strokeColor = if (listUseAll) limeCol else borderCol,
                    strokeWidthDp = 1f,
                )
                c.setTextColor(if (listUseAll) limeCol else txtCol)
            }
            modeManualChip?.let { c ->
                c.background = roundedBg(
                    fill = if (!listUseAll) limeTint else card2Col,
                    radiusDp = 10f,
                    strokeColor = if (!listUseAll) limeCol else borderCol,
                    strokeWidthDp = 1f,
                )
                c.setTextColor(if (!listUseAll) limeCol else txtCol)
            }
            quickActionRow?.visibility = if (listUseAll) View.GONE else View.VISIBLE
            listCountBadge?.text = if (listUseAll) {
                tr("خودکار (${catalog.size} عادت)", "Auto (${catalog.size})")
            } else {
                tr("${selectedListIds.size} انتخاب‌شده", "${selectedListIds.size} selected")
            }
        }

        if (widgetKind == "todo_list") {
            todoAllChip?.let { c ->
                c.background = roundedBg(
                    fill = if (!todoHideCompleted) limeTint else card2Col,
                    radiusDp = 10f,
                    strokeColor = if (!todoHideCompleted) limeCol else borderCol,
                    strokeWidthDp = 1f,
                )
                c.setTextColor(if (!todoHideCompleted) limeCol else txtCol)
            }
            todoPendingChip?.let { c ->
                c.background = roundedBg(
                    fill = if (todoHideCompleted) limeTint else card2Col,
                    radiusDp = 10f,
                    strokeColor = if (todoHideCompleted) limeCol else borderCol,
                    strokeWidthDp = 1f,
                )
                c.setTextColor(if (todoHideCompleted) limeCol else txtCol)
            }
        }

        if (widgetKind == "day_mode") {
            dayModeIncludeChip?.let { c ->
                c.background = roundedBg(
                    fill = if (dayModeIncludeAll) limeTint else card2Col,
                    radiusDp = 10f,
                    strokeColor = if (dayModeIncludeAll) limeCol else borderCol,
                    strokeWidthDp = 1f,
                )
                c.setTextColor(if (dayModeIncludeAll) limeCol else txtCol)
            }
            dayModeOnlyModesChip?.let { c ->
                c.background = roundedBg(
                    fill = if (!dayModeIncludeAll) limeTint else card2Col,
                    radiusDp = 10f,
                    strokeColor = if (!dayModeIncludeAll) limeCol else borderCol,
                    strokeWidthDp = 1f,
                )
                c.setTextColor(if (!dayModeIncludeAll) limeCol else txtCol)
            }
        }

        for (i in habitRowContainers.indices) {
            val row = habitRowContainers[i]
            val checkView = habitRowIndicators[i] as TextView
            val h = catalog[i]
            val isList = widgetKind == "daily_list"
            val selected = if (!isList) {
                selectedAdaptiveId == h.id
            } else {
                listUseAll || selectedListIds.contains(h.id)
            }
            val dimAuto = isList && listUseAll
            row.alpha = if (dimAuto) 0.72f else 1f
            row.background = roundedBg(
                fill = if (selected && !dimAuto) WidgetCanvasHelper.tintWithAlpha(h.color, 0.12f) else cardCol,
                radiusDp = 14f,
                strokeColor = if (selected && !dimAuto) h.color else borderCol,
                strokeWidthDp = if (selected && !dimAuto) 1.4f else 1f,
            )
            val radius = if (isList) 7f else 11f
            val checkFill = when {
                selected && !dimAuto -> h.color
                dimAuto -> WidgetCanvasHelper.tintWithAlpha(mutedCol, 0.25f)
                else -> Color.TRANSPARENT
            }
            checkView.background = roundedBg(
                fill = checkFill,
                radiusDp = radius,
                strokeColor = if (selected) Color.TRANSPARENT else borderCol,
                strokeWidthDp = 1.4f,
            )
            checkView.text = if (selected) "✓" else ""
            checkView.setTextColor(
                if (dimAuto) mutedCol else WidgetCanvasHelper.contrastColor(h.color),
            )
        }
    }

    private fun handleSave() {
        when (widgetKind) {
            "adaptive" -> {
                val chosen = selectedAdaptiveId ?: catalog.firstOrNull()?.id
                if (chosen.isNullOrBlank()) {
                    Toast.makeText(
                        this,
                        tr("لطفاً یک عادت انتخاب کنید", "Please select a habit"),
                        Toast.LENGTH_SHORT,
                    ).show()
                    return
                }
                WidgetConfigStore.saveAdaptiveConfig(
                    context = this,
                    widgetId = appWidgetId,
                    habitId = chosen,
                    themeMode = selectedThemeMode,
                )
                AdaptiveHabitWidgetProvider.updateWidgetById(this, appWidgetId)
            }
            "daily_list" -> {
                if (!listUseAll && selectedListIds.isEmpty()) {
                    Toast.makeText(
                        this,
                        tr("حداقل یک عادت انتخاب کنید یا حالت «همه عادت‌های امروز» را بزنید", "Select at least one habit or pick All Due Today"),
                        Toast.LENGTH_SHORT,
                    ).show()
                    return
                }
                val customTitle = titleInput?.text?.toString()?.trim() ?: ""
                WidgetConfigStore.saveDailyListConfig(
                    context = this,
                    widgetId = appWidgetId,
                    useAll = listUseAll,
                    habitIds = selectedListIds.toList(),
                    customTitle = customTitle,
                    themeMode = selectedThemeMode,
                )
                DailyListWidgetProvider.updateWidgetById(this, appWidgetId)
            }
            "todo_list" -> {
                val customTitle = titleInput?.text?.toString()?.trim() ?: ""
                WidgetConfigStore.saveToDoListConfig(
                    context = this,
                    widgetId = appWidgetId,
                    hideCompleted = todoHideCompleted,
                    customTitle = customTitle,
                    themeMode = selectedThemeMode,
                )
                ToDoListWidgetProvider.updateWidgetById(this, appWidgetId)
            }
            "day_mode" -> {
                WidgetConfigStore.saveDayModeConfig(
                    context = this,
                    widgetId = appWidgetId,
                    includeAll = dayModeIncludeAll,
                    themeMode = selectedThemeMode,
                )
                DayModeWidgetProvider.updateWidgetById(this, appWidgetId)
            }
        }

        val resIntent = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resIntent)
        finish()
    }
}
