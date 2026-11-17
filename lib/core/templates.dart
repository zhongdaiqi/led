import '../models.dart';

/// 20 款内置模板 / 5 分类，全部硬编码在本地，无网络请求。
/// 与小程序 utils/templates.js 一一对应；新增模板时记得同步调色板。

const LedStyle kDefaultStyle = LedStyle();

final Preset fallbackPreset = Preset(
  id: 'fallback',
  name: '我的灯牌',
  text: '电子灯牌',
  mode: 'static',
  style: kDefaultStyle,
  bg: const LedBg(color: '#000000'),
  speed: 80,
);

class Template {
  final String id;
  final String name;
  final String category;
  final List<String> tags;
  final String text;
  final String mode;
  final LedStyle style;
  final LedBg bg;
  final double speed;

  const Template({
    required this.id,
    required this.name,
    required this.category,
    required this.tags,
    required this.text,
    required this.mode,
    required this.style,
    required this.bg,
    this.speed = 80,
  });

  Preset toPreset() => Preset(
        id: id,
        name: name,
        text: text,
        mode: mode,
        style: style,
        bg: bg,
        speed: speed,
        isTemplate: true,
      );
}

const List<String> kCategories = ['全部', '应援', '接机', '加油', '沟通', '节日'];

const List<Template> kTemplates = [
  // 应援
  Template(id: 'tpl_yingyuan', name: '应援红', category: '应援', tags: ['演唱会', '偶像', '我爱你', '表白'], text: '我爱你', mode: 'scroll-h', style: LedStyle(color: '#FF2D2D', glow: 20), bg: LedBg(color: '#000000'), speed: 90),
  Template(id: 'tpl_gold', name: '黄金跑马', category: '应援', tags: ['演唱会', '金色', '加油', '应援棒'], text: '永远支持你', mode: 'scroll-h', style: LedStyle(color: '#FFD700', glow: 24), bg: LedBg(color: '#000000'), speed: 120),
  Template(id: 'tpl_pink', name: '荧光粉', category: '应援', tags: ['演唱会', '粉色', '女团', '闪烁'], text: '冲呀', mode: 'blink', style: LedStyle(color: '#FF4D9D', glow: 22), bg: LedBg(color: '#000000'), speed: 80),
  Template(id: 'tpl_blue', name: '蓝色荧光', category: '应援', tags: ['演唱会', '蓝色', '应援棒', '现场'], text: '我们在这里', mode: 'scroll-h', style: LedStyle(color: '#00E5FF', glow: 26), bg: LedBg(color: '#000000'), speed: 100),
  Template(id: 'tpl_classic', name: '经典灯牌', category: '应援', tags: ['红色', '闪烁', '开场', '气氛'], text: '电子灯牌', mode: 'blink', style: LedStyle(color: '#FF2D2D', glow: 24), bg: LedBg(color: '#000000'), speed: 80),

  // 接机
  Template(id: 'tpl_airport', name: '接机牌', category: '接机', tags: ['机场', '接人', '航班', '白底'], text: '接张伟', mode: 'static', style: LedStyle(color: '#000000', glow: 0), bg: LedBg(color: '#FFFFFF'), speed: 80),
  Template(id: 'tpl_board', name: '白底黑字', category: '接机', tags: ['举牌', '找我', '白底', '车站'], text: '举牌找我', mode: 'static', style: LedStyle(color: '#000000', glow: 0), bg: LedBg(color: '#FFFFFF'), speed: 80),
  Template(id: 'tpl_plate', name: '车牌号', category: '接机', tags: ['车牌', '接机', '黄底', '出租车'], text: '京A·88888', mode: 'static', style: LedStyle(color: '#000000', glow: 0), bg: LedBg(color: '#FFD100'), speed: 80),
  Template(id: 'tpl_welcome', name: '欢迎回家', category: '接机', tags: ['接机', '回家', '金色', '车站'], text: '欢迎回家', mode: 'static', style: LedStyle(color: '#FFD700', glow: 18), bg: LedBg(color: '#000000'), speed: 80),

  // 加油
  Template(id: 'tpl_jiayou', name: '加油鸭', category: '加油', tags: ['比赛', '马拉松', '橙色', '鼓励'], text: '加油', mode: 'static', style: LedStyle(color: '#FFA500', glow: 18), bg: LedBg(color: '#000000'), speed: 80),
  Template(id: 'tpl_sprint', name: '冲刺', category: '加油', tags: ['比赛', '跑步', '红色', '闪烁'], text: '加油！！！', mode: 'blink', style: LedStyle(color: '#FF2D2D', glow: 22), bg: LedBg(color: '#000000'), speed: 80),
  Template(id: 'tpl_chase', name: '跑马加油', category: '加油', tags: ['比赛', '绿色', '滚动', '长句'], text: '加油 加油 加油', mode: 'scroll-h', style: LedStyle(color: '#34C759', glow: 18), bg: LedBg(color: '#000000'), speed: 110),

  // 沟通
  Template(id: 'tpl_thanks', name: '谢谢', category: '沟通', tags: ['礼貌', '感谢', '绿色', '面对面'], text: '谢谢', mode: 'static', style: LedStyle(color: '#34C759', glow: 12), bg: LedBg(color: '#000000'), speed: 80),
  Template(id: 'tpl_excuse', name: '请让一下', category: '沟通', tags: ['地铁', '让路', '白色', '面对面'], text: '请让一下', mode: 'static', style: LedStyle(color: '#FFFFFF', glow: 10), bg: LedBg(color: '#000000'), speed: 80),
  Template(id: 'tpl_deaf', name: '我听不见', category: '沟通', tags: ['听障', '无障碍', '黄色', '打字'], text: '我听不见，请打字', mode: 'static', style: LedStyle(color: '#FFD60A', glow: 14), bg: LedBg(color: '#000000'), speed: 80),
  Template(id: 'tpl_meeting', name: '我在开会', category: '沟通', tags: ['会议', '安静', '灰色', '办公室'], text: '我在开会', mode: 'static', style: LedStyle(color: '#C7C7CC', glow: 0), bg: LedBg(color: '#000000'), speed: 80),

  // 节日
  Template(id: 'tpl_birthday', name: '生日快乐', category: '节日', tags: ['生日', '粉色', '闪烁', '蛋糕'], text: '生日快乐', mode: 'blink', style: LedStyle(color: '#FF6FD8', glow: 22), bg: LedBg(color: '#000000'), speed: 80),
  Template(id: 'tpl_marry', name: '求婚', category: '节日', tags: ['求婚', '表白', '红色', '浪漫'], text: '嫁给我', mode: 'static', style: LedStyle(color: '#FFFFFF', glow: 26), bg: LedBg(color: '#C8102E'), speed: 80),
  Template(id: 'tpl_newyear', name: '新年快乐', category: '节日', tags: ['春节', '新年', '金色', '滚动'], text: '新年快乐 万事顺意', mode: 'scroll-h', style: LedStyle(color: '#FFD700', glow: 20), bg: LedBg(color: '#000000'), speed: 90),
  Template(id: 'tpl_xmas', name: '圣诞快乐', category: '节日', tags: ['圣诞', '绿色', '闪烁', '圣诞树'], text: '圣诞快乐', mode: 'blink', style: LedStyle(color: '#FFD700', glow: 20), bg: LedBg(color: '#0B3D2E'), speed: 80),
];

Template? getTemplate(String id) {
  for (final t in kTemplates) {
    if (t.id == id) return t;
  }
  return null;
}

/// 搜索范围：模板名 + 正文 + 分类 + 标签。
/// 用户搜的是场景词（「机场」「表白」），标签必须参与匹配。
List<Template> searchTemplates(String keyword, [String category = '全部']) {
  final base = category == '全部'
      ? kTemplates
      : kTemplates.where((t) => t.category == category).toList();
  final kw = keyword.trim().toLowerCase();
  if (kw.isEmpty) return base;
  return base.where((t) {
    final hay = [t.name, t.text, t.category, ...t.tags].join(' ').toLowerCase();
    return hay.contains(kw);
  }).toList();
}
