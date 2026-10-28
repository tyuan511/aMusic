# aMusic

第三方网易云音乐客户端：Flutter 前端 + 自研 Rust 播放引擎，一套代码覆盖 Android、iOS、macOS、Windows、Linux 五个平台。直连网易云音乐 eapi/weapi 接口，中间没有自建服务器，登录态与偏好只存在本机。

> 状态：v2.0（`2.0.0+20`），积极开发中；推送 `v*` tag 时 CI 会打包五个平台的安装包并发布到 [GitHub Releases](https://github.com/tyuan511/aMusic/releases)。
> 许可：尚未附加许可证文件，版权所有。

## 为什么是 aMusic

- **没有中间层**：客户端直接加密连接网易云音乐接口（eapi/weapi），仓库里没有任何服务端代码，私人数据不经过第三方。
- **一套代码五个平台**：同一套 UI 与播放逻辑跑在手机和桌面上，五个平台的打包均由 CI（`.github/workflows/release.yml`）验证。
- **自研 Rust 播放引擎**：`packages/amusic_engine` 以 Symphonia 解析音频、以流式音源供声，作为各平台 just_audio 的后端。
- **逐字歌词**：支持逐字（YRC）卡拉OK歌词滚动，而不只是逐行高亮。

## 功能

- 首页：每日推荐、私人漫游、精选歌单、最近播放
- 发现：排行榜、搜索，歌单 / 专辑 / 艺人详情与评论
- 我的音乐：创建与收藏的歌单、红心、播放历史
- 本地音乐：扫描本地音频文件（mp3 / flac / m4a / ogg / wav / aac），读取标签与封面，按 ReplayGain 标签归一化音量
- 正在播放：逐字卡拉OK歌词、播放队列、评论、歌词分享为图片、均衡器
- 登录：网易云音乐 App 扫码登录，同步歌单与红心
- 桌面端：窗口管理与全局键盘快捷键

## 快速开始

前置条件：Flutter stable（Dart ≥ 3.13，见 `pubspec.yaml`）与 Rust 工具链——引擎 crate 由各平台自己的构建（Gradle / CocoaPods / CMake）编译。

```bash
git clone https://github.com/tyuan511/aMusic.git
cd aMusic
flutter pub get
flutter run -d macos   # 或 android / ios / windows / linux
```

不想自己编译的话，到 [GitHub Releases](https://github.com/tyuan511/aMusic/releases) 下载对应平台的打包产物。

## 界面预览

![首页：每日推荐、私人漫游轮播与最近播放](./screenshots/home.png)

![正在播放：封面、逐字歌词与播放队列/评论面板](./screenshots/now_playing.jpg)

## 项目结构

- `lib/` — Flutter 应用主体（UI、服务、网易云接口层）
- `packages/amusic_engine/` — Rust 播放引擎与各平台 FFI 绑定
