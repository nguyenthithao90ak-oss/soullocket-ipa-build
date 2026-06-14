package com.example.tiktok_business_sdk

import android.content.Context
import com.tiktok.TikTokBusinessSdk
import com.tiktok.appevents.base.EventName
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/** TiktokBusinessSdkPlugin */
class TiktokBusinessSdkPlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "tiktok_business_sdk")
        channel.setMethodCallHandler(this)
        applicationContext = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "initTiktokBusinessSdk" -> {
                val accessToken: String? = call.argument<String>("accessToken")
                val appId: String? = call.argument<String>("appId")
                val ttAppId: String? = call.argument<String>("ttAppId")
                val openDebug: Boolean? = call.argument<Boolean>("openDebug")
                val enableAutoIapTrack: Boolean? = call.argument<Boolean>("enableAutoIapTrack")
                val disableAutoEnhancedDataPostbackEvent: Boolean? =
                    call.argument<Boolean>("disableAutoEnhancedDataPostbackEvent")
                if (accessToken?.isNotEmpty() == true &&
                    appId?.isNotEmpty() == true &&
                    ttAppId?.isNotEmpty() == true
                ) {

                    val ttConfig =
                        TikTokBusinessSdk.TTConfig(applicationContext, accessToken)
                    ttConfig.apply {
                        setAppId(appId)
                        setTTAppId(ttAppId)
                        if (openDebug == true) openDebugMode()
                        if (enableAutoIapTrack == true) enableAutoIapTrack()
                        if (disableAutoEnhancedDataPostbackEvent == true) disableAutoEnhancedDataPostbackEvent()
                    }
                    TikTokBusinessSdk.initializeSdk(
                        ttConfig,
                        object : TikTokBusinessSdk.TTInitCallback {
                            override fun success() {
                                result.success(null)
                            }

                            override fun fail(code: Int, msg: String?) {
                                result.error(code.toString(), msg, "")
                            }

                        })
                } else {
                    result.error("-1", "参数不能为空", "请检查参数")
                }
            }

            "setIdentify" -> {
                val externalId: String? = call.argument<String>("externalId")
                val externalUserName: String? = call.argument<String>("externalUserName")
                val phoneNumber: String? = call.argument<String>("phoneNumber")
                val email: String? = call.argument<String>("email")
                TikTokBusinessSdk.identify(
                    externalId, externalUserName, phoneNumber, email
                )
                result.success(null)
            }

            "logout" -> {
                TikTokBusinessSdk.logout()
                result.success(null)
            }

            "trackTTEvent" -> {
                val eventName: String? = call.argument<String>("eventName")
                if (eventName?.isNotEmpty() == true) {
                    val event = EventName.valueOf(eventName)
                    val eventId: String? = call.argument<String>("eventId")
                    if (eventId?.isNotEmpty() == true)
                        TikTokBusinessSdk.trackTTEvent(event, eventId)
                    else
                        TikTokBusinessSdk.trackTTEvent(event)
                } else {
                    result.error("-2", "eventName不能为空", "")
                }


            }

            else ->
                result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }


}
