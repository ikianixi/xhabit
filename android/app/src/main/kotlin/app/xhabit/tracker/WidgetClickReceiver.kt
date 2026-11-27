package app.xhabit.tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

/**
 * Lightweight BroadcastReceiver for RemoteViews ListView item clicks.
 * Routes toggle/sub-step actions directly to HomeWidgetBackgroundIntent without
 * launching any overlay or trampoline Activity, and opens MainActivity for open URIs.
 */
class WidgetClickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val uriStr = intent.getStringExtra("xhabit_uri") ?: intent.dataString ?: return
        if (uriStr.isBlank()) return
        val uri = Uri.parse(uriStr)
        if (uri.host == "open") {
            try {
                val launch = Intent(context, MainActivity::class.java).apply {
                    action = "es.antonborri.home_widget.action.LAUNCH"
                    data = uri
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                context.startActivity(launch)
            } catch (_: Throwable) {
            }
        } else {
            HomeWidgetBackgroundIntent.getBroadcast(context.applicationContext, uri).send()
        }
    }
}
