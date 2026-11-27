package app.xhabit.tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class ToDoListRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        val isLight = intent.getBooleanExtra("isLight", false)
        val rowTitleMaxDp = intent.getFloatExtra("rowTitleMaxDp", 190f)
        return ToDoListFactory(applicationContext, widgetId, isLight, rowTitleMaxDp)
    }
}

private data class ToDoDisplayRow(
    val id: String,
    val title: String,
    val note: String,
    val isDone: Boolean,
    val isShopping: Boolean,
)

private class ToDoListFactory(
    private val context: Context,
    private val appWidgetId: Int,
    private val initialLight: Boolean,
    private val rowTitleMaxDp: Float,
) : RemoteViewsService.RemoteViewsFactory {

    @Volatile
    private var rows: List<ToDoDisplayRow> = emptyList()
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

        val resolved = WidgetConfigStore.resolveToDoListData(prefs, appWidgetId)
        val built = ArrayList<ToDoDisplayRow>(resolved.items.size)
        for (obj in resolved.items) {
            val id = obj.optString("id", "")
            if (id.isEmpty()) continue
            built.add(
                ToDoDisplayRow(
                    id = id,
                    title = obj.optString("title", ""),
                    note = obj.optString("quantity", ""),
                    isDone = obj.optBoolean("isDone", false),
                    isShopping = obj.optString("kind", "todo") == "shopping",
                ),
            )
        }
        rows = built
    }

    override fun onDestroy() {}
    override fun getCount(): Int = rows.size
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false

    override fun getViewAt(position: Int): RemoteViews {
        val snapshot = rows
        if (position !in snapshot.indices) {
            return RemoteViews(context.packageName, R.layout.todo_list_row)
        }
        val row = snapshot[position]
        val txtMain = if (isLight) Color.parseColor("#0F172A") else Color.WHITE
        val txtMuted = if (isLight) Color.parseColor("#475569") else Color.parseColor("#94A3B8")
        val accent = when {
            row.isDone -> txtMuted
            row.isShopping -> Color.parseColor("#38BDF8")
            else -> if (isLight) Color.parseColor("#65A30D") else Color.parseColor("#84CC16")
        }

        val rv = RemoteViews(context.packageName, R.layout.todo_list_row)
        rv.setImageViewBitmap(
            R.id.todo_accent_bar,
            WidgetCanvasHelper.renderAccentCapsuleBitmap(context, accent),
        )
        rv.setImageViewBitmap(
            R.id.todo_title_img,
            WidgetCanvasHelper.renderTextBitmap(
                context = context,
                text = row.title,
                spSize = 12.8f,
                color = if (row.isDone) WidgetCanvasHelper.tintWithAlpha(txtMuted, 0.55f) else txtMain,
                weight = 1,
                maxWidthDp = if (row.note.isEmpty()) rowTitleMaxDp else (rowTitleMaxDp - 44f).coerceAtLeast(50f),
                strikethrough = row.isDone,
            ),
        )

        if (row.note.isEmpty()) {
            rv.setViewVisibility(R.id.todo_note_img, View.GONE)
        } else {
            rv.setViewVisibility(R.id.todo_note_img, View.VISIBLE)
            rv.setImageViewBitmap(
                R.id.todo_note_img,
                WidgetCanvasHelper.renderTextBitmap(
                    context = context,
                    text = row.note,
                    spSize = 10.5f,
                    color = txtMuted,
                    weight = 0,
                    maxWidthDp = 52f,
                ),
            )
        }

        rv.setImageViewBitmap(
            R.id.todo_action_btn,
            WidgetCanvasHelper.renderActionCircleBitmap(
                context = context,
                style = "boolean",
                isQuit = false,
                done = row.isDone,
                slipped = false,
                ratio = if (row.isDone) 1f else 0f,
                accent = accent,
                isLight = isLight,
                dpSize = 28f,
            ),
        )

        val openUri = Uri.Builder()
            .scheme("xhabit")
            .authority("open")
            .appendQueryParameter("tab", "tasks")
            .build()
            .toString()
        val toggleUri = Uri.Builder()
            .scheme("xhabit")
            .authority("todotoggle")
            .appendQueryParameter("taskId", row.id)
            .build()
            .toString()

        rv.setOnClickFillInIntent(
            R.id.todo_title_box,
            Intent().putExtra("xhabit_uri", openUri),
        )
        rv.setOnClickFillInIntent(
            R.id.todo_action_btn,
            Intent().putExtra("xhabit_uri", toggleUri),
        )
        return rv
    }
}
