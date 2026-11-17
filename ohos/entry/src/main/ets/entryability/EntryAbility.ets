import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { window } from '@kit.ArkUI';

const CHANNEL = 'com.zhongdaiqi.led/bridge';

export default class EntryAbility extends FlutterAbility {
  private channel: MethodChannel | null = null;
  private ledWindow: window.Window | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    try {
      window.getLastWindow(this.context).then((win: window.Window) => {
        this.ledWindow = win;
      }).catch(() => {
        this.ledWindow = null;
      });
    } catch (_) {
      this.ledWindow = null;
    }

    this.channel = new MethodChannel(flutterEngine.getDartExecutor(), CHANNEL);
    this.channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.onMethodCall(call, result);
      }
    });
  }

  private onMethodCall(call: MethodCall, result: MethodResult): void {
    const win: window.Window | null = this.ledWindow;
    const args: Record<string, Object> = (call.args ?? {}) as Record<string, Object>;

    switch (call.method) {
      case 'getBrightness': {
        // OHOS 未开放读取窗口亮度，返回 1.0 让 Dart 侧用自身缓存值即可。
        result.success(1.0);
        break;
      }
      case 'setBrightness': {
        try {
          const value = Number(args['value'] ?? 1);
          if (win !== null) {
            const clamped = Math.min(1, Math.max(0.3, value));
            win.setWindowBrightness(clamped).catch(() => {});
          }
          result.success(true);
        } catch (_) {
          result.success(false);
        }
        break;
      }
      case 'keepOn': {
        try {
          const on = Boolean(args['on'] ?? false);
          if (win !== null) {
            win.setKeepScreenOn(on).catch(() => {});
          }
          result.success(true);
        } catch (_) {
          result.success(false);
        }
        break;
      }
      case 'vibrate': {
        // 增强反馈，失败静默
        result.success(true);
        break;
      }
      case 'saveImage':
      case 'shareImage': {
        // OHOS 相册写入 / 系统分享需接 @kit.MediaLibraryKit 并声明权限，
        // 当前先返回 false：Dart 侧会给出「保存失败，请检查相册权限」提示，
        // 不阻塞亮牌主流程。
        result.success(false);
        break;
      }
      case 'hasMethod': {
        result.success(true);
        break;
      }
      default:
        result.notImplemented();
        break;
    }
  }

  onDestroy() {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.ledWindow = null;
    super.onDestroy();
  }
}
