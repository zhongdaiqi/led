import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models.dart';
import '../theme.dart';
import 'texture.dart';

/// 出图：按目标像素**重新排版重绘**，不是把屏幕截图放大。
/// 1920 宽的海报里字号按 1920 重新二分，描边和光晕不会插值成糊色块。
///
/// poster 1920×1080（16:9，存相册）
/// card   1000×800 （5:4，转发卡片；不能从 16:9 裁，会切掉头尾两字）
const Map<String, Size> kExportSpecs = {
  'poster': Size(1920, 1080),
  'card': Size(1000, 800),
};

Future<Uint8List> exportImage(Preset preset, String kind) async {
  final spec = kExportSpecs[kind] ?? kExportSpecs['poster']!;
  final W = spec.width;
  final H = spec.height;

  // 滚动牌在静图里没有"滚动"这回事，按静态排版把整句缩进屏内
  final flat = preset.copy()..mode = 'static';
  final fit = fitText(flat, W, H);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.save();
  canvas.drawRect(
    ui.Offset.zero & spec,
    ui.Paint()..color = ui.Color(colorValueOf(preset.bg.color)),
  );

  final base = _style(fit.size, flat.style);
  final color = ui.Color(colorValueOf(flat.style.color, fallback: 0xFFFF2D2D));
  final fill = base.copyWith(
    color: color,
    shadows: flat.style.glow > 0
        ? [
            ui.Shadow(color: color, blurRadius: flat.style.glow * 0.3),
            ui.Shadow(color: color, blurRadius: flat.style.glow * 0.7),
          ]
        : null,
  );

  final lineH = fit.size * fit.lineHeight;
  for (var i = 0; i < fit.lines.length; i++) {
    final line = fit.lines[i];
    if (line.isEmpty) continue;
    if (flat.style.strokeWidth > 0 && flat.style.strokeColor.isNotEmpty) {
      final strokeColor = ui.Color(colorValueOf(flat.style.strokeColor));
      final sp = _makePainter(
        line,
        base.copyWith(
          color: null,
          foreground: ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = flat.style.strokeWidth
            ..strokeJoin = ui.StrokeJoin.round
            ..color = strokeColor,
        ),
      );
      sp.paint(canvas, ui.Offset((W - sp.width) / 2, i * lineH));
    }
    final fp = _makePainter(line, fill);
    fp.paint(canvas, ui.Offset((W - fp.width) / 2, i * lineH));
  }
  canvas.restore();

  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(W.round(), H.round());
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

TextStyle _style(double size, LedStyle style) {
  final family = (style.fontFamily.isEmpty || style.fontFamily == 'sans-serif')
      ? null
      : style.fontFamily;
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: FontWeight.w900,
    height: style.lineHeight,
    letterSpacing: style.letterSpacing,
  );
}

TextPainter _makePainter(String text, TextStyle style) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
}
