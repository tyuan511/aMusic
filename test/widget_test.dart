// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:amusic/extensions/duration.dart';
import 'package:amusic/models/lyric.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    //this string contains a LRC that can be parsed
    String unparsedLrc =
        """[00:00.00] 作词 : 斯琴Mia\n[00:01.00] 作曲 : 斯琴Mia\n[00:02.00] 编曲 : YC3691\n[00:03.00] 制作人 : YC3691\n[00:19.32][02:22.52]她总说她过的很好\n[00:22.11][02:24.99]不用担心只要你把自己照顾好\n[00:28.98][02:32.20]她总说她还没变老\n[00:31.71][02:34.64]不用牵挂她什么东西都不需要\n[00:38.58][02:41.58]她总说别为了钞票\n[00:41.28][02:43.78]太忙太累身体健康最重要\n[00:48.15][02:50.67]她总爱说你长大了\n[00:50.79][02:53.40]心里却还把你当成儿时的宝\n[00:58.32][03:00.13]皱纹爬上她眼角\n[01:03.18][03:05.37]她说她最近记忆不好\n[01:07.83][03:10.24]什么时候你才发现\n[01:11.28][03:13.84]陪伴她的时间太少\n[01:21.87][03:23.90][04:06.24]有你在的城市她每天都在惦念\n[01:26.19][03:28.19][04:10.54]关心那里的天气是否让她安心一点\n[01:31.29][03:33.36][04:15.69]买了你童年爱吃的新鲜\n[01:35.94][03:37.71][04:19.98]等你等了很多天\n[01:40.56][03:42.59][04:24.71]很久没打电话的你她说很想念\n[01:45.03][03:47.02][04:29.28]又不忍心打扰怕占用了你太多时间\n[03:52.19][01:50.46][04:34.69]什么时候她和你的生活疏远\n[03:59.11][01:57.48][04:41.35]你好像都没发觉\n[04:46.32] 和音编唱 : 冯甜甜\n[04:51.29] 混音/母带 : 王禹茨\n[04:56.26] 监制 : 杨子杰\n[05:01.23] 录音棚 : 盛声国际\n[05:06.20] 统筹 : 明楦/淑琦\n[05:11.17] 制作公司 : Dreamer音乐\n[05:16.14] 营销推广 : 心心向上/大声密谋\n[05:21.11] 出品公司 : 索尼音乐x北京尧上音乐教育科技有限公司\n[05:26.08] 出品人 : Andrew Chan陈国威\n""";
    for (var lrc in LyricRow.fromString(unparsedLrc)) {
      print('${lrc.time.formate()} ${lrc.text}');
    }
  });
}
