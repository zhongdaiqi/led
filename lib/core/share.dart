import '../models.dart';
import 'templates.dart';

/// 分享链接编解码。
/// 小程序把「重建这块牌的最小信息」塞进 URL（文字 + 字色 + 底色 + 模式 + 发光），
/// 因为好友手机上没有这块牌。Flutter 端沿用相同的 query 结构，
/// 通过 App 内部路由传递（也可用于深链）。
const int kMaxShareText = 20;
const int kMaxTitleText = 12;
const List<String> kShareModes = ['static', 'scroll-h', 'blink'];

String _hexOf(String v) {
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(v.trim());
  return m == null ? '' : m.group(1)!.toUpperCase();
}

String _fromHex(String v) =>
    RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v) ? '#${v.toUpperCase()}' : '';

/// 与小程序 share.buildQuery 一致（不含前导 ?）。
String buildQuery(Preset preset) {
  final parts = <String>[
    'src=share',
    't=${Uri.encodeComponent(preset.text.substring(0, preset.text.length < kMaxShareText ? preset.text.length : kMaxShareText))}',
  ];

  final c = _hexOf(preset.style.color);
  if (c.isNotEmpty) parts.add('c=$c');
  final b = _hexOf(preset.bg.color);
  if (b.isNotEmpty) parts.add('b=$b');

  if (preset.mode != 'static' && kShareModes.contains(preset.mode)) {
    parts.add('m=${preset.mode}');
  }

  final glow = preset.style.glow.round();
  if (glow > 0) parts.add('g=${glow.clamp(0, 40)}');

  return parts.join('&');
}

String buildPath(Preset preset) => '/play?$buildQuery(preset)';

/// 从 query 重建牌。注意 Flutter Uri.queryParameters 已 decode 一次，
/// 绝不能再 Uri.decodeComponent —— 文字里带 % 会抛异常。
Preset? presetFromQuery(Map<String, String> query) {
  if (query['src'] != 'share') return null;
  final text = (query['t'] ?? '').trim();
  if (text.isEmpty) return null;

  final p = Preset.fromJson(fallbackPreset.toJson());
  p.id = '';
  p.name = '分享的灯牌';
  p.text = text;
  p.isTemplate = false;

  final c = _fromHex(query['c'] ?? '');
  if (c.isNotEmpty) p.style = p.style.copyWith(color: c);
  final b = _fromHex(query['b'] ?? '');
  if (b.isNotEmpty) p.bg = p.bg.copyWith(color: b);
  if (kShareModes.contains(query['m'])) p.mode = query['m']!;

  final glow = double.tryParse(query['g'] ?? '');
  if (glow != null && glow >= 0) {
    p.style = p.style.copyWith(glow: glow.round().clamp(0, 40).toDouble());
  }
  return p;
}

String titleOf(Preset preset) {
  final t = preset.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return '用「电子灯牌」举了块牌';
  return t.length > kMaxTitleText ? '${t.substring(0, kMaxTitleText)}…' : t;
}
