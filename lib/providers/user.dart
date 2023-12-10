import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ncm_api/ncm_api.dart' as api;

part 'user.g.dart';

@immutable
class UserInfo {
  final int? id;
  final String? avatarUrl;

  const UserInfo({this.id, this.avatarUrl});
}

@riverpod
class User extends _$User {
  @override
  UserInfo build() => const UserInfo();

  Future<void> getInfo() async {
    final res = await api.checkLoginStatus();
    if (res.data.profile != null) {
      state = UserInfo(
        id: res.data.profile!.userId,
        avatarUrl: res.data.profile!.avatarUrl,
      );
    }
  }
}
