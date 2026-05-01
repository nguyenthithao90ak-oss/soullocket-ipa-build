package com.soullocket.app

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import org.json.JSONArray

class DiaryImageRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return DiaryImageRemoteViewsFactory(applicationContext)
    }
}

private class DiaryImageRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "DiaryImageWidget"
    }

    private var imagePaths: List<String> = emptyList()

    override fun onCreate() {
        loadImagePaths()
    }

    override fun onDataSetChanged() {
        loadImagePaths()
    }

    override fun onDestroy() {
        imagePaths = emptyList()
    }

    override fun getCount(): Int = imagePaths.size

    override fun getViewAt(position: Int): RemoteViews {
        val path = imagePaths.getOrNull(position) ?: return createLoadingView()
        val bitmap = runCatching {
            getRoundedRectBitmap(
                decodeSampledBitmapFromFile(path, 240, 140),
                outputWidth = 240,
                outputHeight = 112,
                roundPx = 20f,
            )
        }.onFailure {
            Log.e(TAG, "Failed to decode diary widget image: $path", it)
        }.getOrNull()

        return RemoteViews(context.packageName, R.layout.widget_diary_image).apply {
            if (bitmap != null) {
                setImageViewBitmap(R.id.diary_img, bitmap)
            } else {
                setImageViewResource(R.id.diary_img, R.drawable.ic_heart)
            }
            setOnClickFillInIntent(R.id.diary_item_root, Intent())
        }
    }

    override fun getLoadingView(): RemoteViews = createLoadingView()

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    private fun loadImagePaths() {
        val widgetData = HomeWidgetPlugin.getData(context)
        val raw = widgetData.getString("diaryImagePaths", null)
        val basePaths = if (raw.isNullOrBlank()) {
            emptyList()
        } else {
            runCatching {
                val json = JSONArray(raw)
                buildList {
                    for (index in 0 until json.length()) {
                        val path = json.optString(index).trim()
                        val file = File(path)
                        if (path.isNotEmpty() && file.exists() && file.length() > 0) {
                            add(path)
                        }
                    }
                }
            }.onFailure {
                Log.e(TAG, "Failed to parse diary image paths for widget", it)
            }.getOrDefault(emptyList())
        }
        imagePaths = basePaths
    }

    private fun createLoadingView(): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_diary_image).apply {
            setImageViewResource(R.id.diary_img, R.drawable.ic_heart)
        }
    }

    private fun decodeSampledBitmapFromFile(path: String, reqWidth: Int, reqHeight: Int): Bitmap? {
        return BitmapFactory.Options().run {
            inJustDecodeBounds = true
            BitmapFactory.decodeFile(path, this)
            inSampleSize = calculateInSampleSize(this, reqWidth, reqHeight)
            inJustDecodeBounds = false
            BitmapFactory.decodeFile(path, this)
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

    private fun getRoundedRectBitmap(
        bitmap: Bitmap?,
        outputWidth: Int,
        outputHeight: Int,
        roundPx: Float,
    ): Bitmap? {
        if (bitmap == null) return null
        val output = Bitmap.createBitmap(outputWidth, outputHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        val paint = Paint()
        paint.isAntiAlias = true
        paint.color = -0xbdbdbe

        val rectF = RectF(0f, 0f, outputWidth.toFloat(), outputHeight.toFloat())

        canvas.drawARGB(0, 0, 0, 0)
        canvas.drawRoundRect(rectF, roundPx, roundPx, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)

        val scale = maxOf(
            outputWidth.toFloat() / bitmap.width.toFloat(),
            outputHeight.toFloat() / bitmap.height.toFloat(),
        )
        val scaledW = bitmap.width * scale
        val scaledH = bitmap.height * scale
        val left = (outputWidth - scaledW) / 2.0f
        val top = (outputHeight - scaledH) / 2.0f
        val dest = RectF(left, top, left + scaledW, top + scaledH)

        canvas.drawBitmap(bitmap, null, dest, paint)

        return output
    }
}
