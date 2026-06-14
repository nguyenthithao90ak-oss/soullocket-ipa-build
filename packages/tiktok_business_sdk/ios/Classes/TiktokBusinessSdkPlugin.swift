import Flutter
import UIKit
import TikTokBusinessSDK

public class TiktokBusinessSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "tiktok_business_sdk", binaryMessenger: registrar.messenger())
    let instance = TiktokBusinessSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "initTiktokBusinessSdk":
      guard let args = call.arguments as? [String: Any] else {
        result("Invalid arguments")
        return
      }
      guard let accessToken = args["accessToken"] as? String else {
        result( "accessToken is required")
        return
      }
      guard let appId = args["appId"] as? String else {
        result( "appId is required")
        return
      }
      guard let ttAppId = args["ttAppId"] as? String else {
        result( "ttAppId is required")
        return
      }
      let openDebug = args["openDebug"] as? Bool ?? false
      let enableAutoIapTrack = args["enableAutoIapTrack"] as? Bool ?? true
      let disableAutoEnhancedDataPostbackEvents = args["disableAutoEnhancedDataPostbackEvents"] as? Bool ?? false
      let config = TikTokConfig(accessToken: accessToken, appId: appId, tiktokAppId: ttAppId)
      if openDebug {
        config?.enableDebugMode()
      }
      if !enableAutoIapTrack {
        config?.disablePaymentTracking()
      }
      if disableAutoEnhancedDataPostbackEvents {
        config?.disableAutoEnhancedDataPostbackEvent()
      }
      config?.setLogLevel(TikTokLogLevelDebug)
      TikTokBusiness.initializeSdk(config) { success, error in
                if (!success) {
                    result(error!.localizedDescription)
                } else {
                    result(nil)
                }
            }
    case "setIdentify":
      guard let args = call.arguments as? [String: Any] else {
        result("Invalid arguments")
        return
      }
      guard let externalId = args["externalId"] as? String else {
        result( "externalId is required")
        return
      }
      let externalUserName = args["externalUserName"] as? String ?? ""
      let phoneNumber = args["phoneNumber"] as? String ?? ""
      let email = args["email"] as? String ?? ""
      TikTokBusiness.identify(withExternalID: externalId, externalUserName: externalUserName, phoneNumber: phoneNumber, email: email)
      result(nil)
    case "trackTTEvent":
      guard let args = call.arguments as? [String: Any] else {
        result("Invalid arguments")
        return
      }
      guard let event = args["eventName"] as? String else {
        result( "event is required")
        return
      }
      let eventId = args["eventId"] as? String ?? ""
      TikTokBusiness.trackEvent(event, withId: eventId)
      result(nil)
    case "trackTTEventWithCustomData":
      do {
        guard let args = call.arguments as? [String: Any] else {
          result("Invalid arguments")
          return
        }
        
        guard let eventName = args["eventName"] as? String else {
          result( "eventName is required")
          return
        }
        let eventId = args["eventId"] as? String ?? ""
        let customData = args["customData"] as? String ?? ""
        let finalPayloadJSON = customData.data(using: .utf8)!
        let customEvent = TikTokBaseEvent(eventName:eventName, eventId:eventId) 
        if finalPayloadJSON.count > 0 {
          let finalPayload = try JSONSerialization.jsonObject(with: finalPayloadJSON, options: JSONSerialization.ReadingOptions.mutableContainers) as? [AnyHashable : Any]
          for (key, value) in finalPayload as! [AnyHashable : Any] {
            customEvent.addProperty(withKey:key as! String, value: value)
          }
        }
        TikTokBusiness.trackTTEvent(customEvent)
        result(nil)
      } catch {
        result(error.localizedDescription)
      }
    case "logout":
      TikTokBusiness.logout()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
