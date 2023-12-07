import 'dart:io';

import 'package:ncm_api/ncm_api.dart' as api;
import 'package:path_provider/path_provider.dart';

initApi() async {
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  final String appDocPath = appDocDir.path;
  await api.init(cookiePath: "$appDocPath/.cookies/");
}
