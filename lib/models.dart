import 'dart:convert';

/// 数据模型 —— 字段与小程序 utils/storage.js 的 Preset / Settings 完全一致。
/// 所有 fromJson 都做容错：小程序版本写入的旧数据、缺字段数据都不能让 App 崩。

double _num(Object? v, [double d = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? d;
  return d;
}

int _int(Object? v, [int d = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? d;
  return d;
}

bool _bool(Object? v, [bool d = false]) {
  if (v is bool) return v;
  if (v is String) return v == 'true';
  return d;
}

String _str(Object? v, [String d = '']) => v is String ? v : d;

class LedStyle {
  final String fontFamily;
  final double fontSize;
  final String color;
  final String colorMode;
  final List<String> gradient;
  final String strokeColor;
  final double strokeWidth;
  final double glow;
  final double letterSpacing;
  final double lineHeight;
  final String align;
  final bool mirror;

  const LedStyle({
    this.fontFamily = 'sans-serif',
    this.fontSize = 1,
    this.color = '#FF2D2D',
    this.colorMode = 'solid',
    this.gradient = const [],
    this.strokeColor = '',
    this.strokeWidth = 0,
    this.glow = 16,
    this.letterSpacing = 0,
    this.lineHeight = 1.15,
    this.align = 'center',
    this.mirror = false,
  });

  factory LedStyle.fromJson(Map<String, dynamic>? j) {
    final s = j ?? const <String, dynamic>{};
    return LedStyle(
      fontFamily: _str(s['fontFamily'], 'sans-serif'),
      fontSize: s['fontSize'] == null ? 1 : _num(s['fontSize'], 1),
      color: _str(s['color'], '#FF2D2D'),
      colorMode: _str(s['colorMode'], 'solid'),
      gradient: (s['gradient'] is List)
          ? (s['gradient'] as List).map((e) => _str(e)).toList()
          : const [],
      strokeColor: _str(s['strokeColor']),
      strokeWidth: _num(s['strokeWidth']),
      glow: _num(s['glow'], 16),
      letterSpacing: _num(s['letterSpacing']),
      lineHeight: s['lineHeight'] == null ? 1.15 : _num(s['lineHeight'], 1.15),
      align: _str(s['align'], 'center'),
      mirror: _bool(s['mirror']),
    );
  }

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'color': color,
        'colorMode': colorMode,
        'gradient': gradient,
        'strokeColor': strokeColor,
        'strokeWidth': strokeWidth,
        'glow': glow,
        'letterSpacing': letterSpacing,
        'lineHeight': lineHeight,
        'align': align,
        'mirror': mirror,
      };

  LedStyle copyWith({
    String? fontFamily,
    double? fontSize,
    String? color,
    String? colorMode,
    List<String>? gradient,
    String? strokeColor,
    double? strokeWidth,
    double? glow,
    double? letterSpacing,
    double? lineHeight,
    String? align,
    bool? mirror,
  }) {
    return LedStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      colorMode: colorMode ?? this.colorMode,
      gradient: gradient ?? this.gradient,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      glow: glow ?? this.glow,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineHeight: lineHeight ?? this.lineHeight,
      align: align ?? this.align,
      mirror: mirror ?? this.mirror,
    );
  }
}

class LedBg {
  final String type;
  final String color;
  final List<String> gradient;
  final String image;
  final double dim;

  const LedBg({
    this.type = 'solid',
    this.color = '#000000',
    this.gradient = const [],
    this.image = '',
    this.dim = 0,
  });

  factory LedBg.fromJson(Map<String, dynamic>? j) {
    final b = j ?? const <String, dynamic>{};
    return LedBg(
      type: _str(b['type'], 'solid'),
      color: _str(b['color'], '#000000'),
      gradient: (b['gradient'] is List)
          ? (b['gradient'] as List).map((e) => _str(e)).toList()
          : const [],
      image: _str(b['image']),
      dim: _num(b['dim']),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'color': color,
        'gradient': gradient,
        'image': image,
        'dim': dim,
      };

  LedBg copyWith({String? color, String? type, String? image, double? dim}) {
    return LedBg(
      type: type ?? this.type,
      color: color ?? this.color,
      gradient: gradient,
      image: image ?? this.image,
      dim: dim ?? this.dim,
    );
  }
}

class Preset {
  String id;
  String name;
  String text;
  String mode;
  LedStyle style;
  LedBg bg;
  double speed;
  String orientation;
  bool favorite;
  int usageCount;
  int createdAt;
  int updatedAt;
  int lastUsedAt;
  bool isTemplate;

  Preset({
    this.id = '',
    this.name = '',
    this.text = '',
    this.mode = 'static',
    LedStyle? style,
    LedBg? bg,
    this.speed = 80,
    this.orientation = 'auto',
    this.favorite = false,
    this.usageCount = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.lastUsedAt = 0,
    this.isTemplate = false,
  })  : style = style ?? const LedStyle(),
        bg = bg ?? const LedBg();

  factory Preset.fromJson(Map<String, dynamic>? j) {
    final p = j ?? const <String, dynamic>{};
    return Preset(
      id: _str(p['id']),
      name: _str(p['name']),
      text: _str(p['text']),
      mode: _str(p['mode'], 'static'),
      style: LedStyle.fromJson(p['style'] is Map ? Map<String, dynamic>.from(p['style']) : null),
      bg: LedBg.fromJson(p['bg'] is Map ? Map<String, dynamic>.from(p['bg']) : null),
      speed: p['speed'] == null ? 80 : _num(p['speed'], 80),
      orientation: _str(p['orientation'], 'auto'),
      favorite: _bool(p['favorite']),
      usageCount: _int(p['usageCount']),
      createdAt: _int(p['createdAt']),
      updatedAt: _int(p['updatedAt']),
      lastUsedAt: _int(p['lastUsedAt']),
      isTemplate: _bool(p['isTemplate']),
    );
  }

  factory Preset.fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return Preset.fromJson(decoded);
    } catch (_) {}
    return Preset();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'text': text,
        'mode': mode,
        'style': style.toJson(),
        'bg': bg.toJson(),
        'speed': speed,
        'orientation': orientation,
        'favorite': favorite,
        'usageCount': usageCount,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'lastUsedAt': lastUsedAt,
        'isTemplate': isTemplate,
      };

  String toJsonString() => jsonEncode(toJson());

  Preset copy() => Preset.fromJson(Map<String, dynamic>.from(toJson()));

  /// 最近使用优先；没用过的按更新时间。与 storage.getRecentPresets 一致。
  static int recentKey(Preset p) => p.lastUsedAt > 0 ? p.lastUsedAt : p.updatedAt;
}

class AppSettings {
  String defaultOrientation;
  bool autoMaxBrightness;
  String defaultBgColor;
  bool lowPowerMode;
  String lastPresetId;
  bool hasSeenGuide;
  /// 已同意的隐私协议版本；0 表示从未同意。协议升级后重新弹窗。
  int privacyVersion;

  AppSettings({
    this.defaultOrientation = 'auto',
    this.autoMaxBrightness = true,
    this.defaultBgColor = '#000000',
    this.lowPowerMode = false,
    this.lastPresetId = '',
    this.hasSeenGuide = false,
    this.privacyVersion = 0,
  });

  factory AppSettings.fromJson(Map<String, dynamic>? j) {
    final s = j ?? const <String, dynamic>{};
    return AppSettings(
      defaultOrientation: _str(s['defaultOrientation'], 'auto'),
      autoMaxBrightness: s['autoMaxBrightness'] == null ? true : _bool(s['autoMaxBrightness'], true),
      defaultBgColor: _str(s['defaultBgColor'], '#000000'),
      lowPowerMode: _bool(s['lowPowerMode']),
      lastPresetId: _str(s['lastPresetId']),
      hasSeenGuide: _bool(s['hasSeenGuide']),
      privacyVersion: _int(s['privacyVersion']),
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultOrientation': defaultOrientation,
        'autoMaxBrightness': autoMaxBrightness,
        'defaultBgColor': defaultBgColor,
        'lowPowerMode': lowPowerMode,
        'lastPresetId': lastPresetId,
        'hasSeenGuide': hasSeenGuide,
        'privacyVersion': privacyVersion,
      };
}
