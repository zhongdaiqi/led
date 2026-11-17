import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 平台能力桥 —— 小程序里由 wx.* 提供的能力，Flutter 走 MethodChannel。
///
/// 原生未实现时（例如桌面调试、ohos 尚未补实现）全部静默降级，
/// 绝不因为拿不到亮度或存不了图而阻塞亮牌主流程。
class PlatformBridge {
  static final PlatformBridge instance = PlatformBridge._();
  PlatformBridge._();

  static const MethodChannel _channel = MethodChannel('com.zhongdaiqi.led/bridge');

  Future<double?> getBrightness() async {
    try {
      final v = await _channel.invokeMethod<double>('getBrightness');
      return v;
    } catch (_) {
      return null;
    }
  }

  Future<void> setBrightness(double value) async {
    try {
      await _channel.invokeMethod<void>('setBrightness', {
        'value': value.clamp(0.0, 1.0),
      });
    } catch (_) {}
  }

  Future<void> setKeepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepOn', {'on': on});
    } catch (_) {}
  }

  Future<void> vibrate({String type = 'light'}) async {
    try {
      await _channel.invokeMethod<void>('vibrate', {'type': type});
    } catch (_) {}
  }

  /// 保存 PNG 到相册。返回 false 表示失败/未实现/被拒。
  Future<bool> saveImage(Uint8List bytes, {String name = 'led'}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('saveImage', {
        'bytes': bytes,
        'name': name,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 系统分享（Android ACTION_SEND / iOS activityViewController / ohos 分享）。
  Future<bool> shareImage(Uint8List bytes, String text) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareImage', {
        'bytes': bytes,
        'text': text,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 调试用：平台是否实现了某个方法。
  Future<bool> hasMethod(String name) async {
    if (!kDebugMode) return false;
    try {
      return await _channel.invokeMethod<bool>('hasMethod', {'name': name}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
