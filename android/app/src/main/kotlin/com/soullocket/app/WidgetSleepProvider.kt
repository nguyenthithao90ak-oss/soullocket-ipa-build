package com.soullocket.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class WidgetSleepProvider : HomeWidgetProvider() {

    companion object {
        private const val TAG = "WidgetSleepProvider"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_sleep).apply {
                    val myName = widgetData.getString("sleep_my_name", "Bạn Nam") ?: "Bạn Nam"
                    val partnerName = widgetData.getString("sleep_partner_name", "Người ấy") ?: "Người ấy"
                    val myStatus = widgetData.getString("sleep_my_status", "☀️ Đang thức") ?: "☀️ Đang thức"
                    val partnerStatus = widgetData.getString("sleep_partner_status", "☀️ Đang thức") ?: "☀️ Đang thức"
                    val myTime = widgetData.getString("sleep_my_time", "Đang hoạt động") ?: "Đang hoạt động"
                    val partnerTime = widgetData.getString("sleep_partner_time", "Đang hoạt động") ?: "Đang hoạt động"
                    val summary = widgetData.getString("sleep_summary", "Cả 2 cùng thức ☀️") ?: "Cả 2 cùng thức ☀️"

                    setTextViewText(R.id.tv_my_name, myName)
                    setTextViewText(R.id.tv_partner_name, partnerName)
                    setTextViewText(R.id.tv_my_status, myStatus)
                    setTextViewText(R.id.tv_partner_status, partnerStatus)
                    setTextViewText(R.id.tv_my_time, myTime)
                    setTextViewText(R.id.tv_partner_time, partnerTime)
                    setTextViewText(R.id.tv_sleep_summary, summary)

                    val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (openAppIntent != null) {
                        val pendingIntent = PendingIntent.getActivity(
                            context,
                            appWidgetId,
                            openAppIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                    }
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating sleep widget $appWidgetId", e)
            }
        }
    }
}
