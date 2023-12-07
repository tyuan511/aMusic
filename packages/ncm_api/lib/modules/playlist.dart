part of '../ncm_api.dart';

Future<PlaylistUserRes> getUserPlaylist(int uid) async {
  final res = await request.get('/user/playlist', params: {"uid": uid});
  return PlaylistUserRes.fromJson(res.data);
}

Future<PlaylistDetailRes> getPlaylistDetail(int id) async {
  final res = await request.get('/playlist/detail', params: {"id": id});
  return PlaylistDetailRes.fromJson(res.data);
}

Future<PlaylistRecommandRes> getRecommandPlaylist() async {
  final res = await request.get('/recommend/resource');
  return PlaylistRecommandRes.fromJson(res.data);
}
