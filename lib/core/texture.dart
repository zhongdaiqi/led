import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models.dart';
import '../theme.dart';
import 'renderer.dart';

/// 纹理预渲染（对应小程序 utils/texture.js）
///
/// Flutter 没有 Canvas2D 的 shadowBlur，但 TextStyle.shadows 本身就是
/// Skia 的高斯模糊，且跟随 TextPainter/Paragraph 缓存 —— 天然就是"烘焙"。
/// 这里把描边 + 发光 + 主体一次性画进 ui.Picture，播放时只 drawPicture 一次；
/// 闪烁靠 saveLayer 整体调 alpha，不重排文字。

const double kMaxTexSide = 4096;
const double kScrollCharsPerScreen = 2.5;

class LedTexture {
  final ui.Picture picture;
  final double width; // 逻辑尺寸
  final double height;
  final double pad;
  final double textWidth;
  final double size;
  final double lineHeight;
  final double scale;

  const LedTexture({
    required this.picture,
    required this.width,
    required this.height,
    required this.pad,
    required this.textWidth,
    required this.size,
    required this.lineHeight,
    required this.scale,
  });

  void dispose() => picture.dispose();
}

/// ui.Picture 是矢量绘制指令，drawPicture 按逻辑坐标 1:1 重放，
/// 由引擎在光栅化时统一乘 dpr —— 与小程序「物理像素位图 + drawImage 逻辑尺寸」不同。
/// 因此这里不能用 dpr 去乘字号/坐标，否则文字会被放大 2~3 倍、四周被裁掉。
/// 只做「逻辑尺寸是否超出安全范围」的检查；正常屏幕尺寸恒为 1。
double pickScale(double logicalW, double logicalH, double dpr) {
  if (logicalW <= kMaxTexSide && logicalH <= kMaxTexSide) return 1;
  // 逻辑画布本身就超大（极少数平板/投屏）：等比缩回上限内，绘制仍用逻辑坐标。
  final shrink = kMaxTexSide / (logicalW > logicalH ? logicalW : logicalH);
  return shrink > 0 ? shrink : 0;
}

TextStyle _baseStyle(double pxSize, LedStyle style) {
  final family = (style.fontFamily.isEmpty || style.fontFamily == 'sans-serif')
      ? null
      : style.fontFamily;
  return TextStyle(
    fontFamily: family,
    fontSize: pxSize,
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

/// 把文字 + 描边 + 发光烘焙成一张纹理。失败返回 null（调用方走逐帧降级）。
LedTexture? build({
  required List<String> lines,
  required double size,
  required LedStyle style,
  required double dpr,
}) {
  final lh = style.lineHeight > 0 ? style.lineHeight : 1.15;
  final glow = style.glow > 0 ? style.glow : 0.0;
  final strokeWidth = style.strokeWidth > 0 ? style.strokeWidth : 0.0;

  var maxLineW = 0.0;
  for (final line in lines) {
    final w = measureLine(line, size, style);
    if (w > maxLineW) maxLineW = w;
  }
  if (maxLineW <= 0) return null;

  // 光晕留白：2 倍 glow 基本扩散到肉眼不可见处
  final pad = (glow * 2 + strokeWidth + 4).ceil().toDouble();
  final logicalW = maxLineW.ceil() + pad * 2;
  final logicalH = (lines.length * size * lh).ceil() + pad * 2;

  final scale = pickScale(logicalW, logicalH, dpr);
  if (scale == 0) return null;

  // Picture 记录逻辑坐标，drawPicture 原样重放；引擎光栅化时才乘 dpr。
  // 所以绘制坐标、字号、描边、模糊半径全部用逻辑值，不能乘 scale/dpr。
  if (logicalW < 1 || logicalH < 1) return null;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.save();

  final pxSize = size * scale;
  final pxLineH = pxSize * lh;
  final cx = logicalW / 2;
  final top = pad;

  final base = _baseStyle(pxSize, style);
  final color = ui.Color(colorValueOf(style.color, fallback: 0xFFFF2D2D));

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty) continue;
    final y = top + i * pxLineH;

    // 描边层（foreground 负责颜色，TextStyle.color 必须留空）
    if (strokeWidth > 0 && style.strokeColor.isNotEmpty) {
      final strokeColor = ui.Color(colorValueOf(style.strokeColor));
      final strokeStyle = base.copyWith(
        color: null,
        foreground: ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = ui.StrokeJoin.round
          ..color = strokeColor,
      );
      final sp = _makePainter(line, strokeStyle);
      sp.paint(canvas, ui.Offset(cx - sp.width / 2, y));
    }

    // 发光 + 主体：两层近远阴影烘进 paragraph，播放时不再计算
    final fillStyle = base.copyWith(
      color: color,
      shadows: glow > 0
          ? [
              ui.Shadow(color: color, blurRadius: glow * 0.3),
              ui.Shadow(color: color, blurRadius: glow * 0.7),
            ]
          : null,
    );
    final fp = _makePainter(line, fillStyle);
    fp.paint(canvas, ui.Offset(cx - fp.width / 2, y));
  }

  canvas.restore();
  return LedTexture(
    picture: recorder.endRecording(),
    width: logicalW,
    height: logicalH,
    pad: pad,
    textWidth: maxLineW,
    size: size,
    lineHeight: lh,
    scale: scale,
  );
}

/// 判断纹理能否复用：任何影响像素的字段变了都必须重建。
String keyOf(Preset preset, double size) => [
      preset.text,
      (size * 100).round().toString(),
      preset.style.color,
      preset.style.strokeColor,
      preset.style.strokeWidth.toString(),
      preset.style.glow.toString(),
      preset.style.lineHeight.toString(),
      preset.style.fontFamily,
    ].join('\u0001');

class FitResult {
  final List<String> lines;
  final double size;
  final bool isScroll;
  final double lineHeight;
  const FitResult({
    required this.lines,
    required this.size,
    required this.isScroll,
    required this.lineHeight,
  });
}

/// 全项目唯一的「字该多大」规则：编辑预览 / 播放 / 出图都调它。
FitResult fitText(Preset preset, double width, double height) {
  final style = preset.style;
  final lh = style.lineHeight > 0 ? style.lineHeight : 1.15;
  final isScroll = preset.mode == 'scroll-h';
  final lines = preset.text.split('\n');

  final size = fitFontSize(
    lines,
    isScroll ? double.infinity : width * 0.92,
    height * 0.84,
    lh,
    style: style,
    sizeCap: isScroll ? (width * 0.92) / kScrollCharsPerScreen : null,
  );
  return FitResult(lines: lines, size: size, isScroll: isScroll, lineHeight: lh);
}

class LedStage {
  final List<String> lines;
  final double size;
  final LedTexture? texture;
  final LedStyle style;
  final LedBg bg;
  final double scrollEnter;
  final double scrollExit;

  const LedStage({
    required this.lines,
    required this.size,
    required this.texture,
    required this.style,
    required this.bg,
    required this.scrollEnter,
    required this.scrollExit,
  });
}

/// 一次性准备舞台：算字号 → 烘焙纹理 → 算滚动边界。
LedStage prepareStage(Preset preset, double width, double height, double dpr) {
  final fit = fitText(preset, width, height);
  final style = preset.style.copyWith(lineHeight: fit.lineHeight);
  final tex = build(
    lines: fit.lines,
    size: fit.size,
    style: style,
    dpr: dpr,
  );

  late final double scrollEnter;
  late final double scrollExit;
  if (tex != null) {
    scrollEnter = width - tex.pad;
    scrollExit = -tex.pad - tex.textWidth;
  } else {
    scrollEnter = width;
    scrollExit = -maxLineWidth(fit.lines, fit.size, style);
  }

  return LedStage(
    lines: fit.lines,
    size: fit.size,
    texture: tex,
    style: style,
    bg: preset.bg,
    scrollEnter: scrollEnter,
    scrollExit: scrollExit,
  );
}
