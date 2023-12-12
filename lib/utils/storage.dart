import 'package:get_storage/get_storage.dart';

final GetStorage storage = GetStorage();

Future<void> initStorage() async {
  await GetStorage.init();
}
