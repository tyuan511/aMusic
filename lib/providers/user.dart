import 'package:flutter/material.dart';
import 'package:laji_music/utils/repo.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
    final res = await repo.loginStatus();
    final profile = res['profile'];

    if (profile != null) {
      state = UserInfo(
        id: profile['userId'],
        avatarUrl: profile['avatarUrl'],
      );

      getLikeList();
    }
  }

  Future<void> getLikeList() async {
    final res = await (await repo.likedList(state.id!)).asFuture;
    state = state.copyWith(likeSongs: res);
  }

  Future<void> likeSong(int id, bool like) async {
    await repo.like(id, like: like);
    await getLikeList();
  }
}
