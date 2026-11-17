/// 编辑器调色板 —— 与小程序 utils/palette.js 逐项对应。
/// 约束：模板用到的每一个颜色都必须在这里存在，否则套用模板后色块不高亮。
class Swatch {
  final String hex;
  final String name;
  const Swatch(this.hex, this.name);
}

const List<Swatch> kTextColors = [
  Swatch('#FF2D2D', '应援红'),
  Swatch('#FFD700', '金'),
  Swatch('#FFD60A', '亮黄'),
  Swatch('#FFA500', '橙'),
  Swatch('#FF6FD8', '粉'),
  Swatch('#FF4D9D', '玫红'),
  Swatch('#BF5AF2', '紫'),
  Swatch('#0A84FF', '蓝'),
  Swatch('#00E5FF', '青'),
  Swatch('#34C759', '绿'),
  Swatch('#FFFFFF', '白'),
  Swatch('#C7C7CC', '灰白'),
  Swatch('#000000', '黑'),
];

const List<Swatch> kBgColors = [
  Swatch('#000000', '黑'),
  Swatch('#1C1C1E', '深灰'),
  Swatch('#C8102E', '红'),
  Swatch('#0B3D2E', '墨绿'),
  Swatch('#0A2540', '深蓝'),
  Swatch('#FFFFFF', '白'),
  Swatch('#FFD100', '黄'),
  Swatch('#F2F2F7', '浅灰'),
];

const List<Swatch> kModes = [
  Swatch('static', '静态'),
  Swatch('scroll-h', '滚动'),
  Swatch('blink', '闪烁'),
];
