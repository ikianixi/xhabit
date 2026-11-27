package app.xhabit.tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DayModeWidgetProvider : HomeWidgetProvider() {

    companion object {
        fun updateWidgetById(context: Context, widgetId: Int) {
            val manager = AppWidgetManager.getInstance(context)
            val prefs = context.getSharedPreferences(WidgetConfigStore.PREFS_NAME, Context.MODE_PRIVATE)
            val options = manager.getAppWidgetOptions(widgetId)
            DayModeWidgetProvider().updateOne(context, manager, widgetId, prefs, options)
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
        val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 76).toFloat()
        val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minH.toInt()).toFloat()
        return if (isLand) (maxW to minH) else (minW to minH.coerceAtLeast(72f).coerceAtMost(maxH))
    }

    private fun updateOne(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
        options: Bundle,
    ) {
        val (cardW, cardH) = resolveWidgetDp(context, options)
        val isWide = cardW >= 235f
        val isMed = cardW >= 175f
        val isLight = WidgetConfigStore.resolveIsLight(widgetData, widgetId)
        val bgAlpha = WidgetConfigStore.resolveOpacityAlpha(widgetData)
        val includeAll = WidgetConfigStore.getDayModeIncludeAll(widgetData, widgetId)

        val txtMain = if (isLight) Color.parseColor("#0F172A") else Color.WHITE
        val txtMuted = if (isLight) Color.parseColor("#475569") else Color.parseColor("#94A3B8")

        val json = WidgetConfigStore.readDayModePayload(widgetData)
        val modeName = json.optString("activeModeName", "Normal")
        val accent = json.optInt("activeModeColor", Color.parseColor("#84CC16"))
        val iconCodePoint = json.optInt("activeModeIconCodePoint", 0)
        val subShort = json.optString("subtitleShort", "")
        val subWide = json.optString("subtitleWide", subShort)
        val subtitle = if (isWide) subWide else subShort

        val views = RemoteViews(context.packageName, R.layout.day_mode_widget)
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

        // Adaptive Widget style card backdrop with top-right radial glow matching active Day Mode color
        views.setImageViewBitmap(
            R.id.day_mode_bg_img,
            WidgetCanvasHelper.renderCardBackgroundBitmap(
                context = context,
                isLight = isLight,
                accent = accent,
                withGlow = true,
                widthDp = cardW,
                heightDp = cardH,
                bgAlpha = bgAlpha,
            ),
        )

        val badgeSize = when {
            isWide -> 34f
            isMed -> 32f
            else -> 28f
        }
        views.setImageViewBitmap(
            R.id.day_mode_icon_badge,
            WidgetCanvasHelper.renderHabitIconBadgeBitmap(
                context = context,
                accent = accent,
                iconCodePoint = iconCodePoint,
                dpSize = badgeSize,
            ),
        )

        val titleMaxDp = when {
            isWide -> (cardW - 158f).coerceAtLeast(80f)
            isMed -> (cardW - 144f).coerceAtLeast(68f)
            else -> (cardW - 130f).coerceAtLeast(44f)
        }
        val titleSp = if (isMed) 13.2f else 12.2f
        views.setImageViewBitmap(
            R.id.day_mode_title_img,
            WidgetCanvasHelper.renderTextBitmap(
                context = context,
                text = modeName,
                spSize = titleSp,
                color = txtMain,
                weight = 2,
                maxWidthDp = titleMaxDp,
            ),
        )

        if (subtitle.isEmpty()) {
            views.setViewVisibility(R.id.day_mode_sub_img, View.GONE)
        } else {
            views.setViewVisibility(R.id.day_mode_sub_img, View.VISIBLE)
            views.setImageViewBitmap(
                R.id.day_mode_sub_img,
                WidgetCanvasHelper.renderTextBitmap(
                    context = context,
                    text = subtitle,
                    spSize = if (isMed) 10.5f else 9.8f,
                    color = txtMuted,
                    weight = 1,
                    maxWidthDp = titleMaxDp,
                ),
            )
        }

        val btnSize = when {
            isWide -> 36f
            isMed -> 34f
            else -> 32f
        }
        views.setImageViewBitmap(
            R.id.day_mode_prev_btn,
            WidgetCanvasHelper.renderChevronButtonBitmap(
                context = context,
                isNext = false,
                accent = accent,
                isLight = isLight,
                dpSize = btnSize,
            ),
        )
        views.setImageViewBitmap(
            R.id.day_mode_next_btn,
            WidgetCanvasHelper.renderChevronButtonBitmap(
                context = context,
                isNext = true,
                accent = accent,
                isLight = isLight,
                dpSize = btnSize,
            ),
        )

        val openDayModes = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("xhabit://open?tab=daymodes"),
        )
        views.setOnClickPendingIntent(R.id.day_mode_icon_badge, openDayModes)
        views.setOnClickPendingIntent(R.id.day_mode_title_box, openDayModes)

        val prevUri = Uri.Builder()
            .scheme("xhabit")
            .authority("daymode")
            .appendQueryParameter("delta", "-1")
            .appendQueryParameter("includeAll", includeAll.toString())
            .build()
        val nextUri = Uri.Builder()
            .scheme("xhabit")
            .authority("daymode")
            .appendQueryParameter("delta", "1")
            .appendQueryParameter("includeAll", includeAll.toString())
            .build()

        views.setOnClickPendingIntent(
            R.id.day_mode_prev_btn,
            HomeWidgetBackgroundIntent.getBroadcast(context, prevUri),
        )
        views.setOnClickPendingIntent(
            R.id.day_mode_next_btn,
            HomeWidgetBackgroundIntent.getBroadcast(context, nextUri),
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
