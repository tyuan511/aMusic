import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ncm_api/ncm_api.dart' as api;

part 'user.g.dart';

@immutable
class UserInfo {
  final int? id;
  final String? avatarUrl;
  final List<int> likeSongs;

  const UserInfo({this.id, this.avatarUrl, this.likeSongs = const []});

  UserInfo copyWith({int? id, String? avatarUrl, List<int>? likeSongs}) {
    return UserInfo(
      id: id ?? this.id,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      likeSongs: likeSongs ?? this.likeSongs,
    );
  }
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

      getLikeList();
    }
  }

  Future<void> getLikeList() async {
    final res = await api.getLikeList(state.id!);
    state = state.copyWith(likeSongs: res.ids);
  }
}
