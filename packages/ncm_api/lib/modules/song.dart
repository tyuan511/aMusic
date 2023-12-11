part of '../ncm_api.dart';

Future<SongRecommandRes> getRecommandSong() async {
  final res = await request.get('/recommend/songs');
  return SongRecommandRes.fromJson(res.data);
}

Future<SongUrlRes> getSongURL(List<int> ids, {String level = 'exhigh'}) async {
  final res = await request.get('/song/url/v1', params: {'id': ids.join(','), 'level': level});
  return SongUrlRes.fromJson(res.data);
}

Future<SongLyricRes> getLyric(int id) async {
  final res = await request.get('/lyric', params: {'id': id});
  return SongLyricRes.fromJson(res.data);
}
