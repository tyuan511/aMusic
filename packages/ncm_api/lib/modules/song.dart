part of '../ncm_api.dart';

Future<SongRecommandRes> getRecommandSong() async {
  final res = await request.get('/recommend/songs');
  return SongRecommandRes.fromJson(res.data);
}

Future<SongUrlRes> getSongURL(int id) async {
  final res = await request.get('/song/url', params: {'id': id});
  return SongUrlRes.fromJson(res.data);
}

Future<SongLyricRes> getLyric(int id) async {
  final res = await request.get('/lyric', params: {'id': id});
  return SongLyricRes.fromJson(res.data);
}
