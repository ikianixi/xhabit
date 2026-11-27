package app.xhabit.tracker

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val audioTracks = HashMap<String, AudioTrack>()
    private var pendingFolderResult: MethodChannel.Result? = null
    private var pendingDocReadResult: MethodChannel.Result? = null

    companion object {
        private const val REQ_PICK_TREE = 4109
        private const val REQ_OPEN_JSON_DOC = 4110
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.xhabit.tracker/widgets")
            .setMethodCallHandler { call, result ->
                val manager = AppWidgetManager.getInstance(this)
                when (call.method) {
                    "pinAdaptiveWidget" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.isRequestPinAppWidgetSupported) {
                            val habitId = call.argument<String>("habitId")
                            WidgetConfigStore.setPendingPinAdaptivePreset(this, habitId)
                            val component = ComponentName(this, AdaptiveHabitWidgetProvider::class.java)
                            val launched = manager.requestPinAppWidget(component, null, null)
                            result.success(launched)
                        } else {
                            result.success(false)
                        }
                    }
                    "pinDailyListWidget" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.isRequestPinAppWidgetSupported) {
                            val useAll = call.argument<Boolean>("useAll") ?: true
                            val habitIds = (call.argument<List<*>>("habitIds") ?: emptyList<Any>())
                                .mapNotNull { it?.toString() }
                            val customTitle = call.argument<String>("customTitle")
                            WidgetConfigStore.setPendingPinListPreset(this, useAll, habitIds, customTitle)
                            val component = ComponentName(this, DailyListWidgetProvider::class.java)
                            val launched = manager.requestPinAppWidget(component, null, null)
                            result.success(launched)
                        } else {
                            result.success(false)
                        }
                    }
                    "pinToDoWidget" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.isRequestPinAppWidgetSupported) {
                            val hideCompleted = call.argument<Boolean>("hideCompleted") ?: false
                            val customTitle = call.argument<String>("customTitle")
                            WidgetConfigStore.setPendingPinToDoPreset(this, hideCompleted, customTitle)
                            val component = ComponentName(this, ToDoListWidgetProvider::class.java)
                            val launched = manager.requestPinAppWidget(component, null, null)
                            result.success(launched)
                        } else {
                            result.success(false)
                        }
                    }
                    "pinDayModeWidget" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.isRequestPinAppWidgetSupported) {
                            val includeAll = call.argument<Boolean>("includeAll") ?: true
                            WidgetConfigStore.setPendingPinDayModePreset(this, includeAll)
                            val component = ComponentName(this, DayModeWidgetProvider::class.java)
                            val launched = manager.requestPinAppWidget(component, null, null)
                            result.success(launched)
                        } else {
                            result.success(false)
                        }
                    }
                    "listPlacedWidgets" -> {
                        try {
                            result.success(WidgetConfigStore.listPlacedWidgets(this))
                        } catch (_: Throwable) {
                            result.success(emptyList<Map<String, Any?>>())
                        }
                    }
                    "updateWidgetConfig" -> {
                        val widgetId = call.argument<Number>("widgetId")?.toInt()
                            ?: AppWidgetManager.INVALID_APPWIDGET_ID
                        val kind = call.argument<String>("kind") ?: ""
                        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val themeMode = call.argument<String>("themeMode") ?: "follow"
                        try {
                            if (kind == "adaptive") {
                                val habitId = call.argument<String>("habitId") ?: ""
                                if (habitId.isNotBlank()) {
                                    WidgetConfigStore.saveAdaptiveConfig(
                                        context = this,
                                        widgetId = widgetId,
                                        habitId = habitId,
                                        themeMode = themeMode,
                                    )
                                    AdaptiveHabitWidgetProvider.updateWidgetById(this, widgetId)
                                    result.success(true)
                                    return@setMethodCallHandler
                                }
                            } else if (kind == "daily_list") {
                                val useAll = call.argument<Boolean>("useAll") ?: true
                                val habitIds = (call.argument<List<*>>("habitIds") ?: emptyList<Any>())
                                    .mapNotNull { it?.toString() }
                                val customTitle = call.argument<String>("customTitle") ?: ""
                                WidgetConfigStore.saveDailyListConfig(
                                    context = this,
                                    widgetId = widgetId,
                                    useAll = useAll,
                                    habitIds = habitIds,
                                    customTitle = customTitle,
                                    themeMode = themeMode,
                                )
                                DailyListWidgetProvider.updateWidgetById(this, widgetId)
                                result.success(true)
                                return@setMethodCallHandler
                            } else if (kind == "todo_list") {
                                val hideCompleted = call.argument<Boolean>("hideCompleted") ?: false
                                val customTitle = call.argument<String>("customTitle") ?: ""
                                WidgetConfigStore.saveToDoListConfig(
                                    context = this,
                                    widgetId = widgetId,
                                    hideCompleted = hideCompleted,
                                    customTitle = customTitle,
                                    themeMode = themeMode,
                                )
                                ToDoListWidgetProvider.updateWidgetById(this, widgetId)
                                result.success(true)
                                return@setMethodCallHandler
                            } else if (kind == "day_mode") {
                                val includeAll = call.argument<Boolean>("includeAll") ?: true
                                WidgetConfigStore.saveDayModeConfig(
                                    context = this,
                                    widgetId = widgetId,
                                    includeAll = includeAll,
                                    themeMode = themeMode,
                                )
                                DayModeWidgetProvider.updateWidgetById(this, widgetId)
                                result.success(true)
                                return@setMethodCallHandler
                            }
                            result.success(false)
                        } catch (_: Throwable) {
                            result.success(false)
                        }
                    }
                    "openWidgetConfigure" -> {
                        val widgetId = call.argument<Number>("widgetId")?.toInt()
                            ?: AppWidgetManager.INVALID_APPWIDGET_ID
                        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            val cfgIntent = Intent(this, WidgetConfigureActivity::class.java).apply {
                                action = AppWidgetManager.ACTION_APPWIDGET_CONFIGURE
                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                            }
                            startActivity(cfgIntent)
                            result.success(true)
                        } catch (_: Throwable) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.xhabit.tracker/audio")
            .setMethodCallHandler { call, result ->
                if (call.method == "playPcm") {
                    val key = call.argument<String>("key") ?: "default"
                    val pcm = call.argument<ByteArray>("pcm")
                    val sampleRate = call.argument<Int>("sampleRate") ?: 44100
                    if (pcm == null || pcm.isEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        playStaticPcm(key, pcm, sampleRate)
                        result.success(true)
                    } catch (_: Throwable) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.xhabit.tracker/storage_ui")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickTreeFolder" -> {
                        pendingFolderResult?.success(null)
                        pendingFolderResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                            )
                        }
                        try {
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, REQ_PICK_TREE)
                        } catch (_: Throwable) {
                            val pending = pendingFolderResult
                            pendingFolderResult = null
                            pending?.success(null)
                        }
                    }
                    "pickJsonDocument" -> {
                        pendingDocReadResult?.success(null)
                        pendingDocReadResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain"))
                        }
                        try {
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, REQ_OPEN_JSON_DOC)
                        } catch (_: Throwable) {
                            val pending = pendingDocReadResult
                            pendingDocReadResult = null
                            pending?.success(null)
                        }
                    }
                    "launchCalendarInsert" -> {
                        val title = call.argument<String>("title") ?: "XHabit"
                        val desc = call.argument<String>("description") ?: ""
                        val beginMs = call.argument<Number>("beginTimeMs")?.toLong() ?: System.currentTimeMillis()
                        val endMs = call.argument<Number>("endTimeMs")?.toLong() ?: (beginMs + 1800000L)
                        val rrule = call.argument<String>("rrule") ?: "FREQ=DAILY"
                        try {
                            val intent = Intent(Intent.ACTION_INSERT).apply {
                                data = CalendarContract.Events.CONTENT_URI
                                putExtra(CalendarContract.Events.TITLE, title)
                                putExtra(CalendarContract.Events.DESCRIPTION, desc)
                                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, beginMs)
                                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMs)
                                putExtra(CalendarContract.Events.RRULE, rrule)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Throwable) {
                            result.success(false)
                        }
                    }
                    "installApk" -> {
                        val filePath = call.argument<String>("filePath") ?: ""
                        val apkFile = File(filePath)
                        if (filePath.isBlank() || !apkFile.exists()) {
                            result.success("error")
                            return@setMethodCallHandler
                        }
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                !packageManager.canRequestPackageInstalls()
                            ) {
                                val permIntent = Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(permIntent)
                                result.success("needs_permission")
                                return@setMethodCallHandler
                            }
                            val apkUri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                apkFile,
                            )
                            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_ACTIVITY_NEW_TASK,
                                )
                            }
                            startActivity(installIntent)
                            result.success("launched")
                        } catch (_: Throwable) {
                            result.success("error")
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PICK_TREE) {
            val res = pendingFolderResult
            pendingFolderResult = null
            val treeUri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (treeUri != null) {
                try {
                    val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    contentResolver.takePersistableUriPermission(treeUri, flags)
                } catch (_: Throwable) {
                }
                res?.success(treeUri.toString())
            } else {
                res?.success(null)
            }
        } else if (requestCode == REQ_OPEN_JSON_DOC) {
            val res = pendingDocReadResult
            pendingDocReadResult = null
            val docUri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (docUri == null) {
                res?.success(null)
                return
            }
            try {
                val text = contentResolver.openInputStream(docUri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
                res?.success(text)
            } catch (_: Throwable) {
                res?.success(null)
            }
        }
    }

    private fun playStaticPcm(key: String, pcm: ByteArray, sampleRate: Int) {
        var track = audioTracks[key]
        if (track == null || track.state != AudioTrack.STATE_INITIALIZED) {
            track?.release()
            track = buildStaticTrack(pcm, sampleRate)
            audioTracks[key] = track
        } else {
            try {
                if (track.playState == AudioTrack.PLAYSTATE_PLAYING) {
                    track.pause()
                }
                track.stop()
                track.setPlaybackHeadPosition(0)
                if (track.reloadStaticData() < 0) {
                    track.release()
                    track = buildStaticTrack(pcm, sampleRate)
                    audioTracks[key] = track
                }
            } catch (_: Throwable) {
                track.release()
                track = buildStaticTrack(pcm, sampleRate)
                audioTracks[key] = track
            }
        }
        if (track.state == AudioTrack.STATE_INITIALIZED) {
            track.play()
        }
    }

    private fun buildStaticTrack(pcm: ByteArray, sampleRate: Int): AudioTrack {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val format = AudioFormat.Builder()
            .setSampleRate(sampleRate)
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .build()
        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufBytes = if (minBuf > 0) maxOf(pcm.size, minBuf) else pcm.size
        val track = AudioTrack.Builder()
            .setAudioAttributes(attrs)
            .setAudioFormat(format)
            .setBufferSizeInBytes(bufBytes)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        if (track.state != AudioTrack.STATE_INITIALIZED) {
            track.release()
            throw IllegalStateException("AudioTrack failed to initialize")
        }
        track.write(pcm, 0, pcm.size)
        return track
    }

    override fun onDestroy() {
        for (track in audioTracks.values) {
            try {
                track.release()
            } catch (_: Throwable) {
            }
        }
        audioTracks.clear()
        super.onDestroy()
    }
}
