package app.xhabit.tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class DailyListRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        val showSub = intent.getBooleanExtra("showSubSteps", false)
        val isLight = intent.getBooleanExtra("isLight", false)
        val rowTitleMaxDp = intent.getFloatExtra("rowTitleMaxDp", 190f)
        return DailyListFactory(applicationContext, widgetId, showSub, isLight, rowTitleMaxDp)
    }
}

private data class ListDisplayRow(
    val isSub: Boolean,
    val habitId: String,
    val subId: String = "",
    val title: String,
    val color: Int,
    val done: Boolean,
    val slipped: Boolean,
    val isQuit: Boolean,
    val style: String,
    val ratio: Float,
    val countText: String = "",
    val willCompleteOnTap: Boolean = false,
)

private class DailyListFactory(
    private val context: Context,
    private val appWidgetId: Int,
    private val showSubSteps: Boolean,
    private val initialLight: Boolean,
    private val rowTitleMaxDp: Float,
) : RemoteViewsService.RemoteViewsFactory {

    @Volatile
    private var rows: List<ListDisplayRow> = emptyList()
    @Volatile
    private var isLight = initialLight

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences(WidgetConfigStore.PREFS_NAME, Context.MODE_PRIVATE)
        isLight = if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            WidgetConfigStore.resolveIsLight(prefs, appWidgetId)
        } else {
            (prefs.getString("widget_theme", if (initialLight) "light" else "dark") ?: "dark") == "light"
        }
        val resolved = WidgetConfigStore.resolveDailyListData(prefs, appWidgetId)
        val items = resolved.items

        val built = mutableListOf<ListDisplayRow>()
        for (obj in items) {
            val id = obj.optString("id", "")
            val title = obj.optString("title", "")
            val color = obj.optInt("color", Color.parseColor("#84CC16"))
            val style = obj.optString("style", "boolean")
            val isQuit = obj.optBoolean("isQuit", false)
            val done = obj.optBoolean("done", false)
            val slipped = obj.optBoolean("slipped", false)
            val countVal = obj.optInt("countVal", 0)
            val countTarget = obj.optInt("countTarget", 1).coerceAtLeast(1)
            val ratio = if (style == "count") (countVal.toFloat() / countTarget.toFloat()).coerceIn(0f, 1f) else if (done) 1f else 0f
            val cntTxt = if (style == "count" && !done) "$countVal/$countTarget" else ""
            val completesOnTap = !done && (isQuit || style != "count" || (countVal + 1) >= countTarget)

            built.add(
                ListDisplayRow(
                    isSub = false,
                    habitId = id,
                    title = title,
                    color = color,
                    done = done,
                    slipped = slipped,
                    isQuit = isQuit,
                    style = style,
                    ratio = ratio,
                    countText = cntTxt,
                    willCompleteOnTap = completesOnTap,
                ),
            )

            // Checklist sub-steps belong strictly to Daily List Widget when height >= 3 rows
            if (showSubSteps && !done && style == "checklist") {
                val cl = obj.optJSONArray("checklist") ?: JSONArray()
                for (j in 0 until cl.length()) {
                    val sub = cl.optJSONObject(j) ?: continue
                    built.add(
                        ListDisplayRow(
                            isSub = true,
                            habitId = id,
                            subId = sub.optString("id", ""),
                            title = sub.optString("title", ""),
                            color = color,
                            done = sub.optBoolean("done", false),
                            slipped = false,
                            isQuit = false,
                            style = "sub",
                            ratio = 0f,
                            willCompleteOnTap = !sub.optBoolean("done", false),
                        ),
                    )
                }
            }
        }
        rows = built
    }

    override fun onDestroy() {}
    override fun getCount(): Int = rows.size
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 2
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false

    override fun getViewAt(position: Int): RemoteViews {
        val snapshot = rows
        if (position !in snapshot.indices) {
            return RemoteViews(context.packageName, R.layout.daily_list_row)
        }
        val row = snapshot[position]
        val txtMain = if (isLight) Color.parseColor("#0F172A") else Color.WHITE
        val txtMuted = if (isLight) Color.parseColor("#475569") else Color.parseColor("#94A3B8")

        if (row.isSub) {
            val rv = RemoteViews(context.packageName, R.layout.daily_list_sub_row)
            rv.setImageViewBitmap(
                R.id.sub_box,
                WidgetCanvasHelper.renderSubCheckboxBitmap(context, row.done, row.color, isLight),
            )
            rv.setImageViewBitmap(
                R.id.sub_title_img,
                WidgetCanvasHelper.renderTextBitmap(
                    context = context,
                    text = row.title,
                    spSize = 11.5f,
                    color = if (row.done) WidgetCanvasHelper.tintWithAlpha(txtMuted, 0.65f) else txtMain,
                    weight = 0,
                    maxWidthDp = (rowTitleMaxDp - 24f).coerceAtLeast(60f),
                    strikethrough = row.done,
                ),
            )
            val subUri = Uri.Builder()
                .scheme("xhabit")
                .authority("sub")
                .appendQueryParameter("habitId", row.habitId)
                .appendQueryParameter("subId", row.subId)
                .build()
                .toString()
            val fillIn = Intent()
                .putExtra("xhabit_uri", subUri)
            rv.setOnClickFillInIntent(R.id.sub_row_root, fillIn)
            return rv
        }

        val rv = RemoteViews(context.packageName, R.layout.daily_list_row)
        rv.setImageViewBitmap(
            R.id.row_accent_bar,
            WidgetCanvasHelper.renderAccentCapsuleBitmap(context, row.color),
        )
        rv.setImageViewBitmap(
            R.id.row_title_img,
            WidgetCanvasHelper.renderTextBitmap(
                context = context,
                text = row.title,
                spSize = 12.8f,
                color = if (row.done) WidgetCanvasHelper.tintWithAlpha(txtMuted, 0.55f) else txtMain,
                weight = 1,
                maxWidthDp = if (row.countText.isEmpty()) rowTitleMaxDp else (rowTitleMaxDp - 34f).coerceAtLeast(50f),
                strikethrough = row.done,
            ),
        )

        if (row.countText.isEmpty()) {
            rv.setViewVisibility(R.id.row_count_img, View.GONE)
        } else {
            rv.setViewVisibility(R.id.row_count_img, View.VISIBLE)
            rv.setImageViewBitmap(
                R.id.row_count_img,
                WidgetCanvasHelper.renderTextBitmap(
                    context = context,
                    text = row.countText,
                    spSize = 11f,
                    color = txtMuted,
                    weight = 1,
                    maxWidthDp = 40f,
                ),
            )
        }

        rv.setImageViewBitmap(
            R.id.row_action_btn,
            WidgetCanvasHelper.renderActionCircleBitmap(
                context = context,
                style = row.style,
                isQuit = row.isQuit,
                done = row.done,
                slipped = row.slipped,
                ratio = row.ratio,
                accent = row.color,
                isLight = isLight,
                dpSize = 28f,
            ),
        )

        val openUri = Uri.Builder()
            .scheme("xhabit")
            .authority("open")
            .appendQueryParameter("habitId", row.habitId)
            .build()
            .toString()
        val toggleUri = Uri.Builder()
            .scheme("xhabit")
            .authority("toggle")
            .appendQueryParameter("habitId", row.habitId)
            .build()
            .toString()
        rv.setOnClickFillInIntent(
            R.id.row_title_box,
            Intent().putExtra("xhabit_uri", openUri),
        )
        rv.setOnClickFillInIntent(
            R.id.row_action_btn,
            Intent().putExtra("xhabit_uri", toggleUri),
        )
        return rv
    }
}
