import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 本地数据全部在启动阶段直出，不做任何网络请求 —— 「3 秒亮牌」的前提
  await Storage.instance.init();
  runApp(const LedApp());
}
