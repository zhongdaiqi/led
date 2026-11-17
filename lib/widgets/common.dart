import 'package:flutter/material.dart';

import '../theme.dart';

void toast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ),
    );
}

Future<T?> pushPage<T extends Object?>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  const SectionTitle({super.key, required this.title, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: LColors.ink)),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTap,
              child: Text(trailing!,
                  style: const TextStyle(fontSize: 13, color: LColors.gray)),
            ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = LColors.red,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
          ),
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String line1;
  final String line2;
  const EmptyHint({super.key, required this.line1, required this.line2});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Text(line1, style: const TextStyle(fontSize: 13, color: LColors.gray2)),
            const SizedBox(height: 4),
            Text(line2, style: const TextStyle(fontSize: 13, color: LColors.gray2)),
          ],
        ),
      ),
    );
  }
}

/// 灯牌缩略卡片（首页 / 模板页 / 我的页共用一块底色 + 字色的方卡）
class LedThumb extends StatelessWidget {
  final String bg;
  final String color;
  final String text;
  final double width;
  final double height;
  final double fontSize;
  final Border? border;
  final Widget? overlay;

  const LedThumb({
    super.key,
    required this.bg,
    required this.color,
    required this.text,
    this.width = 90,
    this.height = 90,
    this.fontSize = 11,
    this.border,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: hexColor(bg),
        borderRadius: BorderRadius.circular(10),
        border: border ?? Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: hexColor(color),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700),
            ),
          ),
          ?overlay,
        ],
      ),
    );
  }
}
