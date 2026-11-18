import 'package:flutter/foundation.dart';

/// 灯牌库变更信号：新建/删除/编辑后触发，让保活的 home/mine 页
/// 在从播放页返回时重载列表（IndexedStack 不会重建子页，不能只靠 initState）。
///
/// 单独放一个文件，避免 app.dart 与各业务页互相 import 形成环。
final ValueNotifier<int> kLibraryChanged = ValueNotifier<int>(0);
