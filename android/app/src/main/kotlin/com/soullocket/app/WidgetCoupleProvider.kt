package com.soullocket.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import org.json.JSONArray
import kotlin.math.cos
import kotlin.math.sin

class WidgetCoupleProvider : HomeWidgetProvider() {

    companion object {
        private const val TAG = "WidgetCoupleProvider"
        private const val ACTION_WIDGET_REFRESH = "com.soullocket.app.action.WIDGET_REFRESH"
        private const val ACTION_WIDGET_CLICK = "com.soullocket.app.action.WIDGET_CLICK"
        private const val ACTION_OPEN_DIARY = "diary"
        private const val ACTION_OPEN_LOVE = "love"
        private const val ACTION_OPEN_CALENDAR = "calendar"
        private const val REFRESH_INTERVAL_MS = 6_000L
        private const val HEART_BITMAP_SIZE = 180
        private const val DIARY_PREVIEW_WIDTH = 168
        private const val DIARY_PREVIEW_HEIGHT = 244
        private const val DIARY_PREVIEW_RADIUS = 24f
        private const val EVENT_BADGE_WIDTH = 264
        private const val EVENT_BADGE_HEIGHT = 84
        private const val PREMIUM_BG_WIDTH = 1080
        private const val PREMIUM_BG_HEIGHT = 680
        private val ANIMATED_HEART_EMOJIS =
            listOf(
                "\uD83E\uDD0D", // 🤍
                "\uD83E\uDD0E", // 🤎
                "\u2665\uFE0F", // ♥️
                "\u2763\uFE0F", // ❣️
                "\u2764\uFE0F", // ❤️
                "\uD83D\uDC9E", // 💞
                "\uD83D\uDDA4", // 🖤
                "\uD83D\uDC9F", // 💟
                "\u2764\uFE0F\u200D\uD83D\uDD25", // ❤️‍🔥
                "\uD83E\uDE77", // 🩷
                "\uD83E\uDE76", // 🩶
                "\uD83E\uDE75", // 🩵
                "\uD83D\uDC98", // 💘
                "\u2764\uFE0F\u200D\uD83E\uDE79", // ❤️‍🩹
                "\uD83D\uDC93", // 💓
            )
        private val DEFAULT_HEART_PRIMARY = Color.parseColor("#FF4D73")
        private val DEFAULT_HEART_SECONDARY = Color.parseColor("#FF7D96")
        private val DEFAULT_HEART_GLOW = Color.parseColor("#FFF4F7")
        private val DEFAULT_HEART_SPARK = Color.parseColor("#FFF7C2")
    }

    private data class HeartPalette(
        val primary: Int,
        val secondary: Int,
        val glow: Int,
        val spark: Int,
    )

    private data class ThemeColors(
        val backgroundRes: Int,
        val nameColor: Int,
        val weatherColor: Int,
        val daysColor: Int,
        val starsColor: Int,
        val accentColor: Int,
        val accentSoftColor: Int,
        val statusOnlineColor: Int,
        val statusOfflineColor: Int,
        val badgeTextColor: Int,
        val badgeBackgroundColor: Int,
        val diaryFrameColor: Int,
    )

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleNextRefresh(context)
    }

    override fun onDisabled(context: Context) {
        cancelScheduledRefresh(context)
        super.onDisabled(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_WIDGET_CLICK) {
            val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                val widgetData = HomeWidgetPlugin.getData(context)
                val currentClick = widgetData.getInt("clickCount_$appWidgetId", 0)
                widgetData.edit().putInt("clickCount_$appWidgetId", currentClick + 1).apply()

                val appWidgetManager = AppWidgetManager.getInstance(context)
                onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), widgetData)
            }
            return
        }
        if (intent.action != ACTION_WIDGET_REFRESH) return

        val appWidgetManager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, WidgetCoupleProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(provider)
        if (appWidgetIds.isEmpty()) {
            cancelScheduledRefresh(context)
            return
        }

        val widgetData = HomeWidgetPlugin.getData(context)
        onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        var shouldKeepRefreshing = false
        for (appWidgetId in appWidgetIds) {
            val widgetStyleKey =
                (widgetData.getString("widgetStyleKey", "classic") ?: "classic").trim().lowercase()
            val isCountdownStyle = widgetStyleKey == "countdown"
            val showDiary = widgetData.getBoolean("showDiaryOnWidget", false)
            val showHeartCluster = !showDiary && !isCountdownStyle
            val diaryPaths = getDiaryImagePaths(widgetData)
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_couple).apply {
                    val bgTheme = widgetData.getString("bgTheme", "pink") ?: "pink"
                    val heartAnimated =
                        widgetData.getBoolean("heartAnimated", true) && showHeartCluster
                    val heartStyleKey = widgetData.getString("heartStyleKey", "❤️") ?: "❤️"
                    val heartColorKey = widgetData.getString("heartColorKey", "rose") ?: "rose"
                    val heartPalette = resolveHeartPalette(heartColorKey)
                    val diaryLayoutKey =
                        widgetData.getString("diaryLayoutKey", "single") ?: "single"
                    val seasonResolvedKey =
                        widgetData.getString("seasonResolvedKey", "none") ?: "none"
                    val themeColors = resolveThemeColors(
                        bgTheme = bgTheme,
                        heartPalette = heartPalette,
                        seasonKey = seasonResolvedKey,
                    )
                    val dynamicBackground = createDynamicBackgroundBitmap(
                        appWidgetId = appWidgetId,
                        bgTheme = bgTheme,
                        seasonKey = seasonResolvedKey,
                        themeColors = themeColors,
                        motionEnabled = heartAnimated && !isCountdownStyle,
                    )

                    setInt(R.id.widget_root, "setBackgroundResource", themeColors.backgroundRes)
                    if (dynamicBackground != null) {
                        setViewVisibility(R.id.iv_widget_background, View.VISIBLE)
                        setImageViewBitmap(R.id.iv_widget_background, dynamicBackground)
                    } else {
                        setViewVisibility(R.id.iv_widget_background, View.GONE)
                    }
                    setViewVisibility(R.id.iv_event_badge, View.GONE)
                    setViewVisibility(
                        R.id.classic_mode_block,
                        if (isCountdownStyle) View.GONE else View.VISIBLE
                    )
                    setViewVisibility(
                        R.id.countdown_mode_block,
                        if (isCountdownStyle) View.VISIBLE else View.GONE
                    )
                    setTextColor(R.id.tv_name_1, themeColors.nameColor)
                    setTextColor(R.id.tv_name_2, themeColors.nameColor)
                    setTextColor(R.id.tv_weather_1, themeColors.weatherColor)
                    setTextColor(R.id.tv_weather_2, themeColors.weatherColor)
                    setTextColor(R.id.tv_days, themeColors.daysColor)
                    setTextColor(R.id.tv_days_countdown, themeColors.daysColor)
                    setTextColor(R.id.tv_days_countdown_unit, themeColors.daysColor)
                    setTextColor(R.id.tv_love_date, themeColors.weatherColor)
                    setTextColor(R.id.tv_stars_1, themeColors.starsColor)
                    setTextColor(R.id.tv_stars_2, themeColors.starsColor)
                    if (showHeartCluster) {
                        setViewVisibility(R.id.heart_cluster_slot, View.VISIBLE)
                        setViewVisibility(R.id.iv_heart_cluster, View.VISIBLE)
                        setImageViewBitmap(
                            R.id.iv_heart_cluster,
                            createHeartBitmap(
                                appWidgetId = appWidgetId,
                                animated = heartAnimated,
                                styleKey = heartStyleKey,
                                palette = heartPalette,
                            )
                        )
                    } else {
                        setViewVisibility(R.id.heart_cluster_slot, View.GONE)
                        setViewVisibility(R.id.iv_heart_cluster, View.GONE)
                    }
                    if (isCountdownStyle) {
                        setViewVisibility(R.id.iv_countdown_heart, View.VISIBLE)
                        setImageViewBitmap(
                            R.id.iv_countdown_heart,
                            createHeartBitmap(
                                appWidgetId = appWidgetId,
                                animated = false,
                                styleKey = heartStyleKey,
                                palette = heartPalette,
                            )
                        )
                    }

                    val name1 = widgetData.getString("name1", "Bạn") ?: "Bạn"
                    val name2 = widgetData.getString("name2", "Người ấy") ?: "Người ấy"
                    setTextViewText(R.id.tv_name_1, name1)
                    setTextViewText(R.id.tv_name_2, name2)

                    val status1 = widgetData.getString("status1", "")
                    val status2 = widgetData.getString("status2", "")
                    val isOnline1 = widgetData.getBoolean("isOnline1", true)
                    val isOnline2 = widgetData.getBoolean("isOnline2", false)

                    if (shouldHideStatus(status1)) {
                        setViewVisibility(R.id.tv_status_1, View.GONE)
                    } else {
                        setViewVisibility(R.id.tv_status_1, View.VISIBLE)
                        setTextViewText(R.id.tv_status_1, status1)
                        setTextColor(
                            R.id.tv_status_1,
                            if (isOnline1) themeColors.statusOnlineColor
                            else themeColors.statusOfflineColor
                        )
                    }

                    if (shouldHideStatus(status2)) {
                        setViewVisibility(R.id.tv_status_2, View.GONE)
                    } else {
                        setViewVisibility(R.id.tv_status_2, View.VISIBLE)
                        setTextViewText(R.id.tv_status_2, status2)
                        setTextColor(
                            R.id.tv_status_2,
                            if (isOnline2) themeColors.statusOnlineColor
                            else themeColors.statusOfflineColor
                        )
                    }

                    val weather1 = widgetData.getString("weather1", "")
                    val weather2 = widgetData.getString("weather2", "")
                    if (weather1.isNullOrEmpty()) {
                        setViewVisibility(R.id.tv_weather_1, View.GONE)
                    } else {
                        setViewVisibility(R.id.tv_weather_1, View.VISIBLE)
                        setTextViewText(R.id.tv_weather_1, weather1)
                    }

                    if (weather2.isNullOrEmpty()) {
                        setViewVisibility(R.id.tv_weather_2, View.GONE)
                    } else {
                        setViewVisibility(R.id.tv_weather_2, View.VISIBLE)
                        setTextViewText(R.id.tv_weather_2, weather2)
                    }

                    setViewVisibility(R.id.tv_stars_1, View.GONE)
                    setViewVisibility(R.id.tv_stars_2, View.GONE)

                    val daysRaw = widgetData.getString("daysText", "0") ?: "0"
                    setTextViewText(R.id.tv_days, formatDaysStackedText(daysRaw))
                    setTextViewText(R.id.tv_days_countdown, extractDaysDigits(daysRaw))
                    val loveDateText = widgetData.getString("loveDateText", "") ?: ""
                    if (loveDateText.isBlank()) {
                        setViewVisibility(R.id.tv_love_date, View.GONE)
                    } else {
                        setViewVisibility(R.id.tv_love_date, View.VISIBLE)
                        setTextViewText(R.id.tv_love_date, formatLoveDateLabel(loveDateText))
                    }

                    val avatar1Path = widgetData.getString("avatar1Path", null)
                    if (!avatar1Path.isNullOrBlank()) {
                        val bitmap = getRoundedCroppedBitmap(
                            decodeSampledBitmapFromFile(avatar1Path, 150, 150)
                        )
                        if (bitmap != null) {
                            setImageViewBitmap(R.id.iv_avatar_1, bitmap)
                            setImageViewBitmap(R.id.iv_avatar_1_countdown, bitmap)
                        }
                    }

                    val avatar2Path = widgetData.getString("avatar2Path", null)
                    if (!avatar2Path.isNullOrBlank()) {
                        val bitmap = getRoundedCroppedBitmap(
                            decodeSampledBitmapFromFile(avatar2Path, 150, 150)
                        )
                        if (bitmap != null) {
                            setImageViewBitmap(R.id.iv_avatar_2, bitmap)
                            setImageViewBitmap(R.id.iv_avatar_2_countdown, bitmap)
                        }
                    }

                    // 📸 Debug: Log diary status
                    Log.d(TAG, "Diary Widget: showDiary=$showDiary, pathCount=${diaryPaths.size}")

                    if (!isCountdownStyle && showDiary && diaryPaths.isNotEmpty()) {
                        try {
                            val diaryBitmap = createDiaryCollageBitmap(
                                diaryPaths = diaryPaths,
                                layoutKey = diaryLayoutKey,
                                themeColors = themeColors,
                            )
                            if (diaryBitmap != null) {
                                setImageViewBitmap(R.id.diary_preview, diaryBitmap)
                                setViewVisibility(R.id.diary_preview, View.VISIBLE)
                            } else {
                                setViewVisibility(R.id.diary_preview, View.GONE)
                            }
                            Log.d(TAG, "✅ Diary list attached successfully")
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Error attaching diary list", e)
                            setViewVisibility(R.id.diary_preview, View.GONE)
                        }
                    } else {
                        if (!showDiary) Log.d(TAG, "Diary widget disabled")
                        if (diaryPaths.isEmpty()) Log.d(TAG, "No diary images available")
                        setViewVisibility(R.id.diary_preview, View.GONE)
                    }

                    // Open App Intent
                    val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    val diaryPendingIntent =
                        createLaunchPendingIntent(context, ACTION_OPEN_DIARY, appWidgetId)
                    val lovePendingIntent =
                        createLaunchPendingIntent(context, ACTION_OPEN_LOVE, appWidgetId)
                    val calendarPendingIntent =
                        createLaunchPendingIntent(context, ACTION_OPEN_CALENDAR, appWidgetId)
                    diaryPendingIntent?.let {
                        setOnClickPendingIntent(R.id.iv_avatar_1, it)
                        setOnClickPendingIntent(R.id.iv_avatar_2, it)
                        setOnClickPendingIntent(R.id.iv_avatar_1_countdown, it)
                        setOnClickPendingIntent(R.id.iv_avatar_2_countdown, it)
                        setOnClickPendingIntent(R.id.diary_preview, it)
                    }
                    lovePendingIntent?.let {
                        setOnClickPendingIntent(R.id.iv_heart_cluster, it)
                        setOnClickPendingIntent(R.id.iv_countdown_heart, it)
                    }
                    calendarPendingIntent?.let {
                        setOnClickPendingIntent(R.id.tv_days, it)
                        setOnClickPendingIntent(R.id.tv_days_countdown, it)
                        setOnClickPendingIntent(R.id.tv_love_date, it)
                        setOnClickPendingIntent(R.id.iv_event_badge, it)
                    }
                    if (openAppIntent != null) {
                        val openAppPendingIntent = PendingIntent.getActivity(
                            context,
                            appWidgetId,
                            openAppIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)
                    }
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
                shouldKeepRefreshing =
                    shouldKeepRefreshing ||
                        (widgetData.getBoolean("heartAnimated", true) && showHeartCluster)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widgetId=$appWidgetId", e)
            }
        }

        if (shouldKeepRefreshing) {
            scheduleNextRefresh(context)
        } else {
            cancelScheduledRefresh(context)
        }
    }

    private fun shouldHideStatus(status: String?): Boolean {
        val normalized = status?.trim()?.lowercase() ?: return true
        if (normalized.isEmpty()) return true
        return normalized == "mo app de dong bo" ||
            normalized == "mo app de cap nhat" ||
            normalized == "mở app để cập nhật" ||
            normalized == "chạm để đồng bộ"
    }

    private fun createLaunchPendingIntent(
        context: Context,
        action: String,
        appWidgetId: Int,
    ): PendingIntent? {
        return try {
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("soullocket://widget/$action?widgetId=$appWidgetId&action=$action"),
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to build widget launch intent for action=$action", e)
            null
        }
    }

    private fun extractDaysDigits(daysRaw: String): String {
        val digits = Regex("\\d+").find(daysRaw)?.value ?: daysRaw.trim()
        return if (digits.isBlank()) "0" else digits
    }

    private fun formatDaysStackedText(daysRaw: String): String {
        return "${extractDaysDigits(daysRaw)}\nng\u00E0y"
    }

    private fun formatDaysText(daysRaw: String): String {
        val digits = Regex("\\d+").find(daysRaw)?.value ?: daysRaw.trim()
        return if (digits.isBlank()) "0 ngày" else "$digits ngày"
    }

    private fun formatLoveDateLabel(loveDateRaw: String): String {
        val normalized = loveDateRaw.trim()
        return if (normalized.isBlank()) "" else "Tu $normalized"
    }

    private fun getDiaryImagePaths(widgetData: SharedPreferences): List<String> {
        val raw = widgetData.getString("diaryImagePaths", null)
        if (raw.isNullOrBlank()) {
            Log.d(TAG, "No diary image paths stored")
            return emptyList()
        }
        return runCatching {
            val json = JSONArray(raw)
            buildList {
                for (index in 0 until json.length()) {
                    val path = json.optString(index).trim()
                    val file = File(path)
                    
                    // ✅ Kiểm tra file hợp lệ
                    if (path.isNotEmpty() && file.exists() && file.length() > 0) {
                        add(path)
                    } else {
                        if (!file.exists()) {
                            Log.w(TAG, "Diary image file not found: $path")
                        } else if (file.length() == 0L) {
                            Log.w(TAG, "Diary image file is empty: $path")
                        }
                    }
                }
            }
        }.onFailure {
            Log.e(TAG, "Failed to parse diary widget paths: $raw", it)
        }.getOrDefault(emptyList())
    }

    private fun scheduleNextRefresh(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val triggerAtMillis = System.currentTimeMillis() + REFRESH_INTERVAL_MS
        alarmManager.set(
            AlarmManager.RTC,
            triggerAtMillis,
            refreshPendingIntent(context)
        )
    }

    private fun cancelScheduledRefresh(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarmManager.cancel(refreshPendingIntent(context))
    }

    private fun refreshPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, WidgetCoupleProvider::class.java).apply {
            action = ACTION_WIDGET_REFRESH
            data = Uri.parse("widget-refresh://${context.packageName}")
        }
        return PendingIntent.getBroadcast(
            context,
            7011,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun resolveThemeColors(
        bgTheme: String,
        heartPalette: HeartPalette,
        seasonKey: String,
    ): ThemeColors {
        val seasonPalette = resolveSeasonPalette(seasonKey)
        val accentColor = seasonPalette?.first ?: heartPalette.primary
        val accentSoftColor =
            seasonPalette?.second ?: mixColors(heartPalette.secondary, Color.WHITE, 0.38f)

        val backgroundRes: Int
        val nameColor: Int
        val weatherBase: Int
        val daysBase: Int
        val starsBase: Int
        val darkSurface: Boolean

        when (bgTheme) {
            "dark" -> {
                backgroundRes = R.drawable.widget_bg_dark
                nameColor = Color.WHITE
                weatherBase = Color.parseColor("#AEB8C7")
                daysBase = Color.WHITE
                starsBase = Color.parseColor("#E9D5FF")
                darkSurface = true
            }
            "white" -> {
                backgroundRes = R.drawable.widget_bg_white
                nameColor = Color.parseColor("#333333")
                weatherBase = Color.parseColor("#667085")
                daysBase = Color.parseColor("#FF4D73")
                starsBase = Color.parseColor("#FF4D73")
                darkSurface = false
            }
            "blue" -> {
                backgroundRes = R.drawable.widget_bg_blue
                nameColor = Color.parseColor("#0D47A1")
                weatherBase = Color.parseColor("#356AA0")
                daysBase = Color.parseColor("#0F52BA")
                starsBase = Color.parseColor("#0284C7")
                darkSurface = false
            }
            "orange" -> {
                backgroundRes = R.drawable.widget_bg_orange
                nameColor = Color.parseColor("#E65100")
                weatherBase = Color.parseColor("#A85A1C")
                daysBase = Color.parseColor("#F97316")
                starsBase = Color.parseColor("#EA580C")
                darkSurface = false
            }
            "purple" -> {
                backgroundRes = R.drawable.widget_bg_purple
                nameColor = Color.parseColor("#6A1B9A")
                weatherBase = Color.parseColor("#7B5A91")
                daysBase = Color.parseColor("#8B5CF6")
                starsBase = Color.parseColor("#A855F7")
                darkSurface = false
            }
            "green" -> {
                backgroundRes = R.drawable.widget_bg_green
                nameColor = Color.parseColor("#1B5E20")
                weatherBase = Color.parseColor("#3A7A43")
                daysBase = Color.parseColor("#16A34A")
                starsBase = Color.parseColor("#10B981")
                darkSurface = false
            }
            "red" -> {
                backgroundRes = R.drawable.widget_bg_red
                nameColor = Color.parseColor("#B71C1C")
                weatherBase = Color.parseColor("#9A5151")
                daysBase = Color.parseColor("#E11D48")
                starsBase = Color.parseColor("#FB7185")
                darkSurface = false
            }
            "premium" -> {
                backgroundRes = R.drawable.widget_bg_premium_1
                nameColor = Color.WHITE
                weatherBase = Color.parseColor("#FFF8D8")
                daysBase = Color.WHITE
                starsBase = Color.parseColor("#FFF7C2")
                darkSurface = true
            }
            else -> {
                backgroundRes = R.drawable.widget_bg_pink
                nameColor = Color.parseColor("#333333")
                weatherBase = Color.parseColor("#667085")
                daysBase = Color.parseColor("#FF4D73")
                starsBase = Color.parseColor("#FF4D73")
                darkSurface = false
            }
        }

        val weatherColor =
            if (darkSurface) {
                mixColors(weatherBase, accentSoftColor, 0.22f)
            } else {
                mixColors(weatherBase, accentColor, 0.18f)
            }
        val daysColor =
            if (darkSurface) {
                mixColors(daysBase, accentSoftColor, 0.28f)
            } else {
                mixColors(daysBase, accentColor, 0.36f)
            }
        val starsColor =
            if (darkSurface) {
                mixColors(starsBase, accentColor, 0.26f)
            } else {
                mixColors(starsBase, accentColor, 0.44f)
            }
        val statusOnlineColor =
            mixColors(
                Color.parseColor("#22C55E"),
                accentSoftColor,
                if (darkSurface) 0.12f else 0.08f,
            )
        val statusOfflineColor =
            mixColors(
                Color.parseColor("#94A3B8"),
                accentSoftColor,
                if (darkSurface) 0.20f else 0.12f,
            )
        val badgeBackgroundColor =
            if (darkSurface) {
                mixColors(accentColor, Color.WHITE, 0.16f)
            } else {
                mixColors(accentSoftColor, Color.WHITE, 0.10f)
            }
        val badgeTextColor =
            if (darkSurface) {
                Color.WHITE
            } else if (isColorLight(badgeBackgroundColor)) {
                Color.parseColor("#1F2937")
            } else {
                Color.WHITE
            }
        val diaryFrameColor =
            if (darkSurface) {
                withAlpha(mixColors(accentSoftColor, Color.WHITE, 0.12f), 220)
            } else {
                mixColors(accentSoftColor, Color.WHITE, 0.18f)
            }

        return ThemeColors(
            backgroundRes = backgroundRes,
            nameColor = nameColor,
            weatherColor = weatherColor,
            daysColor = daysColor,
            starsColor = starsColor,
            accentColor = accentColor,
            accentSoftColor = accentSoftColor,
            statusOnlineColor = statusOnlineColor,
            statusOfflineColor = statusOfflineColor,
            badgeTextColor = badgeTextColor,
            badgeBackgroundColor = badgeBackgroundColor,
            diaryFrameColor = diaryFrameColor,
        )
    }

    private fun resolveSeasonPalette(seasonKey: String): Pair<Int, Int>? {
        return when (seasonKey.lowercase()) {
            "valentine" ->
                Color.parseColor("#FF5B8A") to Color.parseColor("#FFC4D6")
            "anniversary" ->
                Color.parseColor("#FFB84D") to Color.parseColor("#FFE5A8")
            "birthday" ->
                Color.parseColor("#5B8CFF") to Color.parseColor("#8FE8FF")
            else -> null
        }
    }

    private fun seasonBadgeLabel(seasonKey: String): String {
        return when (seasonKey.lowercase()) {
            "valentine" -> "Valentine"
            "anniversary" -> "Kỷ niệm"
            "birthday" -> "Sinh nhật"
            else -> ""
        }
    }

    private fun createDynamicBackgroundBitmap(
        appWidgetId: Int,
        bgTheme: String,
        seasonKey: String,
        themeColors: ThemeColors,
        motionEnabled: Boolean,
    ): Bitmap? {
        if (bgTheme == "premium") {
            return createPremiumBackgroundBitmap(
                appWidgetId = appWidgetId,
                accentColor = themeColors.accentColor,
                seasonKey = seasonKey,
                motionEnabled = motionEnabled,
            )
        }
        return null
    }

    private fun motionProgress(
        appWidgetId: Int,
        motionEnabled: Boolean,
        speedMultiplier: Double = 1.0,
    ): Double {
        if (!motionEnabled) return 0.0
        return ((System.currentTimeMillis() / REFRESH_INTERVAL_MS.toDouble()) * speedMultiplier) +
            (appWidgetId * 0.37)
    }

    private fun createPremiumBackgroundBitmap(
        appWidgetId: Int,
        accentColor: Int,
        seasonKey: String,
        motionEnabled: Boolean,
    ): Bitmap {
        val bitmap =
            Bitmap.createBitmap(PREMIUM_BG_WIDTH, PREMIUM_BG_HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val width = PREMIUM_BG_WIDTH.toFloat()
        val height = PREMIUM_BG_HEIGHT.toFloat()
        val motion = motionProgress(appWidgetId, motionEnabled)
        val middleStop =
            (0.35f + (sin(motion * 0.32) * 0.026).toFloat()).coerceIn(0.31f, 0.39f)
        val gradientStartX = width * (-0.05f + (sin(motion * 0.40) * 0.05).toFloat())
        val gradientEndX = width * (0.98f + (cos(motion * 0.28) * 0.05).toFloat())

        val basePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                gradientStartX,
                0f,
                gradientEndX,
                height,
                intArrayOf(
                    Color.parseColor("#FF4F9A"),
                    Color.parseColor("#FFB66D"),
                    Color.parseColor("#68E4FF"),
                    Color.parseColor("#7151F3"),
                ),
                floatArrayOf(0.0f, middleStop, 0.72f, 1.0f),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, width, height, basePaint)

        drawAuroraBlob(
            canvas = canvas,
            centerX = width * (0.17f + (sin(motion * 0.46) * 0.05).toFloat()),
            centerY = height * (0.18f + (cos(motion * 0.38) * 0.04).toFloat()),
            radius = width * 0.42f,
            colors = intArrayOf(
                withAlpha(Color.parseColor("#FF93C7"), 154),
                withAlpha(Color.parseColor("#FFD98C"), 88),
                Color.TRANSPARENT,
            ),
        )
        drawAuroraBlob(
            canvas = canvas,
            centerX = width * (0.82f + (cos(motion * 0.42) * 0.06).toFloat()),
            centerY = height * (0.22f + (sin(motion * 0.34) * 0.04).toFloat()),
            radius = width * 0.34f,
            colors = intArrayOf(
                withAlpha(Color.parseColor("#87EAFF"), 130),
                withAlpha(Color.parseColor("#7B6DFF"), 76),
                Color.TRANSPARENT,
            ),
        )
        drawAuroraBlob(
            canvas = canvas,
            centerX = width * (0.52f + (sin(motion * 0.28) * 0.05).toFloat()),
            centerY = height * (0.84f + (cos(motion * 0.30) * 0.06).toFloat()),
            radius = width * 0.40f,
            colors = intArrayOf(
                withAlpha(Color.parseColor("#FFE3A0"), 88),
                withAlpha(Color.parseColor("#B781FF"), 56),
                Color.TRANSPARENT,
            ),
        )

        val gleamPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                0f,
                width,
                height,
                intArrayOf(
                    withAlpha(Color.WHITE, 44),
                    Color.TRANSPARENT,
                    withAlpha(Color.WHITE, 18),
                ),
                floatArrayOf(0.0f, 0.46f, 1.0f),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, width, height, gleamPaint)
        drawAuroraBlob(
            canvas = canvas,
            centerX = width * (0.46f + (cos(motion * 0.36) * 0.18).toFloat()),
            centerY = height * (0.54f + (sin(motion * 0.31) * 0.16).toFloat()),
            radius = width * 0.26f,
            colors = intArrayOf(
                withAlpha(accentColor, if (seasonKey == "none") 78 else 118),
                withAlpha(mixColors(accentColor, Color.WHITE, 0.46f), 56),
                Color.TRANSPARENT,
            ),
        )
        drawFloatingSparkles(
            canvas = canvas,
            motion = motion,
            accentColor = accentColor,
            intense = true,
        )

        return bitmap
    }

    private fun drawAuroraBlob(
        canvas: Canvas,
        centerX: Float,
        centerY: Float,
        radius: Float,
        colors: IntArray,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
                centerX,
                centerY,
                radius,
                colors,
                floatArrayOf(0.0f, 0.48f, 1.0f),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawCircle(centerX, centerY, radius, paint)
    }

    private fun createSeasonOverlayBitmap(
        appWidgetId: Int,
        accentColor: Int,
        accentSoftColor: Int,
        motionEnabled: Boolean,
    ): Bitmap {
        val bitmap =
            Bitmap.createBitmap(PREMIUM_BG_WIDTH, PREMIUM_BG_HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val width = PREMIUM_BG_WIDTH.toFloat()
        val height = PREMIUM_BG_HEIGHT.toFloat()
        val motion = motionProgress(appWidgetId, motionEnabled, speedMultiplier = 0.82)

        drawAuroraBlob(
            canvas = canvas,
            centerX = width * (0.18f + (sin(motion * 0.44) * 0.04).toFloat()),
            centerY = height * (0.18f + (cos(motion * 0.36) * 0.04).toFloat()),
            radius = width * 0.24f,
            colors = intArrayOf(
                withAlpha(accentSoftColor, 96),
                withAlpha(accentColor, 42),
                Color.TRANSPARENT,
            ),
        )
        drawAuroraBlob(
            canvas = canvas,
            centerX = width * (0.82f + (cos(motion * 0.40) * 0.05).toFloat()),
            centerY = height * (0.78f + (sin(motion * 0.32) * 0.05).toFloat()),
            radius = width * 0.20f,
            colors = intArrayOf(
                withAlpha(accentColor, 74),
                withAlpha(accentSoftColor, 34),
                Color.TRANSPARENT,
            ),
        )
        return bitmap
    }

    private fun drawFloatingSparkles(
        canvas: Canvas,
        motion: Double,
        accentColor: Int,
        intense: Boolean,
    ) {
        val width = canvas.width.toFloat()
        val height = canvas.height.toFloat()
        val sparklePoints =
            listOf(
                0.18f to 0.18f,
                0.31f to 0.34f,
                0.64f to 0.20f,
                0.80f to 0.36f,
                0.58f to 0.74f,
                0.26f to 0.78f,
            )
        val travel = if (intense) width * 0.010f else width * 0.006f
        sparklePoints.forEachIndexed { index, point ->
            val orbit = motion + (index * 0.72)
            val shiftX =
                (sin(orbit * (if (intense) 0.86 else 0.62)) * travel).toFloat()
            val shiftY =
                (cos(orbit * (if (intense) 0.74 else 0.56)) * travel * 0.36).toFloat()
            val x = (width * point.first) + shiftX
            val y = (height * point.second) + shiftY
            val size =
                width * (if (intense) 0.0105f else 0.0078f) *
                    (1f + (((sin(orbit * 0.82) + 1.0) / 2.0) * 0.18).toFloat())
            val sparkleColor =
                if (index % 2 == 0) {
                    withAlpha(Color.WHITE, if (intense) 190 else 132)
                } else {
                    withAlpha(accentColor, if (intense) 170 else 118)
                }
            drawSparkle(canvas, x, y, size, sparkleColor)
        }
    }

    private fun createEventBadgeBitmap(
        label: String,
        backgroundColor: Int,
        textColor: Int,
    ): Bitmap {
        val bitmap =
            Bitmap.createBitmap(EVENT_BADGE_WIDTH, EVENT_BADGE_HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val rect = RectF(0f, 0f, EVENT_BADGE_WIDTH.toFloat(), EVENT_BADGE_HEIGHT.toFloat())
        val radius = EVENT_BADGE_HEIGHT / 2f
        val backgroundPaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    0f,
                    0f,
                    rect.right,
                    rect.bottom,
                    intArrayOf(
                        backgroundColor,
                        mixColors(backgroundColor, Color.WHITE, 0.24f),
                    ),
                    null,
                    Shader.TileMode.CLAMP,
                )
            }
        canvas.drawRoundRect(rect, radius, radius, backgroundPaint)
        val borderPaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                color = withAlpha(Color.WHITE, 148)
                strokeWidth = 3f
            }
        canvas.drawRoundRect(
            RectF(1.5f, 1.5f, rect.right - 1.5f, rect.bottom - 1.5f),
            radius,
            radius,
            borderPaint,
        )

        val textPaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textColor
                textAlign = Paint.Align.CENTER
                isFakeBoldText = true
                textSize = 34f
            }
        while (textPaint.measureText(label) > EVENT_BADGE_WIDTH - 42f && textPaint.textSize > 24f) {
            textPaint.textSize -= 2f
        }
        val metrics = textPaint.fontMetrics
        val baseline = rect.centerY() - ((metrics.ascent + metrics.descent) / 2f)
        canvas.drawText(label, rect.centerX(), baseline, textPaint)
        return bitmap
    }

    private fun createDiaryCollageBitmap(
        diaryPaths: List<String>,
        layoutKey: String,
        themeColors: ThemeColors,
    ): Bitmap? {
        if (diaryPaths.isEmpty()) return null

        val bitmap =
            Bitmap.createBitmap(DIARY_PREVIEW_WIDTH, DIARY_PREVIEW_HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val outerRect = RectF(0f, 0f, DIARY_PREVIEW_WIDTH.toFloat(), DIARY_PREVIEW_HEIGHT.toFloat())
        val outerPaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    0f,
                    0f,
                    outerRect.right,
                    outerRect.bottom,
                    intArrayOf(
                        themeColors.diaryFrameColor,
                        withAlpha(themeColors.accentSoftColor, 210),
                    ),
                    null,
                    Shader.TileMode.CLAMP,
                )
            }
        canvas.drawRoundRect(outerRect, DIARY_PREVIEW_RADIUS, DIARY_PREVIEW_RADIUS, outerPaint)

        val innerRect = RectF(4f, 4f, outerRect.right - 4f, outerRect.bottom - 4f)
        val basePaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = withAlpha(Color.WHITE, 56)
            }
        canvas.drawRoundRect(
            innerRect,
            DIARY_PREVIEW_RADIUS - 4f,
            DIARY_PREVIEW_RADIUS - 4f,
            basePaint,
        )

        val tileRects = resolveDiaryTileRects(layoutKey, innerRect, 6f)
        val tileCount = tileRects.size
        val filledPaths =
            List(tileCount) { index -> if (index < diaryPaths.size) diaryPaths[index] else "" }
        val tileRadius =
            when (layoutKey) {
                "grid" -> 14f
                "duo" -> 16f
                else -> 18f
            }

        tileRects.forEachIndexed { index, rect ->
            val path = filledPaths[index]
            val reqWidth = rect.width().toInt().coerceAtLeast(1)
            val reqHeight = rect.height().toInt().coerceAtLeast(1)
            val tileBitmap =
                if (path.isBlank()) {
                    null
                } else {
                    getRoundedRectCroppedBitmap(
                        decodeSampledBitmapFromFile(path, reqWidth * 2, reqHeight * 2),
                        outputWidth = reqWidth,
                        outputHeight = reqHeight,
                        cornerRadius = tileRadius,
                    )
                }

            if (tileBitmap != null) {
                canvas.drawBitmap(tileBitmap, rect.left, rect.top, null)
            } else {
                drawDiaryPlaceholderTile(
                    canvas = canvas,
                    rect = rect,
                    colorStart = themeColors.accentSoftColor,
                    colorEnd = themeColors.accentColor,
                    cornerRadius = tileRadius,
                )
            }

            val tileBorderPaint =
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE
                    color = withAlpha(Color.WHITE, 150)
                    strokeWidth = 2.2f
                }
            canvas.drawRoundRect(rect, tileRadius, tileRadius, tileBorderPaint)
        }

        val frameStrokePaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                color = withAlpha(Color.WHITE, 170)
                strokeWidth = 2.6f
            }
        canvas.drawRoundRect(
            RectF(1.3f, 1.3f, outerRect.right - 1.3f, outerRect.bottom - 1.3f),
            DIARY_PREVIEW_RADIUS,
            DIARY_PREVIEW_RADIUS,
            frameStrokePaint,
        )
        return bitmap
    }

    private fun resolveDiaryTileRects(
        layoutKey: String,
        bounds: RectF,
        gap: Float,
    ): List<RectF> {
        return when (layoutKey) {
            "duo" -> {
                val tileWidth = (bounds.width() - gap) / 2f
                listOf(
                    RectF(bounds.left, bounds.top, bounds.left + tileWidth, bounds.bottom),
                    RectF(bounds.left + tileWidth + gap, bounds.top, bounds.right, bounds.bottom),
                )
            }
            "grid" -> {
                val tileWidth = (bounds.width() - gap) / 2f
                val tileHeight = (bounds.height() - gap) / 2f
                listOf(
                    RectF(bounds.left, bounds.top, bounds.left + tileWidth, bounds.top + tileHeight),
                    RectF(
                        bounds.left + tileWidth + gap,
                        bounds.top,
                        bounds.right,
                        bounds.top + tileHeight,
                    ),
                    RectF(
                        bounds.left,
                        bounds.top + tileHeight + gap,
                        bounds.left + tileWidth,
                        bounds.bottom,
                    ),
                    RectF(
                        bounds.left + tileWidth + gap,
                        bounds.top + tileHeight + gap,
                        bounds.right,
                        bounds.bottom,
                    ),
                )
            }
            else -> listOf(RectF(bounds))
        }
    }

    private fun drawDiaryPlaceholderTile(
        canvas: Canvas,
        rect: RectF,
        colorStart: Int,
        colorEnd: Int,
        cornerRadius: Float,
    ) {
        val fillPaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    rect.left,
                    rect.top,
                    rect.right,
                    rect.bottom,
                    intArrayOf(
                        withAlpha(colorStart, 220),
                        withAlpha(colorEnd, 138),
                    ),
                    null,
                    Shader.TileMode.CLAMP,
                )
            }
        canvas.drawRoundRect(rect, cornerRadius, cornerRadius, fillPaint)
        val highlightPaint =
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = withAlpha(Color.WHITE, 92)
            }
        canvas.drawCircle(
            rect.centerX(),
            rect.centerY(),
            minOf(rect.width(), rect.height()) * 0.14f,
            highlightPaint,
        )
    }

    private fun resolveHeartPalette(colorKey: String): HeartPalette {
        return when (colorKey) {
            "ruby" -> HeartPalette(
                primary = Color.parseColor("#E11D48"),
                secondary = Color.parseColor("#FB7185"),
                glow = Color.parseColor("#FFE4E6"),
                spark = Color.parseColor("#FFF1F2"),
            )
            "violet" -> HeartPalette(
                primary = Color.parseColor("#8B5CF6"),
                secondary = Color.parseColor("#C084FC"),
                glow = Color.parseColor("#F3E8FF"),
                spark = Color.parseColor("#EDE9FE"),
            )
            "ocean" -> HeartPalette(
                primary = Color.parseColor("#0EA5E9"),
                secondary = Color.parseColor("#67E8F9"),
                glow = Color.parseColor("#E0F2FE"),
                spark = Color.parseColor("#F0FDFF"),
            )
            "mint" -> HeartPalette(
                primary = Color.parseColor("#10B981"),
                secondary = Color.parseColor("#6EE7B7"),
                glow = Color.parseColor("#DCFCE7"),
                spark = Color.parseColor("#ECFDF5"),
            )
            "sunset" -> HeartPalette(
                primary = Color.parseColor("#F97316"),
                secondary = Color.parseColor("#FBBF24"),
                glow = Color.parseColor("#FFF7ED"),
                spark = Color.parseColor("#FEF3C7"),
            )
            "gold" -> HeartPalette(
                primary = Color.parseColor("#EAB308"),
                secondary = Color.parseColor("#FDE68A"),
                glow = Color.parseColor("#FFFBEA"),
                spark = Color.parseColor("#FEF9C3"),
            )
            else -> HeartPalette(
                primary = DEFAULT_HEART_PRIMARY,
                secondary = DEFAULT_HEART_SECONDARY,
                glow = DEFAULT_HEART_GLOW,
                spark = DEFAULT_HEART_SPARK,
            )
        }
    }

    private fun resolveHeartEmoji(styleKey: String?): String {
        return when (styleKey?.trim()) {
            "🤍" -> "🤍"
            "🤎" -> "🤎"
            "♥️" -> "♥️"
            "❣️" -> "❣️"
            "❤️" -> "❤️"
            "💞" -> "💞"
            "🖤" -> "🖤"
            "💟" -> "💟"
            "❤️‍🔥" -> "❤️‍🔥"
            "🩷" -> "🩷"
            "🩶" -> "🩶"
            "🩵" -> "🩵"
            "💘" -> "💘"
            "❤️‍🩹" -> "❤️‍🩹"
            "💓" -> "💓"
            else -> "❤️"
        }
    }

    private fun createHeartBitmap(
        appWidgetId: Int,
        animated: Boolean,
        styleKey: String,
        palette: HeartPalette,
    ): Bitmap {
        val bitmap =
            Bitmap.createBitmap(HEART_BITMAP_SIZE, HEART_BITMAP_SIZE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = HEART_BITMAP_SIZE / 2f
        val primary = palette.primary
        val secondary = palette.secondary
        val glow = palette.glow
        val motion = motionProgress(appWidgetId, animated)
        val emoji =
            resolveAnimatedHeartEmoji(
                appWidgetId = appWidgetId,
                animated = animated,
                baseEmoji = resolveHeartEmoji(styleKey),
                motion = motion,
            )
        val pulse =
            if (animated) {
                (1.0 + (sin(motion * 0.95) * 0.038) + (cos(motion * 0.52) * 0.014)).toFloat()
            } else {
                1.0f
            }
        val floatY =
            if (animated) {
                (sin(motion * 0.88) * -1.35).toFloat()
            } else {
                0.0f
            }
        val swayX =
            if (animated) {
                (cos(motion * 0.74) * 1.25).toFloat()
            } else {
                0.0f
            }

        fun scaled(value: Float): Float = (value / 72f) * HEART_BITMAP_SIZE
        drawGlowCircle(canvas, center, center, scaled(24f), withAlpha(secondary, 72))
        drawGlowCircle(
            canvas,
            center,
            center,
            scaled(34f),
            withAlpha(primary, if (animated) 28 else 18),
        )

        if (animated) {
            drawGlowCircle(
                canvas,
                center + scaled(18f - (swayX * 0.45f)),
                center - scaled(16f - (floatY * 0.20f)),
                scaled(5.2f),
                withAlpha(secondary, 114),
            )
            drawGlowCircle(
                canvas,
                center - scaled(18f + (swayX * 0.24f)),
                center + scaled(18f),
                scaled(4.0f),
                withAlpha(glow, 184),
            )
        }

        drawHeartEmoji(
            canvas = canvas,
            emoji = emoji,
            centerX = center + scaled(swayX * 0.35f),
            centerY = center + scaled(floatY * 0.78f),
            textSize = scaled(38.5f) * pulse,
            shadowColor = withAlpha(primary, if (animated) 74 else 42),
        )

        return bitmap
    }

    private fun resolveAnimatedHeartEmoji(
        appWidgetId: Int,
        animated: Boolean,
        baseEmoji: String,
        motion: Double,
    ): String {
        if (!animated) return baseEmoji
        val normalizedBase = baseEmoji.ifBlank { "\u2764\uFE0F" }
        val pool =
            if (ANIMATED_HEART_EMOJIS.contains(normalizedBase)) {
                ANIMATED_HEART_EMOJIS
            } else {
                listOf(normalizedBase) + ANIMATED_HEART_EMOJIS
            }
        val timeBucket = System.currentTimeMillis() / REFRESH_INTERVAL_MS
        val wobbleBucket = ((sin((motion + appWidgetId) * 0.57) + 1.0) * 1000.0).toLong()
        val seed =
            (timeBucket * 131L) +
                (appWidgetId * 17L) +
                wobbleBucket +
                normalizedBase.hashCode().toLong()
        val index = Math.floorMod(seed, pool.size.toLong()).toInt()
        return pool[index]
    }

    private fun drawHeartEmoji(
        canvas: Canvas,
        emoji: String,
        centerX: Float,
        centerY: Float,
        textSize: Float,
        shadowColor: Int,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            this.textSize = textSize
            setShadowLayer(textSize * 0.14f, 0f, textSize * 0.06f, shadowColor)
        }
        val metrics = paint.fontMetrics
        val baseline = centerY - ((metrics.ascent + metrics.descent) / 2f)
        canvas.drawText(emoji, centerX, baseline, paint)
    }

    private fun isOutlineHeartStyle(styleKey: String): Boolean {
        return styleKey == "🤍" || styleKey == "♥️" || styleKey == "💟"
    }

    private fun isDoubleHeartStyle(styleKey: String): Boolean {
        return styleKey == "💞"
    }

    private fun isSparkleHeartStyle(styleKey: String): Boolean {
        return styleKey == "💓" || styleKey == "💞"
    }

    private fun drawHeartCrack(
        canvas: Canvas,
        centerX: Float,
        centerY: Float,
        size: Float,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = withAlpha(Color.WHITE, 230)
            strokeWidth = maxOf(3f, size * 0.08f)
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val path = Path().apply {
            moveTo(centerX + (size * 0.10f), centerY - (size * 0.42f))
            lineTo(centerX - (size * 0.02f), centerY - (size * 0.10f))
            lineTo(centerX + (size * 0.08f), centerY + (size * 0.02f))
            lineTo(centerX - (size * 0.03f), centerY + (size * 0.20f))
            lineTo(centerX + (size * 0.02f), centerY + (size * 0.42f))
        }
        canvas.drawPath(path, paint)
    }

    private fun drawBandage(
        canvas: Canvas,
        centerX: Float,
        centerY: Float,
        size: Float,
    ) {
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.parseColor("#FDE68A")
        }
        val stitchPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = Color.parseColor("#B45309")
            strokeWidth = maxOf(2f, size * 0.045f)
            strokeCap = Paint.Cap.ROUND
        }
        val bandageRect = RectF(
            centerX - (size * 0.26f),
            centerY - (size * 0.09f),
            centerX + (size * 0.26f),
            centerY + (size * 0.09f),
        )
        canvas.save()
        canvas.rotate(-24f, centerX, centerY)
        canvas.drawRoundRect(bandageRect, size * 0.08f, size * 0.08f, fillPaint)
        canvas.drawLine(
            centerX - (size * 0.08f),
            centerY,
            centerX + (size * 0.08f),
            centerY,
            stitchPaint,
        )
        canvas.drawLine(
            centerX,
            centerY - (size * 0.05f),
            centerX,
            centerY + (size * 0.05f),
            stitchPaint,
        )
        canvas.restore()
    }

    private fun drawCupidArrow(
        canvas: Canvas,
        centerX: Float,
        centerY: Float,
        size: Float,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = withAlpha(Color.WHITE, 216)
            strokeWidth = maxOf(3f, size * 0.055f)
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        canvas.save()
        canvas.rotate(-34f, centerX, centerY)
        canvas.drawLine(
            centerX - (size * 0.46f),
            centerY + (size * 0.30f),
            centerX + (size * 0.42f),
            centerY - (size * 0.28f),
            paint,
        )
        val head = Path().apply {
            moveTo(centerX + (size * 0.42f), centerY - (size * 0.28f))
            lineTo(centerX + (size * 0.26f), centerY - (size * 0.26f))
            moveTo(centerX + (size * 0.42f), centerY - (size * 0.28f))
            lineTo(centerX + (size * 0.34f), centerY - (size * 0.12f))
        }
        canvas.drawPath(head, paint)
        canvas.drawLine(
            centerX - (size * 0.40f),
            centerY + (size * 0.26f),
            centerX - (size * 0.52f),
            centerY + (size * 0.14f),
            paint,
        )
        canvas.drawLine(
            centerX - (size * 0.40f),
            centerY + (size * 0.26f),
            centerX - (size * 0.54f),
            centerY + (size * 0.34f),
            paint,
        )
        canvas.restore()
    }

    private fun drawFlameAccent(
        canvas: Canvas,
        centerX: Float,
        centerY: Float,
        size: Float,
        color: Int,
    ) {
        val outer = Path().apply {
            moveTo(centerX, centerY - (size * 0.64f))
            cubicTo(
                centerX + (size * 0.14f),
                centerY - (size * 0.56f),
                centerX + (size * 0.16f),
                centerY - (size * 0.34f),
                centerX,
                centerY - (size * 0.18f),
            )
            cubicTo(
                centerX - (size * 0.16f),
                centerY - (size * 0.34f),
                centerX - (size * 0.14f),
                centerY - (size * 0.56f),
                centerX,
                centerY - (size * 0.64f),
            )
            close()
        }
        val outerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            this.color = withAlpha(color, 230)
        }
        val innerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            this.color = Color.parseColor("#FFD166")
        }
        canvas.drawPath(outer, outerPaint)
        canvas.drawCircle(centerX, centerY - (size * 0.39f), size * 0.06f, innerPaint)
    }

    private fun drawHeart(
        canvas: Canvas,
        centerX: Float,
        centerY: Float,
        size: Float,
        fillColor: Int,
        strokeColor: Int = withAlpha(Color.WHITE, 140),
        strokeWidth: Float = 2f,
        shadowColor: Int = withAlpha(DEFAULT_HEART_PRIMARY, 36),
        drawShine: Boolean = true,
    ) {
        val path = Path().apply {
            moveTo(centerX, centerY + (size * 0.42f))
            cubicTo(
                centerX + (size * 0.66f),
                centerY + (size * 0.05f),
                centerX + (size * 0.55f),
                centerY - (size * 0.60f),
                centerX,
                centerY - (size * 0.18f),
            )
            cubicTo(
                centerX - (size * 0.55f),
                centerY - (size * 0.60f),
                centerX - (size * 0.66f),
                centerY + (size * 0.05f),
                centerX,
                centerY + (size * 0.42f),
            )
            close()
        }

        if (shadowColor != Color.TRANSPARENT) {
            val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.FILL
                color = shadowColor
            }
            canvas.save()
            canvas.translate(0f, size * 0.08f)
            canvas.drawPath(path, shadowPaint)
            canvas.restore()
        }

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = fillColor
        }
        canvas.drawPath(path, fillPaint)

        if (strokeWidth > 0f) {
            val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                color = strokeColor
                this.strokeWidth = strokeWidth
            }
            canvas.drawPath(path, strokePaint)
        }

        if (!drawShine) {
            return
        }

        val shinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = withAlpha(Color.WHITE, 92)
        }
        canvas.drawCircle(
            centerX - (size * 0.20f),
            centerY - (size * 0.18f),
            size * 0.11f,
            shinePaint,
        )
    }

    private fun drawGlowCircle(
        canvas: Canvas,
        centerX: Float,
        centerY: Float,
        radius: Float,
        color: Int,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            this.color = color
        }
        canvas.drawCircle(centerX, centerY, radius, paint)
    }

    private fun drawSparkle(
        canvas: Canvas,
        centerX: Float,
        centerY: Float,
        radius: Float,
        color: Int,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            this.color = color
            strokeWidth = radius * 0.35f
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawLine(centerX, centerY - radius, centerX, centerY + radius, paint)
        canvas.drawLine(centerX - radius, centerY, centerX + radius, centerY, paint)
        canvas.drawLine(
            centerX - (radius * 0.55f),
            centerY - (radius * 0.55f),
            centerX + (radius * 0.55f),
            centerY + (radius * 0.55f),
            paint,
        )
        canvas.drawLine(
            centerX - (radius * 0.55f),
            centerY + (radius * 0.55f),
            centerX + (radius * 0.55f),
            centerY - (radius * 0.55f),
            paint,
        )
    }

    private fun drawWingArrow(
        canvas: Canvas,
        centerX: Float,
        centerY: Float,
        size: Float,
        color: Int,
        pointingLeft: Boolean,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            this.color = color
            strokeWidth = maxOf(3f, size * 0.20f)
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val direction = if (pointingLeft) -1f else 1f
        val path = Path().apply {
            moveTo(centerX - (direction * size * 0.35f), centerY - (size * 0.55f))
            lineTo(centerX - (direction * size * 0.72f), centerY)
            lineTo(centerX - (direction * size * 0.35f), centerY + (size * 0.55f))
            moveTo(centerX, centerY - (size * 0.55f))
            lineTo(centerX - (direction * size * 0.37f), centerY)
            lineTo(centerX, centerY + (size * 0.55f))
        }
        canvas.drawPath(path, paint)
    }

    private fun withAlpha(color: Int, alpha: Int): Int {
        return Color.argb(
            alpha.coerceIn(0, 255),
            Color.red(color),
            Color.green(color),
            Color.blue(color),
        )
    }

    private fun mixColors(startColor: Int, endColor: Int, ratio: Float): Int {
        val t = ratio.coerceIn(0f, 1f)
        val inverse = 1f - t
        return Color.argb(
            (Color.alpha(startColor) * inverse + Color.alpha(endColor) * t).toInt(),
            (Color.red(startColor) * inverse + Color.red(endColor) * t).toInt(),
            (Color.green(startColor) * inverse + Color.green(endColor) * t).toInt(),
            (Color.blue(startColor) * inverse + Color.blue(endColor) * t).toInt(),
        )
    }

    private fun isColorLight(color: Int): Boolean {
        val luminance =
            ((0.299f * Color.red(color)) +
                (0.587f * Color.green(color)) +
                (0.114f * Color.blue(color))) / 255f
        return luminance >= 0.64f
    }

    private fun decodeSampledBitmapFromFile(
        path: String,
        reqWidth: Int,
        reqHeight: Int
    ): Bitmap? {
        return try {
            val file = File(path)
            if (!file.exists()) {
                Log.w(TAG, "File not found: $path")
                return null
            }
            if (file.length() == 0L) {
                Log.w(TAG, "File is empty: $path")
                return null
            }

            BitmapFactory.Options().run {
                inJustDecodeBounds = true
                BitmapFactory.decodeFile(path, this)
                inSampleSize = calculateInSampleSize(this, reqWidth, reqHeight)
                inJustDecodeBounds = false
                BitmapFactory.decodeFile(path, this)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error decoding bitmap: $path", e)
            null
        }
    }

    private fun calculateInSampleSize(
        options: BitmapFactory.Options,
        reqWidth: Int,
        reqHeight: Int
    ): Int {
        val (height: Int, width: Int) = options.run { outHeight to outWidth }
        var inSampleSize = 1
        if (height > reqHeight || width > reqWidth) {
            val halfHeight: Int = height / 2
            val halfWidth: Int = width / 2
            while (
                halfHeight / inSampleSize >= reqHeight &&
                    halfWidth / inSampleSize >= reqWidth
            ) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }

    private fun getRoundedRectCroppedBitmap(
        bitmap: Bitmap?,
        outputWidth: Int,
        outputHeight: Int,
        cornerRadius: Float
    ): Bitmap? {
        if (bitmap == null) return null
        val output = Bitmap.createBitmap(outputWidth, outputHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = -0xbdbdbe
        }

        val rectF = RectF(0f, 0f, outputWidth.toFloat(), outputHeight.toFloat())
        canvas.drawARGB(0, 0, 0, 0)
        canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)

        val scale = maxOf(
            outputWidth.toFloat() / bitmap.width.toFloat(),
            outputHeight.toFloat() / bitmap.height.toFloat()
        )
        val scaledW = bitmap.width * scale
        val scaledH = bitmap.height * scale
        val left = (outputWidth - scaledW) / 2.0f
        val top = (outputHeight - scaledH) / 2.0f
        val dest = RectF(left, top, left + scaledW, top + scaledH)

        // ⚡ Tối ưu: Sử dụng FILTER_BITMAP để chất lượng tốt hơn khi resize
        paint.flags = Paint.FILTER_BITMAP_FLAG
        canvas.drawBitmap(bitmap, null, dest, paint)
        return output
    }

    private fun getRoundedCroppedBitmap(bitmap: Bitmap?): Bitmap? {
        if (bitmap == null) return null
        val minDim = minOf(bitmap.width, bitmap.height)
        val output = Bitmap.createBitmap(minDim, minDim, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        val paint = Paint()
        paint.isAntiAlias = true
        paint.color = -0xbdbdbe

        val destRect = Rect(0, 0, minDim, minDim)
        val rectF = RectF(destRect)
        val roundPx = minDim / 2.0f

        canvas.drawARGB(0, 0, 0, 0)
        canvas.drawRoundRect(rectF, roundPx, roundPx, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)

        val scale = maxOf(
            minDim.toFloat() / bitmap.width.toFloat(),
            minDim.toFloat() / bitmap.height.toFloat()
        )
        val scaledW = bitmap.width * scale
        val scaledH = bitmap.height * scale
        val left = (minDim - scaledW) / 2.0f
        val top = (minDim - scaledH) / 2.0f
        val dest = RectF(left, top, left + scaledW, top + scaledH)

        // ⚡ Tối ưu: Sử dụng FILTER_BITMAP để chất lượng tốt hơn
        paint.flags = Paint.FILTER_BITMAP_FLAG
        canvas.drawBitmap(bitmap, null, dest, paint)
        return output
    }

}
