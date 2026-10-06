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
                    fun text(key: String, fallbackRes: Int): String =
                        widgetData.getString(key, null) ?: context.getString(fallbackRes)
                    val myName = text("sleep_my_name", R.string.widget_default_me)
                    val partnerName = text("sleep_partner_name", R.string.widget_default_partner)
                    val myStatus = text("sleep_my_status", R.string.widget_sleep_status_awake)
                    val partnerStatus = text("sleep_partner_status", R.string.widget_sleep_status_awake)
                    val myTime = text("sleep_my_time", R.string.widget_sleep_time_active)
                    val partnerTime = text("sleep_partner_time", R.string.widget_sleep_time_active)
                    val summary = text("sleep_summary", R.string.widget_sleep_summary_default)

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
