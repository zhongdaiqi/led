# 电子灯牌（Flutter）

把手机屏幕变成一块 LED 灯牌。演唱会应援、接机、现场举牌，或不方便说话时打字给对方看。

**完全离线 · 无服务端 · 零网络请求** —— 你输入的每一个字只留在这台手机上。

## 功能

- 三种灯牌效果：静态 / 左右滚动 / 闪烁
- 文字颜色、背景色、滚动速度自由调整
- 20 款内置模板，5 大分类：应援、接机、加油、沟通、节日
- 对话牌（面对面观看，不做镜像）
- 屏幕亮度、常亮、振动反馈
- 存图到相册、系统分享
- 首次启动隐私协议闸门，条款变更需重新同意

## 技术栈

Flutter（Dart 3）/ `shared_preferences` 本地存储 / `CustomPainter` + `ui.Picture` 离线渲染 / MethodChannel 平台桥接。三端原生：Android（Kotlin）、iOS（Swift）、HarmonyOS（ArkTS）。

## 本地运行

使用与项目匹配的 Flutter SDK：

```bash
flutter pub get
flutter run -d android
flutter run -d ios
flutter run -d ohos      # 需要 HarmonyOS 定制版 Flutter
```

数据全部存本机 `shared_preferences`，无账号、无上传。

## 签名配置（打包前必读）

> ⚠️ **任何证书、keystore、密钥密码都不得提交到本仓库。**

### Android

```bash
cp android/key.properties.example android/key.properties
# 编辑 key.properties，填入你自己的 storeFile / keyAlias / keyPassword / storePassword
flutter build apk --release
```

`android/key.properties` 已被 gitignore。

### HarmonyOS

```bash
cp ohos/build-profile.example.json5 ohos/build-profile.json5
# 填入本地证书路径与密钥密码
flutter build hap --release
```

`ohos/build-profile.json5` 已被 gitignore。

## iOS CI/CD

GitHub Actions 提供两条工作流（配置见 `.github/workflows/`）：

| 工作流 | 触发 | 作用 |
|---|---|---|
| `iOS Build (unsigned)` | 推到 `main` / 手动 | 在 macOS runner 上验证 iOS 能否编译（未签名） |
| `iOS Release (TestFlight)` | 打 `v*` tag / 手动 | 自动签名并上传 TestFlight |

签名采用 **App Store Connect API Key + 自动签名**，仓库与本机都不存放任何证书文件。需在仓库 Secrets 中配置：

- `APP_STORE_CONNECT_ISSUER_ID` — API Key 的 Issuer ID
- `APP_STORE_CONNECT_KEY_ID` — API Key 的 Key ID
- `APP_STORE_CONNECT_API_KEY` — `.p8` 私钥全文（含 BEGIN/END 行）
- `APPLE_TEAM_ID` — Apple Developer Team ID

前置条件：在 Apple Developer 注册 App ID `com.zuime.led`，并在 App Store Connect 创建对应 App 记录、填好隐私政策 URL（https://led.zuime.com/privacy.html）与隐私营养标签问卷。

## 隐私

无服务端、不注册、不上传、不接入任何统计/广告 SDK。详见 [隐私政策](https://led.zuime.com/privacy.html)。

反馈邮箱：info@zuime.com

## 许可

MIT © 2023-2026 北京醉么信息技术有限公司
