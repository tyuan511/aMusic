library ncm_api;

import 'package:ncm_api/modules/response/login_check_qr.dart';
import 'package:ncm_api/modules/response/login_create_qr.dart';
import 'package:ncm_api/modules/response/login_get_qrkey.dart';
import 'package:ncm_api/modules/response/login_status.dart';
import 'package:ncm_api/modules/response/playlist_detail.dart';
import 'package:ncm_api/modules/response/playlist_recommand.dart';
import 'package:ncm_api/modules/response/playlist_user.dart';
import 'package:ncm_api/modules/response/song_lyric.dart';
import 'package:ncm_api/modules/response/song_recommand.dart';
import 'package:ncm_api/modules/response/song_url.dart';
import 'package:ncm_api/utils/request.dart';

part 'modules/user.dart';
part 'modules/playlist.dart';
part 'modules/song.dart';

Future<void> init({required String cookiePath}) async {
  await request.init(cookiePath);
}
