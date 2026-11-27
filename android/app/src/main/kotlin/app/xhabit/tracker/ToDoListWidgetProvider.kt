package app.xhabit.tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ToDoListWidgetProvider : HomeWidgetProvider() {

    companion object {
        fun updateWidgetById(context: Context, widgetId: Int) {
            val manager = AppWidgetManager.getInstance(context)
            val prefs = context.getSharedPreferences(WidgetConfigStore.PREFS_NAME, Context.MODE_PRIVATE)
            val options = manager.getAppWidgetOptions(widgetId)
            ToDoListWidgetProvider().updateOne(context, manager, widgetId, prefs, options)
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
        val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250).toFloat()
        val maxW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minW.toInt()).toFloat()
        val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180).toFloat()
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
        val isLight = WidgetConfigStore.resolveIsLight(widgetData, widgetId)
        val bgAlpha = WidgetConfigStore.resolveOpacityAlpha(widgetData)
        val txtMain = if (isLight) Color.parseColor("#0F172A") else Color.WHITE
        val txtMuted = if (isLight) Color.parseColor("#475569") else Color.parseColor("#94A3B8")
        val lime = if (isLight) Color.parseColor("#65A30D") else Color.parseColor("#84CC16")

        val resolved = WidgetConfigStore.resolveToDoListData(widgetData, widgetId)
        val ratio = if (resolved.totalCount > 0) {
            resolved.doneCount.toFloat() / resolved.totalCount.toFloat()
        } else {
            0f
        }

        val views = RemoteViews(context.packageName, R.layout.todo_list_widget)
        views.setOnClickPendingIntent(android.R.id.background, null)
        views.setInt(
            android.R.id.background,
            "setBackgroundResource",
            if (bgAlpha < 255) {
                R.drawable.widget_clip_mask
            } else if (isLight) {
                R.drawable.widget_bg_light
            } else {
                R.drawable.widget_bg_dark
            },
        )
        if (bgAlpha < 255) {
            views.setViewVisibility(R.id.todo_list_bg_img, android.view.View.VISIBLE)
            views.setImageViewBitmap(
                R.id.todo_list_bg_img,
                WidgetCanvasHelper.renderCardBackgroundBitmap(
                    context = context,
                    isLight = isLight,
                    accent = lime,
                    withGlow = false,
                    widthDp = cardW,
                    heightDp = cardH,
                    bgAlpha = bgAlpha,
                ),
            )
        } else {
            views.setViewVisibility(R.id.todo_list_bg_img, android.view.View.GONE)
        }

        val openTasksIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("xhabit://open?tab=tasks"),
        )
        views.setOnClickPendingIntent(R.id.todo_list_header_title_img, openTasksIntent)

        views.setImageViewBitmap(
            R.id.todo_list_header_title_img,
            WidgetCanvasHelper.renderTextBitmap(
                context = context,
                text = resolved.headerTitle,
                spSize = 13.4f,
                color = txtMain,
                weight = 2,
                maxWidthDp = (cardW - 85f).coerceAtLeast(80f),
            ),
        )
        views.setImageViewBitmap(
            R.id.todo_list_counter_img,
            WidgetCanvasHelper.renderTextBitmap(
                context = context,
                text = "${resolved.doneCount}/${resolved.totalCount}",
                spSize = 11.2f,
                color = txtMuted,
                weight = 2,
                maxWidthDp = 54f,
            ),
        )

        views.setImageViewBitmap(
            R.id.todo_list_progress_img,
            WidgetCanvasHelper.renderProgressBarBitmap(
                context = context,
                ratio = ratio,
                fillColor = lime,
                isLight = isLight,
                widthDp = (cardW - 32f).coerceAtLeast(110f),
                heightDp = 4.2f,
            ),
        )

        views.setImageViewBitmap(
            R.id.todo_list_empty_img,
            WidgetCanvasHelper.renderTextBitmap(
                context = context,
                text = resolved.emptyMsg.ifEmpty { "XHabit" },
                spSize = 11f,
                color = txtMuted,
                weight = 1,
                maxWidthDp = (cardW - 36f).coerceAtLeast(100f),
            ),
        )
        views.setEmptyView(R.id.todo_list_view, R.id.todo_list_empty_img)

        val rowTitleMaxDp = (cardW - 104f).coerceAtLeast(64f)
        val svcIntent = Intent(context, ToDoListRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra("isLight", isLight)
            putExtra("rowTitleMaxDp", rowTitleMaxDp)
            data = Uri.Builder()
                .scheme("xhabit")
                .authority("todolist")
                .appendPath(widgetId.toString())
                .appendPath(resolved.cfgVer.toString())
                .appendPath(resolved.hideCompleted.toString())
                .appendPath(isLight.toString())
                .appendPath(rowTitleMaxDp.toInt().toString())
                .build()
        }
        @Suppress("DEPRECATION")
        views.setRemoteAdapter(R.id.todo_list_view, svcIntent)

        val routerIntent = Intent(context, WidgetClickReceiver::class.java)
        val pendingTemplate = PendingIntent.getBroadcast(
            context,
            widgetId + 3000,
            routerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        views.setPendingIntentTemplate(R.id.todo_list_view, pendingTemplate)

        appWidgetManager.updateAppWidget(widgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.todo_list_view)
    }
}
