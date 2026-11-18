import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/storage.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 当前隐私协议版本。条款有实质变更时 +1，用户下次启动会重新展示并确认。
const int kPrivacyPolicyVersion = 1;

/// 首次启动闸门：未同意前进不了主界面。
class PrivacyGate extends StatefulWidget {
  final VoidCallback onAccepted;
  const PrivacyGate({super.key, required this.onAccepted});

  @override
  State<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<PrivacyGate> {
  bool _busy = false;

  void _accept() {
    if (_busy) return;
    setState(() => _busy = true);
    // 立即放行，不因落盘阻塞用户进入（存储异常也不该把人挡在门外）。
    // Storage 内部串行写入 + 切后台 flush 保证协议版本最终落盘。
    Storage.instance.patchSettings(privacyVersion: kPrivacyPolicyVersion);
    if (!mounted) return;
    widget.onAccepted();
  }

  void _reject() {
    // 不同意就不使用。Android 直接结束 Activity；iOS 无合规的强制退出 API，
    // SystemNavigator.pop() 会把应用退到后台，符合商店审核要求。
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.privacy_tip_outlined, size: 40, color: LColors.red),
            const SizedBox(height: 10),
            const Text('隐私政策',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: LColors.ink)),
            const SizedBox(height: 4),
            const Text('使用前请先阅读并同意',
                style: TextStyle(fontSize: 13, color: LColors.gray)),
            const SizedBox(height: 18),
            const Expanded(child: PrivacyPolicyBody()),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: LColors.line)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _reject,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: LColors.gray3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('不同意',
                          style: TextStyle(fontSize: 15, color: LColors.gray)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: _busy ? '处理中…' : '同意并继续',
                      onTap: _busy ? null : _accept,
                      height: 48,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 从「关于与隐私」页进入的只读版本。
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私政策', style: TextStyle(fontSize: 17))),
      backgroundColor: LColors.bg,
      body: const PrivacyPolicyBody(),
    );
  }
}

class PrivacyPolicyBody extends StatelessWidget {
  const PrivacyPolicyBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: const [
        _Clause(
          title: '一句话说明',
          text: '电子灯牌没有服务端，不联网、不注册、不上传。你输入的每一个字都只留在这台手机上。',
        ),
        _Clause(
          title: '我们收集什么',
          text: '不收集任何个人信息。应用不需要账号、手机号、位置，也不读取通讯录、短信或相册内容。',
          lines: [
            '· 不接入统计、广告或崩溃上报 SDK',
            '· 不向任何第三方共享数据',
            '· 不申请与亮牌无关的权限',
          ],
        ),
        _Clause(
          title: '数据存在哪里',
          text: '灯牌预设、快捷短语和默认设置保存在本机应用数据中，不生成云端副本。',
          lines: [
            '· 在设置页点「清空本地数据」可一次删除全部内容',
            '· 卸载应用会一并清除这些数据',
          ],
        ),
        _Clause(
          title: '设备权限怎么用',
          text: '以下权限只在对应功能被你主动触发时使用，不会在后台调用：',
          lines: [
            '· 屏幕亮度 / 常亮：仅在播放页生效，退出后自动恢复原亮度',
            '· 写入相册：仅在你点「存图」时保存生成的图片，不读取相册',
            '· 系统分享：仅在你点「分享」时唤起系统面板，发给谁由你决定',
            '· 振动：仅用于按钮操作的触感反馈',
          ],
        ),
        _Clause(
          title: '安全与风险',
          text: '因为数据只在本机，我们不提供云端备份。请自行注意设备安全：他人直接使用你的设备时，可能看到本机保存的灯牌内容。',
        ),
        _Clause(
          title: '儿童隐私',
          text: '本应用面向一般用户，不会明知地收集 14 周岁以下儿童的个人信息。',
        ),
        _Clause(
          title: '政策更新',
          text: '条款若有实质变更，下次启动会重新展示并征求你的同意；未同意前不会进入应用。',
        ),
        _Clause(
          title: '联系我们',
          text: '对本政策有疑问，可在「关于与隐私」页查看反馈邮箱。',
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '点「同意并继续」即表示你已阅读并同意以上政策。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: LColors.gray3),
          ),
        ),
      ],
    );
  }
}

class _Clause extends StatelessWidget {
  final String title;
  final String text;
  final List<String> lines;

  const _Clause({
    required this.title,
    required this.text,
    this.lines = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: LColors.ink)),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, height: 1.75, color: Color(0xFF48484A))),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...lines.map((l) => Text(l,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.9, color: LColors.gray))),
          ],
        ],
      ),
    );
  }
}
