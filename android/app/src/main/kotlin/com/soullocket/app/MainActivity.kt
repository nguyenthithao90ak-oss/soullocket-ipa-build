package com.soullocket.app

import android.content.pm.PackageManager
import android.os.Build
import android.view.MotionEvent
import android.widget.Toast
import androidx.activity.enableEdgeToEdge
import java.security.MessageDigest
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val APP_CONTROL_CHANNEL = "soul_locket/app_control"
        private const val BOOTSTRAP_CHANNEL = "soul_locket/bootstrap"
        private const val METHOD_MOVE_TO_BACK = "moveTaskToBack"
        private const val METHOD_SET_SENSITIVE_PROTECTION = "setSensitiveProtection"
        private const val METHOD_GET_CURRENT_APP_ICON = "getCurrentAppIcon"
        private const val METHOD_SET_APP_ICON = "setAppIcon"
        private const val METHOD_GET_NATIVE_FIREBASE_OPTIONS = "getNativeFirebaseOptions"
        private const val METHOD_GET_APP_SIGNATURE_STATUS = "getAppSignatureStatus"
        private const val OBSCURED_TOUCH_TOAST_INTERVAL_MS = 1_500L
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    private lateinit var appControlChannel: MethodChannel
    private lateinit var bootstrapChannel: MethodChannel
    private var overlayProtectionEnabled = false
    private var lastObscuredTouchToastAt = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        appControlChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_CONTROL_CHANNEL
        )
        appControlChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_MOVE_TO_BACK -> {
                    result.success(moveTaskToBack(true))
                }

                METHOD_SET_SENSITIVE_PROTECTION -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val hideOverlays = call.argument<Boolean>("hideOverlays") ?: enabled
                    applySensitiveProtection(enabled, hideOverlays)
                    result.success(true)
                }

                METHOD_GET_CURRENT_APP_ICON -> {
                    result.success("default")
                }

                METHOD_SET_APP_ICON -> {
                    val iconKey = call.argument<String>("iconKey").orEmpty()
                    result.success(iconKey.trim().lowercase() == "default")
                }

                else -> result.notImplemented()
            }
        }

        bootstrapChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BOOTSTRAP_CHANNEL
        )
        bootstrapChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_GET_NATIVE_FIREBASE_OPTIONS -> {
                    result.success(readNativeFirebaseOptions())
                }

                METHOD_GET_APP_SIGNATURE_STATUS -> {
                    result.success(readAppSignatureStatus())
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (overlayProtectionEnabled && isObscuredTouch(event)) {
            maybeShowObscuredTouchWarning(event)
            return true
        }
        return super.dispatchTouchEvent(event)
    }

    private fun applySensitiveProtection(enabled: Boolean, hideOverlays: Boolean) {
        overlayProtectionEnabled = enabled && hideOverlays

        // Keep overlay/tapjacking protection, but allow screenshots
        // and screen sharing without turning the app black.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.setHideOverlayWindows(overlayProtectionEnabled)
        }
    }

    private fun isObscuredTouch(event: MotionEvent): Boolean {
        val fullyObscured =
            event.flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED != 0
        val partiallyObscured =
            event.flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED != 0
        return fullyObscured || partiallyObscured
    }

    private fun maybeShowObscuredTouchWarning(event: MotionEvent) {
        if (event.actionMasked != MotionEvent.ACTION_DOWN) {
            return
        }
        val now = System.currentTimeMillis()
        if (now - lastObscuredTouchToastAt < OBSCURED_TOUCH_TOAST_INTERVAL_MS) {
            return
        }
        lastObscuredTouchToastAt = now
        Toast.makeText(
            this,
            "Hay tat ung dung phu man hinh roi thu lai.",
            Toast.LENGTH_SHORT
        ).show()

        runCatching {
            val signals = mutableListOf<String>()
            if (event.flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED != 0) {
                signals.add("window_obscured")
            }
            if (event.flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED != 0) {
                signals.add("window_partially_obscured")
            }
            appControlChannel.invokeMethod(
                "onProtectedTouchRejected",
                mapOf(
                    "reasonCode" to "overlay",
                    "signals" to signals,
                    "timestampMs" to now
                )
            )
        }
    }

    private fun readNativeFirebaseOptions(): Map<String, String> {
        val projectId = readStringResource("project_id")
        if (projectId.isBlank()) {
            return emptyMap()
        }
        val authDomain = if (projectId.isBlank()) "" else "$projectId.firebaseapp.com"
        return mapOf<String, String>(
            "apiKey" to readStringResource("google_api_key"),
            "appId" to readStringResource("google_app_id"),
            "messagingSenderId" to readStringResource("gcm_defaultSenderId"),
            "projectId" to projectId,
            "storageBucket" to readStringResource("google_storage_bucket"),
            "databaseURL" to readStringResource("firebase_database_url"),
            "authDomain" to authDomain
        )
    }

    private fun readAppSignatureStatus(): Map<String, Any> {
        if (BuildConfig.DEBUG) {
            return mapOf<String, Any>(
                "status" to "ok",
                "isTrusted" to true,
                "reasonCode" to "debug_build"
            )
        }

        // Signature verification disabled for release builds
        return mapOf<String, Any>(
            "status" to "ok",
            "isTrusted" to true,
            "reasonCode" to "signature_check_disabled"
        )

        val expected = BuildConfig.EXPECTED_SIGNING_SHA256.trim().uppercase()
        if (expected.isBlank()) {
            return mapOf<String, Any>(
                "status" to "package_info_unavailable",
                "isTrusted" to false,
                "reasonCode" to "missing_expected_signature"
            )
        }

        val actual = runCatching { readCurrentSigningSha256() }.getOrNull()
        if (actual.isNullOrBlank()) {
            return mapOf<String, Any>(
                "status" to "package_info_unavailable",
                "isTrusted" to false,
                "reasonCode" to "package_info_unavailable"
            )
        }

        val trusted = actual == expected
        return mapOf<String, Any>(
            "status" to if (trusted) "ok" else "signature_mismatch",
            "isTrusted" to trusted,
            "reasonCode" to if (trusted) "official_signature" else "unofficial_build",
            "signatureSha256" to actual!!
        )
    }

    private fun readCurrentSigningSha256(): String {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
        }

        val certificateBytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = packageInfo.signingInfo ?: return ""
            val signatures = if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
            signatures.firstOrNull()?.toByteArray() ?: return ""
        } else {
            @Suppress("DEPRECATION")
            packageInfo.signatures?.firstOrNull()?.toByteArray() ?: return ""
        }

        val digest = MessageDigest.getInstance("SHA-256").digest(certificateBytes)
        return digest.joinToString(separator = "") { byte -> "%02X".format(byte) }
    }

    private fun readStringResource(name: String): String {
        val resourceId = resources.getIdentifier(name, "string", packageName)
        if (resourceId == 0) {
            return ""
        }
        return runCatching { getString(resourceId).trim() }.getOrDefault("")
    }

}
