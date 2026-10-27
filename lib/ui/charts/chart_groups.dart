import '../../models/discovery.dart';

/// Toplists grouped the way the charts page shows them.
class ChartGroups {
  const ChartGroups({
    this.official = const [],
    this.global = const [],
    this.featured = const [],
  });

  /// NetEase's own 飙升 / 新歌 / 热歌 / 原创 charts.
  final List<Toplist> official;

  /// Foreign / regional charts (Billboard, UK, Oricon, 韩国 ...).
  final List<Toplist> global;

  /// Everything else (genre and themed charts).
  final List<Toplist> featured;

  bool get isEmpty => official.isEmpty && global.isEmpty && featured.isEmpty;
}

const List<String> _globalKeywords = [
  'billboard',
  'uk',
  'oricon',
  'beatport',
  'itunes',
  'spotify',
  'apple',
  'melon',
  'genie',
  'mnet',
  '美国',
  '英国',
  '日本',
  '韩国',
  '法国',
  '俄罗斯',
  '越南',
  '泰国',
  '台湾',
  '香港',
  '欧美',
  '日语',
  '韩语',
  '全球',
  '国际',
];

/// Whether a toplist is a foreign / regional chart.
bool isGlobalChart(Toplist list) {
  final name = list.name.toLowerCase();
  return _globalKeywords.any(name.contains);
}

/// Splits [lists] into official, global and featured charts, keeping the
/// server order inside each group.
ChartGroups groupCharts(List<Toplist> lists) {
  final official = <Toplist>[];
  final global = <Toplist>[];
  final featured = <Toplist>[];
  for (final list in lists) {
    if (list.isOfficial) {
      official.add(list);
    } else if (isGlobalChart(list)) {
      global.add(list);
    } else {
      featured.add(list);
    }
  }
  return ChartGroups(official: official, global: global, featured: featured);
}
