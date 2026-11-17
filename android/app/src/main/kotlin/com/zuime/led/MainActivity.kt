package com.zuime.led

import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.zhongdaiqi.led/bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBrightness" -> {
                        val v = window.attributes.screenBrightness
                        result.success(if (v < 0) 0.5 else v.toDouble())
                    }
                    "setBrightness" -> {
                        val v = call.argument<Double>("value") ?: 1.0
                        val lp = window.attributes
                        lp.screenBrightness = v.coerceIn(0.0, 1.0).toFloat()
                        window.attributes = lp
                        result.success(true)
                    }
                    "keepOn" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(true)
                    }
                    "vibrate" -> {
                        vibrate(call.argument<String>("type") ?: "light")
                        result.success(true)
                    }
                    "saveImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name") ?: "LED"
                        result.success(saveToGallery(bytes, name) != null)
                    }
                    "shareImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val text = call.argument<String>("text") ?: "电子灯牌"
                        val uri = saveToGallery(bytes, "LED-share")
                        if (uri == null) {
                            result.success(false)
                        } else {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "image/png"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                putExtra(Intent.EXTRA_TEXT, text)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(intent, "分享灯牌"))
                            result.success(true)
                        }
                    }
                    "hasMethod" -> result.success(true)
                    else -> result.notImplemented()
                }
            }
    }

    private fun vibrate(type: String) {
        try {
            val duration = if (type == "medium") 40L else 18L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = getSystemService(VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                manager?.defaultVibrator?.vibrate(
                    VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE)
                )
            } else {
                @Suppress("DEPRECATION")
                val v = getSystemService(VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v?.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    v?.vibrate(duration)
                }
            }
        } catch (_: Exception) {
        }
    }

    /** 写入 MediaStore.Pictures/LED，无需存储权限（Android 10+ 分区存储）。 */
    private fun saveToGallery(bytes: ByteArray?, name: String): Uri? {
        if (bytes == null) return null
        return try {
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "$name-${System.currentTimeMillis()}.png")
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/LED")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: return null
            val out = contentResolver.openOutputStream(uri) ?: return null
            val ok = bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.close()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && ok) {
                val update = ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }
                contentResolver.update(uri, update, null, null)
            }
            if (ok) uri else null
        } catch (_: Exception) {
            null
        }
    }
}
