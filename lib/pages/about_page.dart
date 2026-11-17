import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'privacy_page.dart';

const String kAppVersion = '0.1.0';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于与隐私', style: TextStyle(fontSize: 17))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('电子灯牌',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: LColors.ink)),
                SizedBox(height: 4),
                Text('v$versionText',
                    style: TextStyle(fontSize: 12, color: LColors.gray2)),
              ],
            ),
          ),
          _Block(
            title: '这是什么',
            text: '把手机屏幕变成一块 LED 灯牌。演唱会应援、接机、活动现场，或者不方便说话时打字给对方看。',
          ),
          const _Block(
            title: '关于隐私',
            text: '本应用没有服务端，不收集、不上传任何数据。',
            lines: [
              '· 你输入的文字只存在这台手机里',
              '· 不需要注册、不索取手机号和位置',
              '· 相册权限只用于一件事：把灯牌图片保存到你的相册',
              '· 卸载或清空后数据不会残留任何副本',
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: const Text('查看完整隐私政策',
                  style: TextStyle(fontSize: 15, color: LColors.ink)),
              trailing: const Icon(Icons.chevron_right,
                  size: 18, color: LColors.gray2),
              onTap: () => pushPage(context, const PrivacyPolicyPage()),
            ),
          ),
          const SizedBox(height: 12),
          const _Block(
            title: '离线可用',
            text: '所有灯牌和模板都打包在本机，没有网络也能正常亮牌。演唱会场馆信号差的时候，这一点很重要。',
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: const Text('意见反馈',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: LColors.ink)),
              onTap: () => toast(context, '反馈邮箱：info@zuime.com'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: Center(
              child: Text('Made for people who need to be seen.',
                  style: TextStyle(fontSize: 11, color: LColors.gray3)),
            ),
          ),
        ],
      ),
    );
  }
}

const String versionText = kAppVersion;

class _Block extends StatelessWidget {
  final String title;
  final String text;
  final List<String> lines;
  const _Block({required this.title, required this.text, this.lines = const []});

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
                    fontSize: 13, height: 1.9, color: LColors.gray2))),
          ],
        ],
      ),
    );
  }
}
