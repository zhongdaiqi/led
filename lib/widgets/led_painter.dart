import 'package:flutter/material.dart';

import '../core/renderer.dart';
import '../core/texture.dart';
import '../theme.dart';

/// LED 舞台绘制器。
///
/// 静态牌：stage 不变、offsetX/alpha 不变 → shouldRepaint 返回 false，
/// Flutter 不会重绘这一帧，天然实现小程序的「静态牌 0fps」省电策略。
/// 滚动 / 闪烁：由 Ticker 每帧更新 offsetX / alpha 触发重绘。
class LedPainter extends CustomPainter {
  final LedStage? stage;
  final double? offsetX;
  final double alpha;
  final bool mirror;

  const LedPainter({
    required this.stage,
    required this.offsetX,
    required this.alpha,
    required this.mirror,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = hexColor(stage?.bg.color ?? '#000000');
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final st = stage;
    if (st == null) return;

    canvas.save();
    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    // 闪烁暗相位：整帧不画字，和小程序 alpha<=0.01 直接跳过一致
    if (alpha <= 0.01) {
      canvas.restore();
      return;
    }

    final tex = st.texture;
    final tw = tex?.width ?? maxLineWidth(st.lines, st.size, st.style);
    final th = tex?.height ?? st.lines.length * st.size * st.style.lineHeight;
    final x = offsetX ?? (size.width - tw) / 2;
    final y = (size.height - th) / 2;

    final needAlpha = alpha < 0.999;
    if (needAlpha) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()
          ..colorFilter = ColorFilter.mode(
            Color.fromARGB((alpha * 255).round().clamp(0, 255).toInt(), 255, 255, 255),
            BlendMode.modulate,
          ),
      );
    }

    canvas.save();
    canvas.translate(x, y);
    if (tex != null) {
      canvas.drawPicture(tex.picture);
    } else {
      // 降级路径：纹理建不出来（超长文本 / 超大画布）时逐帧画文字
      final base = textStyleOf(st.size, st.style);
      final fill = base.copyWith(
        color: hexColor(st.style.color, fallback: Colors.red),
        shadows: st.style.glow > 0
            ? [
                Shadow(
                    color: hexColor(st.style.color, fallback: Colors.red),
                    blurRadius: st.style.glow),
              ]
            : null,
      );
      for (var i = 0; i < st.lines.length; i++) {
        final p = TextPainter(
          text: TextSpan(text: st.lines[i], style: fill),
          textDirection: TextDirection.ltr,
        )..layout();
        p.paint(canvas, Offset(0, i * st.size * st.style.lineHeight));
      }
    }
    canvas.restore();

    if (needAlpha) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LedPainter old) {
    return old.stage != stage ||
        old.offsetX != offsetX ||
        old.alpha != alpha ||
        old.mirror != mirror;
  }
}
