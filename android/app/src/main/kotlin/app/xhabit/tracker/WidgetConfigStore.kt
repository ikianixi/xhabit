package app.xhabit.tracker

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import org.json.JSONArray
import org.json.JSONObject

data class DailyListSelection(
    val mode: String, // "default" | "all" | "custom"
    val selectedIds: List<String>,
    val customTitle: String,
)

data class DailyListResolved(
    val headerTitle: String,
    val doneCount: Int,
    val totalCount: Int,
    val emptyMsg: String,
    val items: List<JSONObject>,
    val cfgVer: Long,
)

data class ToDoListResolved(
    val headerTitle: String,
    val doneCount: Int,
    val totalCount: Int,
    val emptyMsg: String,
    val items: List<JSONObject>,
    val hideCompleted: Boolean,
    val cfgVer: Long,
)

/**
 * Shared per-instance (`appWidgetId`) configuration store for both Home Screen widgets.
 * Persists directly inside `HomeWidgetPreferences` so Kotlin providers, RemoteViewsService,
 * `WidgetConfigureActivity`, and Flutter `MethodChannel` stay 100% consistent without starting Flutter.
 */
object WidgetConfigStore {
    const val PREFS_NAME = "HomeWidgetPreferences"

    private const val KEY_ADAPTIVE_ALL = "adaptive_all_habits_json"
    private const val KEY_ADAPTIVE_LEGACY = "adaptive_payload_json"
    private const val KEY_LIST_ALL = "daily_list_all_json"
    private const val KEY_LIST_LEGACY = "daily_list_payload_json"
    private const val KEY_TODO_ALL = "todo_list_all_json"
    private const val KEY_DAY_MODE_JSON = "day_mode_payload_json"

    private const val KEY_PENDING_ADAPTIVE_ID = "pending_pin_adaptive_habit_id"
    private const val KEY_PENDING_LIST_MODE = "pending_pin_list_mode"
    private const val KEY_PENDING_LIST_IDS = "pending_pin_list_ids"
    private const val KEY_PENDING_LIST_TITLE = "pending_pin_list_title"
    private const val KEY_PENDING_TODO_HIDE_DONE = "pending_pin_todo_hide_done"
    private const val KEY_PENDING_TODO_TITLE = "pending_pin_todo_title"
    private const val KEY_PENDING_DAY_MODE_ALL = "pending_pin_day_mode_include_all"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun adaptiveKey(widgetId: Int) = "widget_adaptive_habit_$widgetId"
    private fun listModeKey(widgetId: Int) = "widget_list_mode_$widgetId"
    private fun listIdsKey(widgetId: Int) = "widget_list_ids_$widgetId"
    private fun todoHideDoneKey(widgetId: Int) = "widget_todo_hide_done_$widgetId"
    private fun dayModeIncludeAllKey(widgetId: Int) = "widget_day_mode_include_all_$widgetId"
    private fun titleKey(widgetId: Int) = "widget_title_$widgetId"
    private fun themeKey(widgetId: Int) = "widget_theme_$widgetId"
    private fun cfgVerKey(widgetId: Int) = "widget_cfg_ver_$widgetId"

    fun getConfigVersion(prefs: SharedPreferences, widgetId: Int): Long =
        prefs.getLong(cfgVerKey(widgetId), 0L)

    fun getWidgetThemeMode(prefs: SharedPreferences, widgetId: Int): String =
        when (prefs.getString(themeKey(widgetId), "follow")) {
            "dark" -> "dark"
            "light" -> "light"
            else -> "follow"
        }

    fun resolveIsLight(prefs: SharedPreferences, widgetId: Int): Boolean {
        return when (getWidgetThemeMode(prefs, widgetId)) {
            "light" -> true
            "dark" -> false
            else -> (prefs.getString("widget_theme", "dark") ?: "dark") == "light"
        }
    }

    fun resolveOpacityAlpha(prefs: SharedPreferences): Int {
        val pct = prefs.getInt("widget_opacity_pct", 100).coerceIn(0, 100)
        return (pct * 255 / 100).coerceIn(0, 255)
    }

    fun setPendingPinAdaptivePreset(context: Context, habitId: String?) {
        val editor = prefs(context).edit()
        if (habitId.isNullOrBlank()) {
            editor.remove(KEY_PENDING_ADAPTIVE_ID)
        } else {
            editor.putString(KEY_PENDING_ADAPTIVE_ID, habitId)
        }
        editor.apply()
    }

    fun setPendingPinListPreset(
        context: Context,
        useAll: Boolean,
        habitIds: List<String>,
        customTitle: String?,
    ) {
        val editor = prefs(context).edit()
        editor.putString(KEY_PENDING_LIST_MODE, if (useAll) "all" else "custom")
        editor.putString(KEY_PENDING_LIST_IDS, JSONArray(habitIds).toString())
        if (customTitle.isNullOrBlank()) {
            editor.remove(KEY_PENDING_LIST_TITLE)
        } else {
            editor.putString(KEY_PENDING_LIST_TITLE, customTitle.trim())
        }
        editor.apply()
    }

    fun consumePendingAdaptivePreset(prefs: SharedPreferences): String? {
        val id = prefs.getString(KEY_PENDING_ADAPTIVE_ID, null)?.takeIf { it.isNotBlank() }
        if (id != null) {
            prefs.edit().remove(KEY_PENDING_ADAPTIVE_ID).apply()
        }
        return id
    }

    fun consumePendingListPreset(prefs: SharedPreferences): DailyListSelection? {
        val mode = prefs.getString(KEY_PENDING_LIST_MODE, null) ?: return null
        val ids = parseJsonStringList(prefs.getString(KEY_PENDING_LIST_IDS, null))
        val title = prefs.getString(KEY_PENDING_LIST_TITLE, "") ?: ""
        prefs.edit()
            .remove(KEY_PENDING_LIST_MODE)
            .remove(KEY_PENDING_LIST_IDS)
            .remove(KEY_PENDING_LIST_TITLE)
            .apply()
        return DailyListSelection(mode = mode, selectedIds = ids, customTitle = title)
    }

    fun getAdaptiveHabitId(prefs: SharedPreferences, widgetId: Int): String? =
        prefs.getString(adaptiveKey(widgetId), null)?.takeIf { it.isNotBlank() }

    fun getDailyListSelection(prefs: SharedPreferences, widgetId: Int): DailyListSelection {
        val mode = when (prefs.getString(listModeKey(widgetId), "default")) {
            "all" -> "all"
            "custom" -> "custom"
            else -> "default"
        }
        val ids = parseJsonStringList(prefs.getString(listIdsKey(widgetId), null))
        val title = prefs.getString(titleKey(widgetId), "") ?: ""
        return DailyListSelection(mode = mode, selectedIds = ids, customTitle = title)
    }

    fun saveAdaptiveConfig(
        context: Context,
        widgetId: Int,
        habitId: String,
        themeMode: String = "follow",
    ) {
        val p = prefs(context)
        val nextVer = p.getLong(cfgVerKey(widgetId), 0L) + 1L
        p.edit()
            .putString(adaptiveKey(widgetId), habitId)
            .putString(themeKey(widgetId), normalizeThemeMode(themeMode))
            .putLong(cfgVerKey(widgetId), nextVer)
            .commit()
    }

    fun saveDailyListConfig(
        context: Context,
        widgetId: Int,
        useAll: Boolean,
        habitIds: List<String>,
        customTitle: String,
        themeMode: String = "follow",
    ) {
        val p = prefs(context)
        val nextVer = p.getLong(cfgVerKey(widgetId), 0L) + 1L
        val cleanIds = habitIds.distinct().filter { it.isNotBlank() }
        val mode = if (useAll) "all" else "custom"
        val cleanTitle = customTitle.trim()
        val editor = p.edit()
            .putString(listModeKey(widgetId), mode)
            .putString(listIdsKey(widgetId), JSONArray(cleanIds).toString())
            .putString(themeKey(widgetId), normalizeThemeMode(themeMode))
            .putLong(cfgVerKey(widgetId), nextVer)
        if (cleanTitle.isEmpty()) {
            editor.remove(titleKey(widgetId))
        } else {
            editor.putString(titleKey(widgetId), cleanTitle)
        }
        editor.commit()
    }

    fun setPendingPinToDoPreset(context: Context, hideCompleted: Boolean, customTitle: String?) {
        val editor = prefs(context).edit()
            .putBoolean(KEY_PENDING_TODO_HIDE_DONE, hideCompleted)
        if (customTitle.isNullOrBlank()) {
            editor.remove(KEY_PENDING_TODO_TITLE)
        } else {
            editor.putString(KEY_PENDING_TODO_TITLE, customTitle.trim())
        }
        editor.apply()
    }

    fun consumePendingToDoPreset(prefs: SharedPreferences): Pair<Boolean, String>? {
        if (!prefs.contains(KEY_PENDING_TODO_HIDE_DONE)) return null
        val hide = prefs.getBoolean(KEY_PENDING_TODO_HIDE_DONE, false)
        val title = prefs.getString(KEY_PENDING_TODO_TITLE, "") ?: ""
        prefs.edit()
            .remove(KEY_PENDING_TODO_HIDE_DONE)
            .remove(KEY_PENDING_TODO_TITLE)
            .apply()
        return hide to title
    }

    fun setPendingPinDayModePreset(context: Context, includeAll: Boolean) {
        prefs(context).edit()
            .putBoolean(KEY_PENDING_DAY_MODE_ALL, includeAll)
            .apply()
    }

    fun consumePendingDayModePreset(prefs: SharedPreferences): Boolean? {
        if (!prefs.contains(KEY_PENDING_DAY_MODE_ALL)) return null
        val inc = prefs.getBoolean(KEY_PENDING_DAY_MODE_ALL, true)
        prefs.edit().remove(KEY_PENDING_DAY_MODE_ALL).apply()
        return inc
    }

    fun getToDoHideCompleted(prefs: SharedPreferences, widgetId: Int): Boolean =
        prefs.getBoolean(todoHideDoneKey(widgetId), false)

    fun hasToDoConfig(prefs: SharedPreferences, widgetId: Int): Boolean =
        prefs.contains(todoHideDoneKey(widgetId)) || prefs.contains(titleKey(widgetId))

    fun getCustomTitle(prefs: SharedPreferences, widgetId: Int): String =
        prefs.getString(titleKey(widgetId), "") ?: ""

    fun getDayModeIncludeAll(prefs: SharedPreferences, widgetId: Int): Boolean =
        prefs.getBoolean(dayModeIncludeAllKey(widgetId), true)

    fun hasDayModeConfig(prefs: SharedPreferences, widgetId: Int): Boolean =
        prefs.contains(dayModeIncludeAllKey(widgetId))

    fun saveToDoListConfig(
        context: Context,
        widgetId: Int,
        hideCompleted: Boolean,
        customTitle: String,
        themeMode: String = "follow",
    ) {
        val p = prefs(context)
        val nextVer = p.getLong(cfgVerKey(widgetId), 0L) + 1L
        val cleanTitle = customTitle.trim()
        val editor = p.edit()
            .putBoolean(todoHideDoneKey(widgetId), hideCompleted)
            .putString(themeKey(widgetId), normalizeThemeMode(themeMode))
            .putLong(cfgVerKey(widgetId), nextVer)
        if (cleanTitle.isEmpty()) {
            editor.remove(titleKey(widgetId))
        } else {
            editor.putString(titleKey(widgetId), cleanTitle)
        }
        editor.commit()
    }

    fun saveDayModeConfig(
        context: Context,
        widgetId: Int,
        includeAll: Boolean,
        themeMode: String = "follow",
    ) {
        val p = prefs(context)
        val nextVer = p.getLong(cfgVerKey(widgetId), 0L) + 1L
        p.edit()
            .putBoolean(dayModeIncludeAllKey(widgetId), includeAll)
            .putString(themeKey(widgetId), normalizeThemeMode(themeMode))
            .putLong(cfgVerKey(widgetId), nextVer)
            .commit()
    }

    fun cleanupDeletedWidgets(context: Context, widgetIds: IntArray) {
        if (widgetIds.isEmpty()) return
        val editor = prefs(context).edit()
        for (id in widgetIds) {
            editor.remove(adaptiveKey(id))
            editor.remove(listModeKey(id))
            editor.remove(listIdsKey(id))
            editor.remove(todoHideDoneKey(id))
            editor.remove(dayModeIncludeAllKey(id))
            editor.remove(titleKey(id))
            editor.remove(themeKey(id))
            editor.remove(cfgVerKey(id))
        }
        editor.apply()
    }

    fun readAdaptiveHabitsCatalog(prefs: SharedPreferences): List<JSONObject> {
        val all = parseJsonObject(prefs.getString(KEY_ADAPTIVE_ALL, null))
        val habitsObj = all.optJSONObject("habits") ?: return emptyList()
        val orderArr = all.optJSONArray("order")
        val seen = HashSet<String>()
        val result = ArrayList<JSONObject>()
        if (orderArr != null) {
            for (i in 0 until orderArr.length()) {
                val id = orderArr.optString(i, "")
                val h = if (id.isNotEmpty()) habitsObj.optJSONObject(id) else null
                if (h != null && seen.add(id)) {
                    result.add(h)
                }
            }
        }
        val keys = habitsObj.keys()
        while (keys.hasNext()) {
            val k = keys.next()
            if (seen.add(k)) {
                habitsObj.optJSONObject(k)?.let { result.add(it) }
            }
        }
        return result
    }

    fun resolveAdaptiveDefaultId(prefs: SharedPreferences): String {
        val all = parseJsonObject(prefs.getString(KEY_ADAPTIVE_ALL, null))
        val defId = all.optString("defaultId", "")
        if (defId.isNotEmpty()) return defId
        val orderArr = all.optJSONArray("order")
        if (orderArr != null && orderArr.length() > 0) {
            return orderArr.optString(0, "")
        }
        return parseJsonObject(prefs.getString(KEY_ADAPTIVE_LEGACY, null)).optString("id", "")
    }

    fun resolveAdaptivePayload(prefs: SharedPreferences, widgetId: Int): JSONObject {
        val all = parseJsonObject(prefs.getString(KEY_ADAPTIVE_ALL, null))
        if (all.length() > 0) {
            if (all.optBoolean("empty", false)) {
                return JSONObject().apply {
                    put("empty", true)
                    put("emptyMsg", all.optString("emptyMsg", "XHabit"))
                }
            }
            val habitsObj = all.optJSONObject("habits")
            if (habitsObj != null && habitsObj.length() > 0) {
                val chosenId = getAdaptiveHabitId(prefs, widgetId)
                if (chosenId != null) {
                    habitsObj.optJSONObject(chosenId)?.let { return it }
                }
                val defId = all.optString("defaultId", "")
                if (defId.isNotEmpty()) {
                    habitsObj.optJSONObject(defId)?.let { return it }
                }
                val orderArr = all.optJSONArray("order")
                if (orderArr != null) {
                    for (i in 0 until orderArr.length()) {
                        val id = orderArr.optString(i, "")
                        habitsObj.optJSONObject(id)?.let { return it }
                    }
                }
                val firstKey = habitsObj.keys().takeIf { it.hasNext() }?.next()
                if (firstKey != null) {
                    habitsObj.optJSONObject(firstKey)?.let { return it }
                }
            }
        }
        return parseJsonObject(prefs.getString(KEY_ADAPTIVE_LEGACY, null))
    }

    fun readDailyListCatalog(prefs: SharedPreferences): JSONObject =
        parseJsonObject(prefs.getString(KEY_LIST_ALL, null))

    fun resolveDailyListData(prefs: SharedPreferences, widgetId: Int): DailyListResolved {
        val cfgVer = getConfigVersion(prefs, widgetId)
        val allRoot = parseJsonObject(prefs.getString(KEY_LIST_ALL, null))
        val allHabits = allRoot.optJSONArray("allHabits")
        if (allRoot.length() == 0 || allHabits == null) {
            val legacy = parseJsonObject(prefs.getString(KEY_LIST_LEGACY, null))
            val legacyArr = legacy.optJSONArray("items") ?: JSONArray()
            val list = ArrayList<JSONObject>(legacyArr.length())
            for (i in 0 until legacyArr.length()) {
                legacyArr.optJSONObject(i)?.let { list.add(it) }
            }
            return DailyListResolved(
                headerTitle = legacy.optString("todayLabel", "Today"),
                doneCount = legacy.optInt("doneCount", 0),
                totalCount = legacy.optInt("totalCount", list.size),
                emptyMsg = legacy.optString("emptyMsg", "XHabit"),
                items = list,
                cfgVer = cfgVer,
            )
        }

        val selection = getDailyListSelection(prefs, widgetId)
        val useAll = when (selection.mode) {
            "all" -> true
            "custom" -> false
            else -> allRoot.optBoolean("useDefaultAll", true)
        }
        val activeFilterSet: Set<String>? = if (useAll) {
            null
        } else if (selection.mode == "custom") {
            selection.selectedIds.toHashSet()
        } else {
            val defArr = allRoot.optJSONArray("defaultIds")
            val set = HashSet<String>()
            if (defArr != null) {
                for (i in 0 until defArr.length()) {
                    val id = defArr.optString(i, "")
                    if (id.isNotEmpty()) set.add(id)
                }
            }
            set
        }

        val dueItems = ArrayList<JSONObject>()
        var doneCount = 0
        for (i in 0 until allHabits.length()) {
            val h = allHabits.optJSONObject(i) ?: continue
            val id = h.optString("id", "")
            if (activeFilterSet != null && !activeFilterSet.contains(id)) continue
            if (!h.optBoolean("isDueToday", false)) continue
            dueItems.add(h)
            if (h.optBoolean("done", false)) doneCount++
        }

        val todayLabel = allRoot.optString("todayLabel", "Today")
        val headerTitle = selection.customTitle.ifBlank { todayLabel }
        val emptyMsg = if (activeFilterSet != null && activeFilterSet.isEmpty()) {
            allRoot.optString("emptyUnconfiguredMsg", "Choose habits from widget settings")
        } else {
            allRoot.optString("emptyDueMsg", "No scheduled tasks due today")
        }

        return DailyListResolved(
            headerTitle = headerTitle,
            doneCount = doneCount,
            totalCount = dueItems.size,
            emptyMsg = emptyMsg,
            items = dueItems,
            cfgVer = cfgVer,
        )
    }

    fun readDayModePayload(prefs: SharedPreferences): JSONObject =
        parseJsonObject(prefs.getString(KEY_DAY_MODE_JSON, null))

    fun resolveToDoListData(prefs: SharedPreferences, widgetId: Int): ToDoListResolved {
        val cfgVer = getConfigVersion(prefs, widgetId)
        val root = parseJsonObject(prefs.getString(KEY_TODO_ALL, null))
        val allTasks = root.optJSONArray("tasks") ?: JSONArray()
        val hideCompleted = if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            getToDoHideCompleted(prefs, widgetId)
        } else {
            false
        }
        val customTitle = if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            getCustomTitle(prefs, widgetId)
        } else {
            ""
        }

        val items = ArrayList<JSONObject>()
        var doneCount = 0
        val totalAll = allTasks.length()
        for (i in 0 until totalAll) {
            val t = allTasks.optJSONObject(i) ?: continue
            val isDone = t.optBoolean("isDone", false)
            if (isDone) doneCount++
            if (hideCompleted && isDone) continue
            items.add(t)
        }

        val defaultTitle = root.optString("title", "To Do List")
        val headerTitle = customTitle.ifBlank { defaultTitle }
        val emptyMsg = if (totalAll == 0) {
            root.optString("emptyMsg", "To Do List is empty")
        } else if (hideCompleted && items.isEmpty()) {
            root.optString("allDoneMsg", "All tasks completed")
        } else {
            root.optString("emptyMsg", "To Do List is empty")
        }

        return ToDoListResolved(
            headerTitle = headerTitle,
            doneCount = doneCount,
            totalCount = totalAll,
            emptyMsg = emptyMsg,
            items = items,
            hideCompleted = hideCompleted,
            cfgVer = cfgVer,
        )
    }

    fun listPlacedWidgets(context: Context): List<Map<String, Any?>> {
        val manager = AppWidgetManager.getInstance(context)
        val p = prefs(context)
        val out = ArrayList<Map<String, Any?>>()

        val adaptiveIds = try {
            manager.getAppWidgetIds(ComponentName(context, AdaptiveHabitWidgetProvider::class.java))
        } catch (_: Throwable) {
            IntArray(0)
        }
        for (id in adaptiveIds) {
            val opts = manager.getAppWidgetOptions(id)
            val (wDp, hDp) = approxDp(context, opts, defaultW = 160f, defaultH = 80f)
            val payload = resolveAdaptivePayload(p, id)
            val resolvedHabitId = getAdaptiveHabitId(p, id)
                ?: payload.optString("id", "").takeIf { it.isNotEmpty() }
            out.add(
                mapOf(
                    "widgetId" to id,
                    "kind" to "adaptive",
                    "habitId" to resolvedHabitId,
                    "listMode" to "default",
                    "habitIds" to emptyList<String>(),
                    "customTitle" to "",
                    "hideCompleted" to false,
                    "includeAll" to true,
                    "themeMode" to getWidgetThemeMode(p, id),
                    "widthDp" to wDp.toInt(),
                    "heightDp" to hDp.toInt(),
                ),
            )
        }

        val listIds = try {
            manager.getAppWidgetIds(ComponentName(context, DailyListWidgetProvider::class.java))
        } catch (_: Throwable) {
            IntArray(0)
        }
        for (id in listIds) {
            val opts = manager.getAppWidgetOptions(id)
            val (wDp, hDp) = approxDp(context, opts, defaultW = 250f, defaultH = 180f)
            val sel = getDailyListSelection(p, id)
            out.add(
                mapOf(
                    "widgetId" to id,
                    "kind" to "daily_list",
                    "habitId" to null,
                    "listMode" to sel.mode,
                    "habitIds" to sel.selectedIds,
                    "customTitle" to sel.customTitle,
                    "hideCompleted" to false,
                    "includeAll" to true,
                    "themeMode" to getWidgetThemeMode(p, id),
                    "widthDp" to wDp.toInt(),
                    "heightDp" to hDp.toInt(),
                ),
            )
        }

        val todoIds = try {
            manager.getAppWidgetIds(ComponentName(context, ToDoListWidgetProvider::class.java))
        } catch (_: Throwable) {
            IntArray(0)
        }
        for (id in todoIds) {
            val opts = manager.getAppWidgetOptions(id)
            val (wDp, hDp) = approxDp(context, opts, defaultW = 250f, defaultH = 180f)
            out.add(
                mapOf(
                    "widgetId" to id,
                    "kind" to "todo_list",
                    "habitId" to null,
                    "listMode" to "default",
                    "habitIds" to emptyList<String>(),
                    "customTitle" to getCustomTitle(p, id),
                    "hideCompleted" to getToDoHideCompleted(p, id),
                    "includeAll" to true,
                    "themeMode" to getWidgetThemeMode(p, id),
                    "widthDp" to wDp.toInt(),
                    "heightDp" to hDp.toInt(),
                ),
            )
        }

        val dayModeIds = try {
            manager.getAppWidgetIds(ComponentName(context, DayModeWidgetProvider::class.java))
        } catch (_: Throwable) {
            IntArray(0)
        }
        for (id in dayModeIds) {
            val opts = manager.getAppWidgetOptions(id)
            val (wDp, hDp) = approxDp(context, opts, defaultW = 160f, defaultH = 80f)
            out.add(
                mapOf(
                    "widgetId" to id,
                    "kind" to "day_mode",
                    "habitId" to null,
                    "listMode" to "default",
                    "habitIds" to emptyList<String>(),
                    "customTitle" to "",
                    "hideCompleted" to false,
                    "includeAll" to getDayModeIncludeAll(p, id),
                    "themeMode" to getWidgetThemeMode(p, id),
                    "widthDp" to wDp.toInt(),
                    "heightDp" to hDp.toInt(),
                ),
            )
        }

        return out
    }

    private fun approxDp(
        context: Context,
        options: Bundle,
        defaultW: Float,
        defaultH: Float,
    ): Pair<Float, Float> {
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
        val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, defaultW.toInt()).toFloat()
        val maxW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minW.toInt()).toFloat()
        val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, defaultH.toInt()).toFloat()
        val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minH.toInt()).toFloat()
        return if (isLand) (maxW to minH) else (minW to maxH)
    }

    private fun normalizeThemeMode(mode: String): String = when (mode) {
        "dark" -> "dark"
        "light" -> "light"
        else -> "follow"
    }

    private fun parseJsonObject(raw: String?): JSONObject {
        if (raw.isNullOrBlank()) return JSONObject()
        return try {
            JSONObject(raw)
        } catch (_: Throwable) {
            JSONObject()
        }
    }

    private fun parseJsonStringList(raw: String?): List<String> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            val list = ArrayList<String>(arr.length())
            for (i in 0 until arr.length()) {
                val s = arr.optString(i, "")
                if (s.isNotEmpty()) list.add(s)
            }
            list
        } catch (_: Throwable) {
            emptyList()
        }
    }
}
