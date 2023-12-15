import 'dart:io';

import 'package:ncm_api/netease_api.dart';
import 'package:path_provider/path_provider.dart';

late Repository repo;

Future<void> initApi() async {
  final Directory dir = await getApplicationDocumentsDirectory();
  repo = Repository('${dir.path}/.cookies/');
}
