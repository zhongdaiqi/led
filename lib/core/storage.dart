import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// 本地数据层 —— 全项目唯一的持久化出口。
/// key 前缀 lp: 与小程序一致；所有读写失败都吞掉，返回兜底值。
/// 用内存缓存 + 异步落盘：页面同步读，写入点统一 await flush()。
class Storage with WidgetsBindingObserver {
  static final Storage instance = Storage._();
  Storage._();

  bool _observerRegistered = false;

  static const String kPresets = 'lp:presets';
  static const String kSettings = 'lp:settings';
  static const String kPhrases = 'lp:phrases';
  static const String kFavorites = 'lp:favTpl';
  static const int maxKeyBytes = 800 * 1024;

  SharedPreferences? _prefs;
  List<Preset> _presets = [];
  AppSettings _settings = AppSettings();
  List<String> _phrases = [];
  List<String> _favorites = [];

  /// 串行写入队列。所有落盘都挂在这条链上，杜绝并发 setString 相互覆盖
  /// （亮牌时 upsertPreset 与播放页 touchPreset 会连着写同一个 key）。
  Future<void> _writeChain = Future.value();

  /// 等待所有已排队的写入真正落盘。切后台 / 退出前调用，防止 iOS 上
  /// 未完成的异步写入被系统冻结而丢失。
  Future<void> flush() => _writeChain;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 亮牌保存是异步落盘。用户点完亮牌常立刻锁屏/切后台，此时必须等
    // 已排队的写入真正落盘，否则 iOS 上会被系统冻结导致「没保存」。
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      flush();
    }
  }

  static const List<String> defaultPhrases = [
    '谢谢',
    '不用了，谢谢',
    '请让一下',
    '我听不见，可以打字吗',
    '我在开会，稍后回复',
    '这个位子有人',
    '多少钱',
    '可以扫码吗',
    '我身体不舒服',
    '请帮我叫一下医生',
    '洗手间在哪',
    '我要下车',
    '麻烦小声一点',
    '我在等你',
    '好',
    '不行',
  ];

  Future<void> init() async {
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
    }
    _presets = _decodeList<Preset>(_read(kPresets), Preset.fromJsonString);
    _settings = AppSettings.fromJson(_decodeMap(_read(kSettings)));
    final phrases = _decodeList<String>(_read(kPhrases), (s) => s);
    _phrases = phrases.isEmpty ? List<String>.from(defaultPhrases) : phrases;
    _favorites = _decodeList<String>(_read(kFavorites), (s) => s);
  }

  String? _read(String key) {
    try {
      return _prefs?.getString(key);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : const {};
    } catch (_) {
      return const {};
    }
  }

  static List<T> _decodeList<T>(String? raw, T Function(String) decode) {
    // 必须返回可变的 List<T>：const [] 的运行时类型是 List<Never> 且不可变，
    // 首次安装（无历史数据）时若把它赋给 _presets，后续 upsert 的 insert 会
    // 抛「type 'X' is not a subtype of type 'Never'」，导致新建灯牌根本存不进去。
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final v = jsonDecode(raw);
      if (v is! List) return <T>[];
      return v.map((e) {
        if (e is String) return decode(e);
        return decode(jsonEncode(e));
      }).toList();
    } catch (_) {
      return <T>[];
    }
  }

  Future<bool> _write(String key, Object value) async {
    try {
      final json = jsonEncode(value);
      // 保守按 UTF-16 估算，和小程序 800KB 水位一致
      if (json.length * 2 > maxKeyBytes) return false;
      final prefs = _prefs;
      if (prefs == null) return false;
      // 排队执行：本次写等上一次写落盘后才开始，避免并发覆盖。
      // 结果通过这条链返回，调用方仍可逐笔 await 自己的写入。
      final task = _writeChain.then((_) => prefs.setString(key, json));
      _writeChain = task.then((_) {}, onError: (_) {});
      return await task;
    } catch (_) {
      return false;
    }
  }

  /* ------------------------------ 灯牌预设 ------------------------------ */

  List<Preset> getPresets() => List<Preset>.from(_presets);

  Preset? getPreset(String id) {
    for (final p in _presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  static String genId() {
    final suffix = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(4, '0').substring(0, 4);
    return 'p_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_$suffix';
  }

  static String nameFromText(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return '未命名';
    return t.length > 8 ? '${t.substring(0, 8)}…' : t;
  }

  /// 新增或覆盖；按 updatedAt 语义 unshift 到首位。
  /// 返回 null 表示写入失败（空间不足）。
  Future<Preset?> upsertPreset(Preset preset) async {
    final now = DateTime.now().microsecondsSinceEpoch ~/ 1000;
    final item = preset.copy();
    if (item.id.isEmpty) {
      item.id = genId();
      item.createdAt = now;
      item.usageCount = 0;
    }
    item.updatedAt = now;
    if (item.name.isEmpty) item.name = nameFromText(item.text);

    final idx = _presets.indexWhere((p) => p.id == item.id);
    if (idx >= 0) {
      _presets[idx] = item;
    } else {
      _presets.insert(0, item);
    }
    final ok = await _write(kPresets, _presets.map((p) => p.toJson()).toList());
    return ok ? item : null;
  }

  Future<void> removePreset(String id) async {
    _presets.removeWhere((p) => p.id == id);
    await _write(kPresets, _presets.map((p) => p.toJson()).toList());
  }

  /// 用一次记一次：usageCount +1、最近使用时间刷新、置顶。
  Future<void> touchPreset(String id) async {
    final idx = _presets.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final item = _presets.removeAt(idx);
    item.usageCount = (item.usageCount) + 1;
    item.lastUsedAt = DateTime.now().microsecondsSinceEpoch ~/ 1000;
    _presets.insert(0, item);
    await _write(kPresets, _presets.map((p) => p.toJson()).toList());
  }

  List<Preset> getRecentPresets([int? limit]) {
    final list = List<Preset>.from(_presets)
      ..sort((a, b) => Preset.recentKey(b).compareTo(Preset.recentKey(a)));
    return limit == null ? list : list.take(limit).toList();
  }

  /* ------------------------------ 设置 ------------------------------ */

  AppSettings getSettings() => AppSettings.fromJson(_settings.toJson());

  Future<AppSettings> patchSettings({
    String? defaultOrientation,
    bool? autoMaxBrightness,
    String? defaultBgColor,
    bool? lowPowerMode,
    String? lastPresetId,
    bool? hasSeenGuide,
    int? privacyVersion,
  }) async {
    if (defaultOrientation != null) _settings.defaultOrientation = defaultOrientation;
    if (autoMaxBrightness != null) _settings.autoMaxBrightness = autoMaxBrightness;
    if (defaultBgColor != null) _settings.defaultBgColor = defaultBgColor;
    if (lowPowerMode != null) _settings.lowPowerMode = lowPowerMode;
    if (lastPresetId != null) _settings.lastPresetId = lastPresetId;
    if (hasSeenGuide != null) _settings.hasSeenGuide = hasSeenGuide;
    if (privacyVersion != null) _settings.privacyVersion = privacyVersion;
    await _write(kSettings, _settings.toJson());
    return getSettings();
  }

  /* ------------------------------ 快捷短语 ------------------------------ */

  /// 与小程序一致：没存过（或尚未 init）时直接返回内置短语，不让对话牌空着。
  List<String> getPhrases() => _phrases.isEmpty
      ? List<String>.from(defaultPhrases)
      : List<String>.from(_phrases);

  Future<void> savePhrases(List<String> list) async {
    _phrases = List<String>.from(list);
    await _write(kPhrases, _phrases);
  }

  /* ------------------------------ 模板收藏 ------------------------------ */

  List<String> getFavorites() => List<String>.from(_favorites);

  bool isFavorite(String id) => _favorites.contains(id);

  /// 新收藏放头部，「我的」页按这个顺序展示。
  Future<bool> toggleFavorite(String id) async {
    if (id.isEmpty) return false;
    final idx = _favorites.indexOf(id);
    if (idx >= 0) {
      _favorites.removeAt(idx);
      await _write(kFavorites, _favorites);
      return false;
    }
    _favorites.insert(0, id);
    return await _write(kFavorites, _favorites);
  }

  /* ------------------------------ 清空 ------------------------------ */

  Future<void> clearAll() async {
    _presets = [];
    _settings = AppSettings();
    _phrases = List<String>.from(defaultPhrases);
    _favorites = [];
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await Future.wait([
        prefs.remove(kPresets),
        prefs.remove(kSettings),
        prefs.remove(kPhrases),
        prefs.remove(kFavorites),
      ]);
    } catch (_) {}
  }
}
