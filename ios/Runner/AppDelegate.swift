import AudioToolbox
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.zhongdaiqi.led/bridge",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "getBrightness":
        result(Double(UIScreen.main.brightness))

      case "setBrightness":
        guard let value = args?["value"] as? Double else { result(false); return }
        UIScreen.main.brightness = CGFloat(min(max(value, 0.3), 1.0))
        result(true)

      case "keepOn":
        guard let on = args?["on"] as? Bool else { result(false); return }
        UIApplication.shared.isIdleTimerDisabled = on
        result(true)

      case "vibrate":
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        result(true)

      case "saveImage":
        guard let data = args?["bytes"] as? FlutterStandardTypedData,
              let image = UIImage(data: data.data) else { result(false); return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        result(true)

      case "shareImage":
        guard let data = args?["bytes"] as? FlutterStandardTypedData,
              let image = UIImage(data: data.data),
              let png = image.pngData() else { result(false); return }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
          .appendingPathComponent("led-\(Int(Date().timeIntervalSince1970)).png")
        try? png.write(to: url)
        let text = args?["text"] as? String ?? "电子灯牌"
        let activity = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
        self?.window?.rootViewController?.present(activity, animated: true)
        result(true)

      case "hasMethod":
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
