import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class _Request {
  final _client = Dio(
    BaseOptions(
      baseUrl: 'https://neteaseapi.tangge.me',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
    ),
  );

  init(String cookiePath) async {
    final jar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage(cookiePath),
    );
    _client.interceptors.add(CookieManager(jar));
  }

  Future<Response<T>> get<T>(String url, {Map<String, dynamic>? params}) {
    return _client.get<T>(url, queryParameters: params);
  }

  Future<Response<T>> post<T>(String url, {Map<String, dynamic>? params, Map<String, dynamic>? data}) {
    return _client.post<T>(url, queryParameters: params, data: data);
  }

  Future<Response<T>> put<T>(String url, {Map<String, dynamic>? params, Map<String, dynamic>? data}) {
    return _client.put<T>(url, queryParameters: params, data: data);
  }

  Future<Response<T>> delete<T>(String url, {Map<String, dynamic>? params, Map<String, dynamic>? data}) {
    return _client.delete<T>(url, data: data, queryParameters: params);
  }

  setCookie(String cookie) {}
}

final request = _Request();
