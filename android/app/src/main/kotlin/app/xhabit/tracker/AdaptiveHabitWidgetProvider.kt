package app.xhabit.tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.min

class AdaptiveHabitWidgetProvider : HomeWidgetProvider() {

    companion object {
        fun updateWidgetById(context: Context, widgetId: Int) {
            val manager = AppWidgetManager.getInstance(context)
            val prefs = context.getSharedPreferences(WidgetConfigStore.PREFS_NAME, Context.MODE_PRIVATE)
            val options = manager.getAppWidgetOptions(widgetId)
            AdaptiveHabitWidgetProvider().updateOne(context, manager, widgetId, prefs, options)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            updateOne(context, appWidgetManager, widgetId, widgetData, options)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        WidgetConfigStore.cleanupDeletedWidgets(context, appWidgetIds)
        super.onDeleted(context, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val prefs = context.getSharedPreferences(WidgetConfigStore.PREFS_NAME, Context.MODE_PRIVATE)
        updateOne(context, appWidgetManager, appWidgetId, prefs, newOptions)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun resolveWidgetDp(context: Context, options: Bundle): Pair<Float, Float> {
        val isLand = context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            if (!sizes.isNullOrEmpty()) {
                val chosen = if (sizes.size > 1) {
                    if (isLand) sizes.maxByOrNull { it.width } else sizes.minByOrNull { it.width }
                } else {
                    sizes[0]
                }
                if (chosen != null && chosen.width > 0f && chosen.height > 0f) {
                    return chosen.width to chosen.height
                }
            }
        }
        val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 160).toFloat()
        val maxW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minW.toInt()).toFloat()
        val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 80).toFloat()
        val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minH.toInt()).toFloat()
        return if (isLand) (maxW to minH) else (minW to maxH)
    }

    private fun updateOne(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
        options: Bundle,
    ) {
        val (cardW, cardH) = resolveWidgetDp(context, options)
        val aspect = cardH / cardW.coerceAtLeast(1f)

        // Strict aspect + dp grid classification:
        // - <= 4x2 (2x1, 3x1, 4x1, 2x2, 3x2, 4x2) -> NEVER has KPI footer
        // - 4x3 -> 18-week heatmap + KPI footer (no checklist sub-steps)
        // - 4x4 -> 18-week heatmap + KPI footer + clickable checklist sub-steps (if checklist habit)
        val cols = when {
            cardW >= 230f -> 4
            cardW >= 195f -> 3
            else -> 2
        }
        val mode = when (cols) {
            2 -> if (cardH >= 120f) "2x2" else "2x1"
            3 -> when {
                cardH < 120f -> "3x1"
                else -> "3x2"
            }
            else -> when {
                cardH < 125f -> "4x1"
                cardH >= 325f || (cardH >= 280f && aspect >= 1.06f) -> "4x4"
                cardH >= 235f -> "4x3"
                else -> "4x2"
            }
        }

        val isLight = WidgetConfigStore.resolveIsLight(widgetData, widgetId)
        val pillRes = if (isLight) R.drawable.widget_pill_light else R.drawable.widget_pill_dark
        val txtMain = if (isLight) Color.parseColor("#0F172A") else Color.WHITE
        val txtMuted = if (isLight) Color.parseColor("#475569") else Color.parseColor("#94A3B8")
        val sepCol = if (isLight) Color.argb(28, 15, 23, 42) else Color.argb(24, 255, 255, 255)
        val todayRingCol = if (isLight) Color.parseColor("#0F172A") else Color.WHITE

        val json = WidgetConfigStore.resolveAdaptivePayload(widgetData, widgetId)

        val color = json.optInt("color", Color.parseColor("#84CC16"))
        val withGlow = true

        val views = RemoteViews(context.packageName, R.layout.adaptive_widget)
        views.setOnClickPendingIntent(android.R.id.background, null)
        views.setInt(
            android.R.id.background,
            "setBackgroundResource",
            if (isLight) R.drawable.widget_bg_light else R.drawable.widget_bg_dark,
        )

        views.setImageViewBitmap(
            R.id.adaptive_bg_img,
            WidgetCanvasHelper.renderCardBackgroundBitmap(
                context = context,
                isLight = isLight,
                accent = color,
                withGlow = withGlow && !json.optBoolean("empty", true),
                widthDp = cardW,
                heightDp = cardH,
            ),
        )

        if (json.optBoolean("empty", true)) {
            views.setViewVisibility(R.id.adaptive_empty_img, View.VISIBLE)
            views.setViewVisibility(R.id.adaptive_content, View.GONE)
            views.setImageViewBitmap(
                R.id.adaptive_empty_img,
                WidgetCanvasHelper.renderTextBitmap(
                    context = context,
                    text = json.optString("emptyMsg", "XHabit"),
                    spSize = 11.5f,
                    color = txtMuted,
                    weight = 1,
                    maxWidthDp = (cardW - 28f).coerceAtLeast(80f),
                ),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
            return
        }

        views.setViewVisibility(R.id.adaptive_empty_img, View.GONE)
        views.setViewVisibility(R.id.adaptive_content, View.VISIBLE)

        val habitId = json.optString("id", "")
        val title = json.optString("title", "XHabit")
        val iconCodePoint = json.optInt("iconCodePoint", 0)
        val style = json.optString("style", "boolean")
        val isQuit = json.optBoolean("isQuit", false)
        val doneToday = json.optBoolean("doneToday", false)
        val slippedToday = json.optBoolean("slippedToday", false)
        val countVal = json.optInt("countVal", 0)
        val countTarget = json.optInt("countTarget", 1).coerceAtLeast(1)
        val countRatio = if (style == "count") (countVal.toFloat() / countTarget.toFloat()).coerceIn(0f, 1f) else if (doneToday) 1f else 0f
        val streak = json.optInt("streak", 0)
        val best = json.optInt("best", 0)
        val score = json.optInt("score", 0)

        views.setViewVisibility(R.id.adaptive_icon_badge, View.GONE)
        views.setViewVisibility(R.id.adaptive_action_start, View.GONE)
        views.setViewVisibility(R.id.adaptive_action_end, View.GONE)
        views.setViewVisibility(R.id.adaptive_sub_flame, View.GONE)
        views.setViewVisibility(R.id.adaptive_compact_prog_img, View.GONE)
        views.setViewVisibility(R.id.adaptive_streak_group, View.GONE)
        views.setViewVisibility(R.id.adaptive_stepper_pill, View.GONE)
        views.setViewVisibility(R.id.adaptive_week7_img, View.GONE)
        views.setViewVisibility(R.id.adaptive_tall_prog_img, View.GONE)
        views.setViewVisibility(R.id.adaptive_grid_img, View.GONE)
        views.setViewVisibility(R.id.adaptive_kpi_sep, View.GONE)
        views.setViewVisibility(R.id.adaptive_kpi_row, View.GONE)
        views.setViewVisibility(R.id.adaptive_checklist_box, View.GONE)

        if (habitId.isNotEmpty()) {
            val openUri = Uri.Builder()
                .scheme("xhabit")
                .authority("open")
                .appendQueryParameter("habitId", habitId)
                .build()
            val openHabit = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                openUri,
            )
            views.setOnClickPendingIntent(R.id.adaptive_title_img, openHabit)

            val toggleUri = Uri.Builder()
                .scheme("xhabit")
                .authority("toggle")
                .appendQueryParameter("habitId", habitId)
                .build()
            val toggleIntent = HomeWidgetBackgroundIntent.getBroadcast(context, toggleUri)
            views.setOnClickPendingIntent(R.id.adaptive_action_start, toggleIntent)
            views.setOnClickPendingIntent(R.id.adaptive_action_end, toggleIntent)
        }

        val actionBmp = WidgetCanvasHelper.renderActionCircleBitmap(
            context = context,
            style = style,
            isQuit = isQuit,
            done = doneToday,
            slipped = slippedToday,
            ratio = countRatio,
            accent = color,
            isLight = isLight,
            dpSize = when (mode) {
                "2x1", "2x2" -> 32f
                "4x1" -> 36f
                else -> 34f
            },
        )

        val titleMaxDp = when (mode) {
            "2x1" -> (cardW - 96f).coerceAtLeast(52f)
            "3x1" -> (cardW - 106f).coerceAtLeast(80f)
            "4x1" -> (cardW - 224f).coerceAtLeast(66f)
            "2x2" -> (cardW - 78f).coerceAtLeast(65f)
            else -> (cardW - 184f).coerceAtLeast(80f)
        }
        val titleSp = if (mode == "2x1" || mode == "2x2") 11f else 12f
        views.setImageViewBitmap(
            R.id.adaptive_title_img,
            WidgetCanvasHelper.renderTextBitmap(
                context = context,
                text = title,
                spSize = titleSp,
                color = txtMain,
                weight = 2,
                maxWidthDp = titleMaxDp,
            ),
        )

        when (mode) {
            "2x1", "3x1" -> {
                val is3 = mode == "3x1"
                views.setImageViewBitmap(
                    R.id.adaptive_icon_badge,
                    WidgetCanvasHelper.renderHabitIconBadgeBitmap(
                        context = context,
                        accent = color,
                        iconCodePoint = iconCodePoint,
                        dpSize = if (is3) 32f else 28f,
                    ),
                )
                views.setViewVisibility(R.id.adaptive_icon_badge, View.VISIBLE)

                if (style == "count") {
                    views.setImageViewBitmap(
                        R.id.adaptive_subtitle_img,
                        WidgetCanvasHelper.renderTextBitmap(
                            context = context,
                            text = "$countVal/$countTarget",
                            spSize = if (is3) 10f else 9.5f,
                            color = txtMuted,
                            weight = 1,
                            maxWidthDp = titleMaxDp,
                        ),
                    )
                } else {
                    views.setImageViewBitmap(
                        R.id.adaptive_subtitle_img,
                        WidgetCanvasHelper.renderTextBitmap(
                            context = context,
                            text = "$streak",
                            spSize = if (is3) 10f else 9.5f,
                            color = color,
                            weight = 2,
                            maxWidthDp = 42f,
                        ),
                    )
                    views.setImageViewBitmap(
                        R.id.adaptive_sub_flame,
                        WidgetCanvasHelper.renderFlameBitmap(context, color, 11f),
                    )
                    views.setViewVisibility(R.id.adaptive_sub_flame, View.VISIBLE)
                }

                views.setImageViewBitmap(R.id.adaptive_action_end, actionBmp)
                views.setViewVisibility(R.id.adaptive_action_end, View.VISIBLE)
            }

            "4x1" -> {
                if (style == "count") {
                    views.setImageViewBitmap(
                        R.id.adaptive_subtitle_img,
                        WidgetCanvasHelper.renderTextBitmap(
                            context = context,
                            text = "$countVal/$countTarget",
                            spSize = 10f,
                            color = txtMuted,
                            weight = 1,
                            maxWidthDp = titleMaxDp,
                        ),
                    )
                    views.setImageViewBitmap(
                        R.id.adaptive_compact_prog_img,
                        WidgetCanvasHelper.renderProgressBarBitmap(context, countRatio, color, isLight, 100f, 4f),
                    )
                    views.setViewVisibility(R.id.adaptive_compact_prog_img, View.VISIBLE)
                } else {
                    views.setImageViewBitmap(
                        R.id.adaptive_subtitle_img,
                        WidgetCanvasHelper.renderTextBitmap(
                            context = context,
                            text = "$streak",
                            spSize = 10f,
                            color = color,
                            weight = 2,
                            maxWidthDp = 42f,
                        ),
                    )
                    views.setImageViewBitmap(
                        R.id.adaptive_sub_flame,
                        WidgetCanvasHelper.renderFlameBitmap(context, color, 11.5f),
                    )
                    views.setViewVisibility(R.id.adaptive_sub_flame, View.VISIBLE)
                }

                val week7 = json.optJSONArray("week7") ?: JSONArray()
                views.setImageViewBitmap(
                    R.id.adaptive_week7_img,
                    renderWeek7Bitmap(context, week7, color, txtMuted, todayRingCol),
                )
                views.setViewVisibility(R.id.adaptive_week7_img, View.VISIBLE)

                views.setImageViewBitmap(R.id.adaptive_action_end, actionBmp)
                views.setViewVisibility(R.id.adaptive_action_end, View.VISIBLE)
            }

            "2x2" -> {
                val mSub = json.optString("monthLabel", "") +
                    if (style == "count") " - $countVal/$countTarget" else ""
                views.setImageViewBitmap(
                    R.id.adaptive_subtitle_img,
                    WidgetCanvasHelper.renderTextBitmap(
                        context = context,
                        text = mSub,
                        spSize = 8.5f,
                        color = txtMuted,
                        weight = 1,
                        maxWidthDp = titleMaxDp,
                    ),
                )

                views.setImageViewBitmap(R.id.adaptive_action_end, actionBmp)
                views.setViewVisibility(R.id.adaptive_action_end, View.VISIBLE)

                val wd = json.optJSONArray("monthWeekdays") ?: JSONArray()
                val cells = json.optJSONArray("monthCells") ?: JSONArray()
                val gridAvailW = (cardW - 28f).coerceAtLeast(100f)
                val gridAvailH = (cardH - 68f).coerceAtLeast(70f)
                views.setImageViewBitmap(
                    R.id.adaptive_grid_img,
                    renderMonthBitmap(context, wd, cells, gridAvailW, gridAvailH, color, txtMuted, todayRingCol),
                )
                views.setViewVisibility(R.id.adaptive_grid_img, View.VISIBLE)
            }

            else -> {
                // 3x2 | 4x2 (NO footer) | 4x3 (KPI footer) | 4x4 (KPI footer + checklist sub-steps if checklist)
                val isTall = mode == "4x3" || mode == "4x4"
                val cl = json.optJSONArray("checklist") ?: JSONArray()
                val showChecklist = mode == "4x4" && style == "checklist" && cl.length() > 0
                val showWeeks = if (mode == "3x2") 12 else 18

                views.setImageViewBitmap(
                    R.id.adaptive_icon_badge,
                    WidgetCanvasHelper.renderHabitIconBadgeBitmap(
                        context = context,
                        accent = color,
                        iconCodePoint = iconCodePoint,
                        dpSize = 32f,
                    ),
                )
                views.setViewVisibility(R.id.adaptive_icon_badge, View.VISIBLE)

                views.setImageViewBitmap(R.id.adaptive_action_end, actionBmp)
                views.setViewVisibility(R.id.adaptive_action_end, View.VISIBLE)

                val subStr = json.optString(if (mode == "3x2") "sub3x2" else "sub4x2", "")
                views.setImageViewBitmap(
                    R.id.adaptive_subtitle_img,
                    WidgetCanvasHelper.renderTextBitmap(
                        context = context,
                        text = subStr,
                        spSize = 9f,
                        color = txtMuted,
                        weight = 0,
                        maxWidthDp = titleMaxDp,
                    ),
                )

                if (isTall && style == "count" && !isQuit) {
                    views.setInt(R.id.adaptive_stepper_pill, "setBackgroundResource", pillRes)
                    views.setViewVisibility(R.id.adaptive_stepper_pill, View.VISIBLE)
                    views.setTextViewText(R.id.adaptive_step_val, "$countVal/$countTarget")
                    views.setTextColor(R.id.adaptive_step_val, txtMain)
                    views.setTextColor(R.id.adaptive_step_minus, if (countVal <= 0) txtMuted else txtMain)
                    views.setTextColor(R.id.adaptive_step_plus, if (countVal >= countTarget) txtMuted else color)
                    if (habitId.isNotEmpty()) {
                        views.setOnClickPendingIntent(
                            R.id.adaptive_step_minus,
                            HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                Uri.parse("xhabit://step?habitId=$habitId&delta=-1"),
                            ),
                        )
                        views.setOnClickPendingIntent(
                            R.id.adaptive_step_plus,
                            HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                Uri.parse("xhabit://step?habitId=$habitId&delta=1"),
                            ),
                        )
                    }

                    views.setImageViewBitmap(
                        R.id.adaptive_tall_prog_img,
                        WidgetCanvasHelper.renderProgressBarBitmap(
                            context,
                            countRatio,
                            color,
                            isLight,
                            (cardW - 28f).coerceAtLeast(180f),
                            4f,
                        ),
                    )
                    views.setViewVisibility(R.id.adaptive_tall_prog_img, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.adaptive_streak_group, View.VISIBLE)
                    views.setImageViewBitmap(
                        R.id.adaptive_streak_val_img,
                        WidgetCanvasHelper.renderTextBitmap(
                            context = context,
                            text = "$streak",
                            spSize = 13f,
                            color = color,
                            weight = 2,
                            maxWidthDp = 42f,
                        ),
                    )
                    views.setImageViewBitmap(
                        R.id.adaptive_end_flame,
                        WidgetCanvasHelper.renderFlameBitmap(context, color, 14f),
                    )
                }

                val hmRows = json.optJSONArray("heatmapRows") ?: JSONArray()
                val gridAvailW = (cardW - 28f).coerceAtLeast(160f)
                val clCount = if (showChecklist) min(5, cl.length()) else 0
                val reservedH = when {
                    !isTall -> 70f
                    showChecklist -> 114f + clCount * 22f
                    style == "count" && !isQuit -> 124f
                    else -> 110f
                }
                val gridAvailH = (cardH - reservedH).coerceAtLeast(72f)
                views.setImageViewBitmap(
                    R.id.adaptive_grid_img,
                    renderHeatmapBitmap(
                        context = context,
                        rowsArr = hmRows,
                        showWeeks = showWeeks,
                        availWidthDp = gridAvailW,
                        availHeightDp = gridAvailH,
                        accent = color,
                        txtMuted = txtMuted,
                        todayRingCol = todayRingCol,
                    ),
                )
                views.setViewVisibility(R.id.adaptive_grid_img, View.VISIBLE)

                if (isTall) {
                    views.setInt(R.id.adaptive_kpi_sep, "setBackgroundColor", sepCol)
                    views.setViewVisibility(R.id.adaptive_kpi_sep, View.VISIBLE)
                    views.setViewVisibility(R.id.adaptive_kpi_row, View.VISIBLE)

                    val kpiMaxDp = ((cardW - 36f) / 3f).coerceAtLeast(52f)
                    views.setImageViewBitmap(
                        R.id.kpi_streak_val_img,
                        WidgetCanvasHelper.renderTextBitmap(context, "$streak", 13f, color, 2, kpiMaxDp),
                    )
                    views.setImageViewBitmap(
                        R.id.kpi_streak_lbl_img,
                        WidgetCanvasHelper.renderTextBitmap(
                            context,
                            json.optString("lblStreak", "Streak"),
                            9f,
                            txtMuted,
                            0,
                            kpiMaxDp,
                        ),
                    )
                    views.setImageViewBitmap(
                        R.id.kpi_best_val_img,
                        WidgetCanvasHelper.renderTextBitmap(context, "$best", 13f, txtMain, 2, kpiMaxDp),
                    )
                    views.setImageViewBitmap(
                        R.id.kpi_best_lbl_img,
                        WidgetCanvasHelper.renderTextBitmap(
                            context,
                            json.optString("lblBest", "Best"),
                            9f,
                            txtMuted,
                            0,
                            kpiMaxDp,
                        ),
                    )
                    views.setImageViewBitmap(
                        R.id.kpi_score_val_img,
                        WidgetCanvasHelper.renderTextBitmap(context, "$score%", 13f, txtMain, 2, kpiMaxDp),
                    )
                    views.setImageViewBitmap(
                        R.id.kpi_score_lbl_img,
                        WidgetCanvasHelper.renderTextBitmap(
                            context,
                            json.optString("lblScore", "Score"),
                            9f,
                            txtMuted,
                            0,
                            kpiMaxDp,
                        ),
                    )
                }

                if (showChecklist) {
                    views.setViewVisibility(R.id.adaptive_checklist_box, View.VISIBLE)
                    val rowIds = intArrayOf(
                        R.id.ad_sub_row_0, R.id.ad_sub_row_1, R.id.ad_sub_row_2, R.id.ad_sub_row_3, R.id.ad_sub_row_4
                    )
                    val chkIds = intArrayOf(
                        R.id.ad_sub_chk_0, R.id.ad_sub_chk_1, R.id.ad_sub_chk_2, R.id.ad_sub_chk_3, R.id.ad_sub_chk_4
                    )
                    val txtIds = intArrayOf(
                        R.id.ad_sub_txt_0, R.id.ad_sub_txt_1, R.id.ad_sub_txt_2, R.id.ad_sub_txt_3, R.id.ad_sub_txt_4
                    )
                    val subMaxW = (cardW - 60f).coerceAtLeast(100f)
                    for (i in 0 until 5) {
                        if (i < cl.length()) {
                            val item = cl.optJSONObject(i) ?: continue
                            val subId = item.optString("id", "")
                            val subTitle = item.optString("title", "")
                            val subDone = item.optBoolean("done", false)
                            views.setViewVisibility(rowIds[i], View.VISIBLE)
                            views.setImageViewBitmap(
                                chkIds[i],
                                WidgetCanvasHelper.renderSubCheckboxBitmap(context, subDone, color, isLight),
                            )
                            views.setImageViewBitmap(
                                txtIds[i],
                                WidgetCanvasHelper.renderTextBitmap(
                                    context = context,
                                    text = subTitle,
                                    spSize = 10.5f,
                                    color = if (subDone) WidgetCanvasHelper.tintWithAlpha(txtMuted, 0.65f) else txtMain,
                                    weight = 0,
                                    maxWidthDp = subMaxW,
                                    strikethrough = subDone,
                                ),
                            )
                            if (habitId.isNotEmpty() && subId.isNotEmpty()) {
                                val subUri = Uri.Builder()
                                    .scheme("xhabit")
                                    .authority("sub")
                                    .appendQueryParameter("habitId", habitId)
                                    .appendQueryParameter("subId", subId)
                                    .build()
                                views.setOnClickPendingIntent(
                                    rowIds[i],
                                    HomeWidgetBackgroundIntent.getBroadcast(context, subUri),
                                )
                            }
                        } else {
                            views.setViewVisibility(rowIds[i], View.GONE)
                        }
                    }
                }
            }
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun renderWeek7Bitmap(
        context: Context,
        week7: JSONArray,
        accent: Int,
        txtMuted: Int,
        todayRingCol: Int,
    ): Bitmap {
        val dm = context.resources.displayMetrics
        val scale = dm.density.coerceAtLeast(2f)
        val count = week7.length().coerceAtLeast(1)
        val box = 15f * scale
        val gap = 4.5f * scale
        val topTextH = 11f * scale
        val w = (count * box + (count - 1) * gap + 4f * scale).toInt()
        val h = (topTextH + box + 4f * scale).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.density = dm.densityDpi
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        val sampleLabel = if (week7.length() > 0) week7.optJSONObject(0)?.optString("label", "S") ?: "S" else "S"
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = txtMuted
            textSize = 7.5f * scale
            textAlign = Paint.Align.CENTER
            typeface = WidgetCanvasHelper.typefaceForText(context, sampleLabel, 1)
        }
        val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = todayRingCol
            style = Paint.Style.STROKE
            strokeWidth = 1.4f * scale
        }

        for (i in 0 until week7.length()) {
            val obj = week7.optJSONObject(i) ?: continue
            val label = obj.optString("label", "")
            val ratio = obj.optDouble("ratio", 0.0).toFloat()
            val isToday = obj.optBoolean("isToday", false)
            val x = 2f * scale + i * (box + gap)
            canvas.drawText(label, x + box / 2f, 8f * scale, textPaint)
            paint.color = when {
                ratio >= 1f -> accent
                ratio > 0f -> WidgetCanvasHelper.tintWithAlpha(accent, 0.45f)
                else -> WidgetCanvasHelper.tintWithAlpha(accent, 0.16f)
            }
            val rect = RectF(x, topTextH, x + box, topTextH + box)
            canvas.drawRoundRect(rect, 4f * scale, 4f * scale, paint)
            if (isToday) {
                canvas.drawRoundRect(
                    RectF(x - 1f * scale, topTextH - 1f * scale, x + box + 1f * scale, topTextH + box + 1f * scale),
                    5f * scale,
                    5f * scale,
                    ringPaint,
                )
            }
        }
        return bmp
    }

    private fun renderMonthBitmap(
        context: Context,
        weekdays: JSONArray,
        cells: JSONArray,
        availWidthDp: Float,
        availHeightDp: Float,
        accent: Int,
        txtMuted: Int,
        todayRingCol: Int,
    ): Bitmap {
        val dm = context.resources.displayMetrics
        val scale = dm.density.coerceAtLeast(2f)
        val cols = 7
        val rows = ((cells.length() + 6) / 7).coerceAtLeast(1)
        val gapDp = if (rows >= 6) 2.2f else 2.6f
        val hdrDp = 11f
        val cellWDp = (availWidthDp - (cols - 1) * gapDp) / cols
        val maxCellHDp = (availHeightDp - hdrDp - (rows - 1) * gapDp) / rows
        val cellHDp = maxCellHDp.coerceIn(cellWDp * 0.68f, cellWDp * 1.15f)
        val cellW = cellWDp * scale
        val cellH = cellHDp * scale
        val gap = gapDp * scale
        val hdrH = hdrDp * scale

        val w = (cols * cellW + (cols - 1) * gap + 2f * scale).toInt()
        val h = (hdrH + rows * cellH + (rows - 1) * gap + 2f * scale).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.density = dm.densityDpi
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val futStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = WidgetCanvasHelper.tintWithAlpha(accent, 0.25f)
            style = Paint.Style.STROKE
            strokeWidth = 1f * scale
        }
        val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = todayRingCol
            style = Paint.Style.STROKE
            strokeWidth = 1.3f * scale
        }
        val sampleWd = weekdays.optString(0, "S")
        val hdrPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = txtMuted
            textSize = 7.2f * scale
            textAlign = Paint.Align.CENTER
            typeface = WidgetCanvasHelper.typefaceForText(context, sampleWd, 1)
        }

        for (c in 0 until min(cols, weekdays.length())) {
            val x = 1f * scale + c * (cellW + gap) + cellW / 2f
            canvas.drawText(weekdays.optString(c, ""), x, 8f * scale, hdrPaint)
        }

        val rad = 3f * scale
        for (i in 0 until cells.length()) {
            val obj = cells.optJSONObject(i) ?: continue
            if (obj.optBoolean("pad", false)) continue
            val col = i % cols
            val row = i / cols
            val x = 1f * scale + col * (cellW + gap)
            val y = hdrH + row * (cellH + gap)
            val rect = RectF(x, y, x + cellW, y + cellH)
            if (obj.optBoolean("fut", false)) {
                canvas.drawRoundRect(rect, rad, rad, futStroke)
            } else {
                val r = obj.optDouble("ratio", 0.0).toFloat()
                paint.color = when {
                    r >= 1f -> accent
                    r > 0f -> WidgetCanvasHelper.tintWithAlpha(accent, 0.45f)
                    else -> WidgetCanvasHelper.tintWithAlpha(accent, 0.16f)
                }
                canvas.drawRoundRect(rect, rad, rad, paint)
            }
            if (obj.optBoolean("isToday", false)) {
                canvas.drawRoundRect(
                    RectF(x - 0.6f * scale, y - 0.6f * scale, x + cellW + 0.6f * scale, y + cellH + 0.6f * scale),
                    rad + 0.5f * scale,
                    rad + 0.5f * scale,
                    ringPaint,
                )
            }
        }
        return bmp
    }

    private fun renderHeatmapBitmap(
        context: Context,
        rowsArr: JSONArray,
        showWeeks: Int,
        availWidthDp: Float,
        availHeightDp: Float,
        accent: Int,
        txtMuted: Int,
        todayRingCol: Int,
    ): Bitmap {
        val dm = context.resources.displayMetrics
        val scale = dm.density.coerceAtLeast(2f)
        val labelColDp = 13f
        val gapDp = 2.5f

        // Fill 100% of available horizontal width cleanly while keeping cells proportionate & legible
        val cellWDp = ((availWidthDp - labelColDp - showWeeks * gapDp) / showWeeks).coerceAtLeast(6f)
        val maxCellHDp = ((availHeightDp - 6f * gapDp) / 7f).coerceAtLeast(6f)
        val cellHDp = min(cellWDp * 1.12f, maxCellHDp).coerceAtLeast(min(cellWDp * 0.72f, maxCellHDp))

        val labelColW = labelColDp * scale
        val boxW = cellWDp * scale
        val boxH = cellHDp * scale
        val gap = gapDp * scale

        val w = (labelColW + showWeeks * boxW + showWeeks * gap + 1f * scale).toInt()
        val h = (7f * boxH + 6f * gap + 2f * scale).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.density = dm.densityDpi
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        val firstLabel = if (rowsArr.length() > 0) rowsArr.optJSONObject(0)?.optString("label", "S") ?: "S" else "S"
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = txtMuted
            textSize = (min(cellWDp, cellHDp) * 0.62f).coerceIn(6.5f, 8.8f) * scale
            textAlign = Paint.Align.CENTER
            typeface = WidgetCanvasHelper.typefaceForText(context, firstLabel, 1)
        }
        val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = todayRingCol
            style = Paint.Style.STROKE
            strokeWidth = 1.1f * scale
        }
        val fontMetrics = textPaint.fontMetrics
        val rad = 3f * scale

        for (r in 0 until min(7, rowsArr.length())) {
            val rowObj = rowsArr.optJSONObject(r) ?: continue
            val label = rowObj.optString("label", "")
            val cells = rowObj.optJSONArray("cells") ?: JSONArray()
            val y = 1f * scale + r * (boxH + gap)
            val baseline = y + boxH / 2f - (fontMetrics.ascent + fontMetrics.descent) / 2f
            canvas.drawText(label, labelColW / 2f, baseline, textPaint)

            val offset = (cells.length() - showWeeks).coerceAtLeast(0)
            for (cIdx in 0 until showWeeks) {
                val srcIdx = offset + cIdx
                if (srcIdx >= cells.length()) continue
                val cell = cells.optJSONObject(srcIdx) ?: continue
                val x = labelColW + gap + cIdx * (boxW + gap)
                val fut = cell.optBoolean("fut", false)
                val ratio = cell.optDouble("ratio", 0.0).toFloat()
                paint.color = when {
                    fut -> Color.argb(30, 128, 128, 128)
                    ratio >= 1f -> accent
                    ratio > 0f -> WidgetCanvasHelper.tintWithAlpha(accent, 0.45f)
                    else -> WidgetCanvasHelper.tintWithAlpha(accent, 0.16f)
                }
                val rect = RectF(x, y, x + boxW, y + boxH)
                canvas.drawRoundRect(rect, rad, rad, paint)
                if (cell.optBoolean("isToday", false)) {
                    canvas.drawRoundRect(
                        RectF(x + 0.5f * scale, y + 0.5f * scale, x + boxW - 0.5f * scale, y + boxH - 0.5f * scale),
                        rad,
                        rad,
                        ringPaint,
                    )
                }
            }
        }
        return bmp
    }
}
