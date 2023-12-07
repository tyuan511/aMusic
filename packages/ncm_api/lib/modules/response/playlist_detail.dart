import 'dart:convert';

class PlaylistDetailRes {
  final int code;
  final dynamic relatedVideos;
  final Playlist playlist;
  final dynamic urls;
  final List<Privilege> privileges;
  final dynamic sharedPrivilege;
  final dynamic resEntrance;
  final dynamic fromUsers;
  final int fromUserCount;
  final dynamic songFromUsers;

  PlaylistDetailRes({
    required this.code,
    required this.relatedVideos,
    required this.playlist,
    required this.urls,
    required this.privileges,
    required this.sharedPrivilege,
    required this.resEntrance,
    required this.fromUsers,
    required this.fromUserCount,
    required this.songFromUsers,
  });

  PlaylistDetailRes copyWith({
    int? code,
    dynamic relatedVideos,
    Playlist? playlist,
    dynamic urls,
    List<Privilege>? privileges,
    dynamic sharedPrivilege,
    dynamic resEntrance,
    dynamic fromUsers,
    int? fromUserCount,
    dynamic songFromUsers,
  }) =>
      PlaylistDetailRes(
        code: code ?? this.code,
        relatedVideos: relatedVideos ?? this.relatedVideos,
        playlist: playlist ?? this.playlist,
        urls: urls ?? this.urls,
        privileges: privileges ?? this.privileges,
        sharedPrivilege: sharedPrivilege ?? this.sharedPrivilege,
        resEntrance: resEntrance ?? this.resEntrance,
        fromUsers: fromUsers ?? this.fromUsers,
        fromUserCount: fromUserCount ?? this.fromUserCount,
        songFromUsers: songFromUsers ?? this.songFromUsers,
      );

  factory PlaylistDetailRes.fromRawJson(String str) => PlaylistDetailRes.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PlaylistDetailRes.fromJson(Map<String, dynamic> json) => PlaylistDetailRes(
        code: json["code"],
        relatedVideos: json["relatedVideos"],
        playlist: Playlist.fromJson(json["playlist"]),
        urls: json["urls"],
        privileges: List<Privilege>.from(json["privileges"].map((x) => Privilege.fromJson(x))),
        sharedPrivilege: json["sharedPrivilege"],
        resEntrance: json["resEntrance"],
        fromUsers: json["fromUsers"],
        fromUserCount: json["fromUserCount"],
        songFromUsers: json["songFromUsers"],
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "relatedVideos": relatedVideos,
        "playlist": playlist.toJson(),
        "urls": urls,
        "privileges": List<dynamic>.from(privileges.map((x) => x.toJson())),
        "sharedPrivilege": sharedPrivilege,
        "resEntrance": resEntrance,
        "fromUsers": fromUsers,
        "fromUserCount": fromUserCount,
        "songFromUsers": songFromUsers,
      };
}

class Playlist {
  final int id;
  final String name;
  final double coverImgId;
  final String coverImgUrl;
  final String coverImgIdStr;
  final int adType;
  final int userId;
  final int createTime;
  final int status;
  final bool opRecommend;
  final bool highQuality;
  final bool newImported;
  final int updateTime;
  final int trackCount;
  final int specialType;
  final int privacy;
  final int trackUpdateTime;
  final String commentThreadId;
  final int playCount;
  final int trackNumberUpdateTime;
  final int subscribedCount;
  final int cloudTrackCount;
  final bool ordered;
  final String description;
  final List<dynamic> tags;
  final dynamic updateFrequency;
  final int backgroundCoverId;
  final dynamic backgroundCoverUrl;
  final int titleImage;
  final dynamic titleImageUrl;
  final dynamic englishTitle;
  final dynamic officialPlaylistType;
  final bool copied;
  final dynamic relateResType;
  final List<dynamic> subscribers;
  final bool subscribed;
  final Creator creator;
  final List<Track> tracks;
  final dynamic videoIds;
  final dynamic videos;
  final List<TrackId> trackIds;
  final dynamic bannedTrackIds;
  final dynamic mvResourceInfos;
  final int shareCount;
  final int commentCount;
  final dynamic remixVideo;
  final dynamic sharedUsers;
  final dynamic historySharedUsers;
  final String gradeStatus;
  final dynamic score;
  final dynamic algTags;
  final int trialMode;

  Playlist({
    required this.id,
    required this.name,
    required this.coverImgId,
    required this.coverImgUrl,
    required this.coverImgIdStr,
    required this.adType,
    required this.userId,
    required this.createTime,
    required this.status,
    required this.opRecommend,
    required this.highQuality,
    required this.newImported,
    required this.updateTime,
    required this.trackCount,
    required this.specialType,
    required this.privacy,
    required this.trackUpdateTime,
    required this.commentThreadId,
    required this.playCount,
    required this.trackNumberUpdateTime,
    required this.subscribedCount,
    required this.cloudTrackCount,
    required this.ordered,
    required this.description,
    required this.tags,
    required this.updateFrequency,
    required this.backgroundCoverId,
    required this.backgroundCoverUrl,
    required this.titleImage,
    required this.titleImageUrl,
    required this.englishTitle,
    required this.officialPlaylistType,
    required this.copied,
    required this.relateResType,
    required this.subscribers,
    required this.subscribed,
    required this.creator,
    required this.tracks,
    required this.videoIds,
    required this.videos,
    required this.trackIds,
    required this.bannedTrackIds,
    required this.mvResourceInfos,
    required this.shareCount,
    required this.commentCount,
    required this.remixVideo,
    required this.sharedUsers,
    required this.historySharedUsers,
    required this.gradeStatus,
    required this.score,
    required this.algTags,
    required this.trialMode,
  });

  Playlist copyWith({
    int? id,
    String? name,
    double? coverImgId,
    String? coverImgUrl,
    String? coverImgIdStr,
    int? adType,
    int? userId,
    int? createTime,
    int? status,
    bool? opRecommend,
    bool? highQuality,
    bool? newImported,
    int? updateTime,
    int? trackCount,
    int? specialType,
    int? privacy,
    int? trackUpdateTime,
    String? commentThreadId,
    int? playCount,
    int? trackNumberUpdateTime,
    int? subscribedCount,
    int? cloudTrackCount,
    bool? ordered,
    String? description,
    List<dynamic>? tags,
    dynamic updateFrequency,
    int? backgroundCoverId,
    dynamic backgroundCoverUrl,
    int? titleImage,
    dynamic titleImageUrl,
    dynamic englishTitle,
    dynamic officialPlaylistType,
    bool? copied,
    dynamic relateResType,
    List<dynamic>? subscribers,
    bool? subscribed,
    Creator? creator,
    List<Track>? tracks,
    dynamic videoIds,
    dynamic videos,
    List<TrackId>? trackIds,
    dynamic bannedTrackIds,
    dynamic mvResourceInfos,
    int? shareCount,
    int? commentCount,
    dynamic remixVideo,
    dynamic sharedUsers,
    dynamic historySharedUsers,
    String? gradeStatus,
    dynamic score,
    dynamic algTags,
    int? trialMode,
  }) =>
      Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        coverImgId: coverImgId ?? this.coverImgId,
        coverImgUrl: coverImgUrl ?? this.coverImgUrl,
        coverImgIdStr: coverImgIdStr ?? this.coverImgIdStr,
        adType: adType ?? this.adType,
        userId: userId ?? this.userId,
        createTime: createTime ?? this.createTime,
        status: status ?? this.status,
        opRecommend: opRecommend ?? this.opRecommend,
        highQuality: highQuality ?? this.highQuality,
        newImported: newImported ?? this.newImported,
        updateTime: updateTime ?? this.updateTime,
        trackCount: trackCount ?? this.trackCount,
        specialType: specialType ?? this.specialType,
        privacy: privacy ?? this.privacy,
        trackUpdateTime: trackUpdateTime ?? this.trackUpdateTime,
        commentThreadId: commentThreadId ?? this.commentThreadId,
        playCount: playCount ?? this.playCount,
        trackNumberUpdateTime: trackNumberUpdateTime ?? this.trackNumberUpdateTime,
        subscribedCount: subscribedCount ?? this.subscribedCount,
        cloudTrackCount: cloudTrackCount ?? this.cloudTrackCount,
        ordered: ordered ?? this.ordered,
        description: description ?? this.description,
        tags: tags ?? this.tags,
        updateFrequency: updateFrequency ?? this.updateFrequency,
        backgroundCoverId: backgroundCoverId ?? this.backgroundCoverId,
        backgroundCoverUrl: backgroundCoverUrl ?? this.backgroundCoverUrl,
        titleImage: titleImage ?? this.titleImage,
        titleImageUrl: titleImageUrl ?? this.titleImageUrl,
        englishTitle: englishTitle ?? this.englishTitle,
        officialPlaylistType: officialPlaylistType ?? this.officialPlaylistType,
        copied: copied ?? this.copied,
        relateResType: relateResType ?? this.relateResType,
        subscribers: subscribers ?? this.subscribers,
        subscribed: subscribed ?? this.subscribed,
        creator: creator ?? this.creator,
        tracks: tracks ?? this.tracks,
        videoIds: videoIds ?? this.videoIds,
        videos: videos ?? this.videos,
        trackIds: trackIds ?? this.trackIds,
        bannedTrackIds: bannedTrackIds ?? this.bannedTrackIds,
        mvResourceInfos: mvResourceInfos ?? this.mvResourceInfos,
        shareCount: shareCount ?? this.shareCount,
        commentCount: commentCount ?? this.commentCount,
        remixVideo: remixVideo ?? this.remixVideo,
        sharedUsers: sharedUsers ?? this.sharedUsers,
        historySharedUsers: historySharedUsers ?? this.historySharedUsers,
        gradeStatus: gradeStatus ?? this.gradeStatus,
        score: score ?? this.score,
        algTags: algTags ?? this.algTags,
        trialMode: trialMode ?? this.trialMode,
      );

  factory Playlist.fromRawJson(String str) => Playlist.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json["id"],
        name: json["name"],
        coverImgId: json["coverImgId"]?.toDouble(),
        coverImgUrl: json["coverImgUrl"],
        coverImgIdStr: json["coverImgId_str"],
        adType: json["adType"],
        userId: json["userId"],
        createTime: json["createTime"],
        status: json["status"],
        opRecommend: json["opRecommend"],
        highQuality: json["highQuality"],
        newImported: json["newImported"],
        updateTime: json["updateTime"],
        trackCount: json["trackCount"],
        specialType: json["specialType"],
        privacy: json["privacy"],
        trackUpdateTime: json["trackUpdateTime"],
        commentThreadId: json["commentThreadId"],
        playCount: json["playCount"],
        trackNumberUpdateTime: json["trackNumberUpdateTime"],
        subscribedCount: json["subscribedCount"],
        cloudTrackCount: json["cloudTrackCount"],
        ordered: json["ordered"],
        description: json["description"],
        tags: List<dynamic>.from(json["tags"].map((x) => x)),
        updateFrequency: json["updateFrequency"],
        backgroundCoverId: json["backgroundCoverId"],
        backgroundCoverUrl: json["backgroundCoverUrl"],
        titleImage: json["titleImage"],
        titleImageUrl: json["titleImageUrl"],
        englishTitle: json["englishTitle"],
        officialPlaylistType: json["officialPlaylistType"],
        copied: json["copied"],
        relateResType: json["relateResType"],
        subscribers: List<dynamic>.from(json["subscribers"].map((x) => x)),
        subscribed: json["subscribed"],
        creator: Creator.fromJson(json["creator"]),
        tracks: List<Track>.from(json["tracks"].map((x) => Track.fromJson(x))),
        videoIds: json["videoIds"],
        videos: json["videos"],
        trackIds: List<TrackId>.from(json["trackIds"].map((x) => TrackId.fromJson(x))),
        bannedTrackIds: json["bannedTrackIds"],
        mvResourceInfos: json["mvResourceInfos"],
        shareCount: json["shareCount"],
        commentCount: json["commentCount"],
        remixVideo: json["remixVideo"],
        sharedUsers: json["sharedUsers"],
        historySharedUsers: json["historySharedUsers"],
        gradeStatus: json["gradeStatus"],
        score: json["score"],
        algTags: json["algTags"],
        trialMode: json["trialMode"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "coverImgId": coverImgId,
        "coverImgUrl": coverImgUrl,
        "coverImgId_str": coverImgIdStr,
        "adType": adType,
        "userId": userId,
        "createTime": createTime,
        "status": status,
        "opRecommend": opRecommend,
        "highQuality": highQuality,
        "newImported": newImported,
        "updateTime": updateTime,
        "trackCount": trackCount,
        "specialType": specialType,
        "privacy": privacy,
        "trackUpdateTime": trackUpdateTime,
        "commentThreadId": commentThreadId,
        "playCount": playCount,
        "trackNumberUpdateTime": trackNumberUpdateTime,
        "subscribedCount": subscribedCount,
        "cloudTrackCount": cloudTrackCount,
        "ordered": ordered,
        "description": description,
        "tags": List<dynamic>.from(tags.map((x) => x)),
        "updateFrequency": updateFrequency,
        "backgroundCoverId": backgroundCoverId,
        "backgroundCoverUrl": backgroundCoverUrl,
        "titleImage": titleImage,
        "titleImageUrl": titleImageUrl,
        "englishTitle": englishTitle,
        "officialPlaylistType": officialPlaylistType,
        "copied": copied,
        "relateResType": relateResType,
        "subscribers": List<dynamic>.from(subscribers.map((x) => x)),
        "subscribed": subscribed,
        "creator": creator.toJson(),
        "tracks": List<dynamic>.from(tracks.map((x) => x.toJson())),
        "videoIds": videoIds,
        "videos": videos,
        "trackIds": List<dynamic>.from(trackIds.map((x) => x.toJson())),
        "bannedTrackIds": bannedTrackIds,
        "mvResourceInfos": mvResourceInfos,
        "shareCount": shareCount,
        "commentCount": commentCount,
        "remixVideo": remixVideo,
        "sharedUsers": sharedUsers,
        "historySharedUsers": historySharedUsers,
        "gradeStatus": gradeStatus,
        "score": score,
        "algTags": algTags,
        "trialMode": trialMode,
      };
}

class Creator {
  final bool defaultAvatar;
  final int province;
  final int authStatus;
  final bool followed;
  final String avatarUrl;
  final int accountStatus;
  final int gender;
  final int city;
  final int birthday;
  final int userId;
  final int userType;
  final String nickname;
  final String signature;
  final String description;
  final String detailDescription;
  final double avatarImgId;
  final int backgroundImgId;
  final String backgroundUrl;
  final int authority;
  final bool mutual;
  final dynamic expertTags;
  final dynamic experts;
  final int djStatus;
  final int vipType;
  final dynamic remarkName;
  final int authenticationTypes;
  final dynamic avatarDetail;
  final bool anchor;
  final String avatarImgIdStr;
  final String backgroundImgIdStr;
  final String creatorAvatarImgIdStr;

  Creator({
    required this.defaultAvatar,
    required this.province,
    required this.authStatus,
    required this.followed,
    required this.avatarUrl,
    required this.accountStatus,
    required this.gender,
    required this.city,
    required this.birthday,
    required this.userId,
    required this.userType,
    required this.nickname,
    required this.signature,
    required this.description,
    required this.detailDescription,
    required this.avatarImgId,
    required this.backgroundImgId,
    required this.backgroundUrl,
    required this.authority,
    required this.mutual,
    required this.expertTags,
    required this.experts,
    required this.djStatus,
    required this.vipType,
    required this.remarkName,
    required this.authenticationTypes,
    required this.avatarDetail,
    required this.anchor,
    required this.avatarImgIdStr,
    required this.backgroundImgIdStr,
    required this.creatorAvatarImgIdStr,
  });

  Creator copyWith({
    bool? defaultAvatar,
    int? province,
    int? authStatus,
    bool? followed,
    String? avatarUrl,
    int? accountStatus,
    int? gender,
    int? city,
    int? birthday,
    int? userId,
    int? userType,
    String? nickname,
    String? signature,
    String? description,
    String? detailDescription,
    double? avatarImgId,
    int? backgroundImgId,
    String? backgroundUrl,
    int? authority,
    bool? mutual,
    dynamic expertTags,
    dynamic experts,
    int? djStatus,
    int? vipType,
    dynamic remarkName,
    int? authenticationTypes,
    dynamic avatarDetail,
    bool? anchor,
    String? avatarImgIdStr,
    String? backgroundImgIdStr,
    String? creatorAvatarImgIdStr,
  }) =>
      Creator(
        defaultAvatar: defaultAvatar ?? this.defaultAvatar,
        province: province ?? this.province,
        authStatus: authStatus ?? this.authStatus,
        followed: followed ?? this.followed,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        accountStatus: accountStatus ?? this.accountStatus,
        gender: gender ?? this.gender,
        city: city ?? this.city,
        birthday: birthday ?? this.birthday,
        userId: userId ?? this.userId,
        userType: userType ?? this.userType,
        nickname: nickname ?? this.nickname,
        signature: signature ?? this.signature,
        description: description ?? this.description,
        detailDescription: detailDescription ?? this.detailDescription,
        avatarImgId: avatarImgId ?? this.avatarImgId,
        backgroundImgId: backgroundImgId ?? this.backgroundImgId,
        backgroundUrl: backgroundUrl ?? this.backgroundUrl,
        authority: authority ?? this.authority,
        mutual: mutual ?? this.mutual,
        expertTags: expertTags ?? this.expertTags,
        experts: experts ?? this.experts,
        djStatus: djStatus ?? this.djStatus,
        vipType: vipType ?? this.vipType,
        remarkName: remarkName ?? this.remarkName,
        authenticationTypes: authenticationTypes ?? this.authenticationTypes,
        avatarDetail: avatarDetail ?? this.avatarDetail,
        anchor: anchor ?? this.anchor,
        avatarImgIdStr: avatarImgIdStr ?? this.avatarImgIdStr,
        backgroundImgIdStr: backgroundImgIdStr ?? this.backgroundImgIdStr,
        creatorAvatarImgIdStr: creatorAvatarImgIdStr ?? this.creatorAvatarImgIdStr,
      );

  factory Creator.fromRawJson(String str) => Creator.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Creator.fromJson(Map<String, dynamic> json) => Creator(
        defaultAvatar: json["defaultAvatar"],
        province: json["province"],
        authStatus: json["authStatus"],
        followed: json["followed"],
        avatarUrl: json["avatarUrl"],
        accountStatus: json["accountStatus"],
        gender: json["gender"],
        city: json["city"],
        birthday: json["birthday"],
        userId: json["userId"],
        userType: json["userType"],
        nickname: json["nickname"],
        signature: json["signature"],
        description: json["description"],
        detailDescription: json["detailDescription"],
        avatarImgId: json["avatarImgId"]?.toDouble(),
        backgroundImgId: json["backgroundImgId"],
        backgroundUrl: json["backgroundUrl"],
        authority: json["authority"],
        mutual: json["mutual"],
        expertTags: json["expertTags"],
        experts: json["experts"],
        djStatus: json["djStatus"],
        vipType: json["vipType"],
        remarkName: json["remarkName"],
        authenticationTypes: json["authenticationTypes"],
        avatarDetail: json["avatarDetail"],
        anchor: json["anchor"],
        avatarImgIdStr: json["avatarImgIdStr"],
        backgroundImgIdStr: json["backgroundImgIdStr"],
        creatorAvatarImgIdStr: json["avatarImgId_str"],
      );

  Map<String, dynamic> toJson() => {
        "defaultAvatar": defaultAvatar,
        "province": province,
        "authStatus": authStatus,
        "followed": followed,
        "avatarUrl": avatarUrl,
        "accountStatus": accountStatus,
        "gender": gender,
        "city": city,
        "birthday": birthday,
        "userId": userId,
        "userType": userType,
        "nickname": nickname,
        "signature": signature,
        "description": description,
        "detailDescription": detailDescription,
        "avatarImgId": avatarImgId,
        "backgroundImgId": backgroundImgId,
        "backgroundUrl": backgroundUrl,
        "authority": authority,
        "mutual": mutual,
        "expertTags": expertTags,
        "experts": experts,
        "djStatus": djStatus,
        "vipType": vipType,
        "remarkName": remarkName,
        "authenticationTypes": authenticationTypes,
        "avatarDetail": avatarDetail,
        "anchor": anchor,
        "avatarImgIdStr": avatarImgIdStr,
        "backgroundImgIdStr": backgroundImgIdStr,
        "avatarImgId_str": creatorAvatarImgIdStr,
      };
}

class TrackId {
  final int id;
  final int v;
  final int t;
  final int at;
  final dynamic alg;
  final int uid;
  final String rcmdReason;
  final dynamic sc;
  final dynamic f;
  final dynamic sr;

  TrackId({
    required this.id,
    required this.v,
    required this.t,
    required this.at,
    required this.alg,
    required this.uid,
    required this.rcmdReason,
    required this.sc,
    required this.f,
    required this.sr,
  });

  TrackId copyWith({
    int? id,
    int? v,
    int? t,
    int? at,
    dynamic alg,
    int? uid,
    String? rcmdReason,
    dynamic sc,
    dynamic f,
    dynamic sr,
  }) =>
      TrackId(
        id: id ?? this.id,
        v: v ?? this.v,
        t: t ?? this.t,
        at: at ?? this.at,
        alg: alg ?? this.alg,
        uid: uid ?? this.uid,
        rcmdReason: rcmdReason ?? this.rcmdReason,
        sc: sc ?? this.sc,
        f: f ?? this.f,
        sr: sr ?? this.sr,
      );

  factory TrackId.fromRawJson(String str) => TrackId.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory TrackId.fromJson(Map<String, dynamic> json) => TrackId(
        id: json["id"],
        v: json["v"],
        t: json["t"],
        at: json["at"],
        alg: json["alg"],
        uid: json["uid"],
        rcmdReason: json["rcmdReason"],
        sc: json["sc"],
        f: json["f"],
        sr: json["sr"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "v": v,
        "t": t,
        "at": at,
        "alg": alg,
        "uid": uid,
        "rcmdReason": rcmdReason,
        "sc": sc,
        "f": f,
        "sr": sr,
      };
}

class Track {
  final String name;
  final int id;
  final int pst;
  final int t;
  final List<Ar> ar;
  final List<dynamic> alia;
  final int pop;
  final int st;
  final String? rt;
  final int fee;
  final int v;
  final dynamic crbt;
  final String cf;
  final Al al;
  final int dt;
  final H h;
  final H m;
  final H l;
  final H? sq;
  final H? hr;
  final dynamic a;
  final String cd;
  final int no;
  final dynamic rtUrl;
  final int ftype;
  final List<dynamic> rtUrls;
  final int djId;
  final int copyright;
  final int sId;
  final int mark;
  final int originCoverType;
  final OriginSongSimpleData? originSongSimpleData;
  final dynamic tagPicList;
  final bool resourceState;
  final int version;
  final dynamic songJumpInfo;
  final dynamic entertainmentTags;
  final dynamic awardTags;
  final int single;
  final dynamic noCopyrightRcmd;
  final int rtype;
  final dynamic rurl;
  final int mst;
  final int cp;
  final int mv;
  final int publishTime;
  final List<String>? tns;

  Track({
    required this.name,
    required this.id,
    required this.pst,
    required this.t,
    required this.ar,
    required this.alia,
    required this.pop,
    required this.st,
    required this.rt,
    required this.fee,
    required this.v,
    required this.crbt,
    required this.cf,
    required this.al,
    required this.dt,
    required this.h,
    required this.m,
    required this.l,
    required this.sq,
    required this.hr,
    required this.a,
    required this.cd,
    required this.no,
    required this.rtUrl,
    required this.ftype,
    required this.rtUrls,
    required this.djId,
    required this.copyright,
    required this.sId,
    required this.mark,
    required this.originCoverType,
    required this.originSongSimpleData,
    required this.tagPicList,
    required this.resourceState,
    required this.version,
    required this.songJumpInfo,
    required this.entertainmentTags,
    required this.awardTags,
    required this.single,
    required this.noCopyrightRcmd,
    required this.rtype,
    required this.rurl,
    required this.mst,
    required this.cp,
    required this.mv,
    required this.publishTime,
    this.tns,
  });

  Track copyWith({
    String? name,
    int? id,
    int? pst,
    int? t,
    List<Ar>? ar,
    List<dynamic>? alia,
    int? pop,
    int? st,
    String? rt,
    int? fee,
    int? v,
    dynamic crbt,
    String? cf,
    Al? al,
    int? dt,
    H? h,
    H? m,
    H? l,
    H? sq,
    H? hr,
    dynamic a,
    String? cd,
    int? no,
    dynamic rtUrl,
    int? ftype,
    List<dynamic>? rtUrls,
    int? djId,
    int? copyright,
    int? sId,
    int? mark,
    int? originCoverType,
    OriginSongSimpleData? originSongSimpleData,
    dynamic tagPicList,
    bool? resourceState,
    int? version,
    dynamic songJumpInfo,
    dynamic entertainmentTags,
    dynamic awardTags,
    int? single,
    dynamic noCopyrightRcmd,
    int? rtype,
    dynamic rurl,
    int? mst,
    int? cp,
    int? mv,
    int? publishTime,
    List<String>? tns,
  }) =>
      Track(
        name: name ?? this.name,
        id: id ?? this.id,
        pst: pst ?? this.pst,
        t: t ?? this.t,
        ar: ar ?? this.ar,
        alia: alia ?? this.alia,
        pop: pop ?? this.pop,
        st: st ?? this.st,
        rt: rt ?? this.rt,
        fee: fee ?? this.fee,
        v: v ?? this.v,
        crbt: crbt ?? this.crbt,
        cf: cf ?? this.cf,
        al: al ?? this.al,
        dt: dt ?? this.dt,
        h: h ?? this.h,
        m: m ?? this.m,
        l: l ?? this.l,
        sq: sq ?? this.sq,
        hr: hr ?? this.hr,
        a: a ?? this.a,
        cd: cd ?? this.cd,
        no: no ?? this.no,
        rtUrl: rtUrl ?? this.rtUrl,
        ftype: ftype ?? this.ftype,
        rtUrls: rtUrls ?? this.rtUrls,
        djId: djId ?? this.djId,
        copyright: copyright ?? this.copyright,
        sId: sId ?? this.sId,
        mark: mark ?? this.mark,
        originCoverType: originCoverType ?? this.originCoverType,
        originSongSimpleData: originSongSimpleData ?? this.originSongSimpleData,
        tagPicList: tagPicList ?? this.tagPicList,
        resourceState: resourceState ?? this.resourceState,
        version: version ?? this.version,
        songJumpInfo: songJumpInfo ?? this.songJumpInfo,
        entertainmentTags: entertainmentTags ?? this.entertainmentTags,
        awardTags: awardTags ?? this.awardTags,
        single: single ?? this.single,
        noCopyrightRcmd: noCopyrightRcmd ?? this.noCopyrightRcmd,
        rtype: rtype ?? this.rtype,
        rurl: rurl ?? this.rurl,
        mst: mst ?? this.mst,
        cp: cp ?? this.cp,
        mv: mv ?? this.mv,
        publishTime: publishTime ?? this.publishTime,
        tns: tns ?? this.tns,
      );

  factory Track.fromRawJson(String str) => Track.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        name: json["name"],
        id: json["id"],
        pst: json["pst"],
        t: json["t"],
        ar: List<Ar>.from(json["ar"].map((x) => Ar.fromJson(x))),
        alia: List<dynamic>.from(json["alia"].map((x) => x)),
        pop: json["pop"],
        st: json["st"],
        rt: json["rt"],
        fee: json["fee"],
        v: json["v"],
        crbt: json["crbt"],
        cf: json["cf"],
        al: Al.fromJson(json["al"]),
        dt: json["dt"],
        h: H.fromJson(json["h"]),
        m: H.fromJson(json["m"]),
        l: H.fromJson(json["l"]),
        sq: json["sq"] == null ? null : H.fromJson(json["sq"]),
        hr: json["hr"] == null ? null : H.fromJson(json["hr"]),
        a: json["a"],
        cd: json["cd"],
        no: json["no"],
        rtUrl: json["rtUrl"],
        ftype: json["ftype"],
        rtUrls: List<dynamic>.from(json["rtUrls"].map((x) => x)),
        djId: json["djId"],
        copyright: json["copyright"],
        sId: json["s_id"],
        mark: json["mark"],
        originCoverType: json["originCoverType"],
        originSongSimpleData:
            json["originSongSimpleData"] == null ? null : OriginSongSimpleData.fromJson(json["originSongSimpleData"]),
        tagPicList: json["tagPicList"],
        resourceState: json["resourceState"],
        version: json["version"],
        songJumpInfo: json["songJumpInfo"],
        entertainmentTags: json["entertainmentTags"],
        awardTags: json["awardTags"],
        single: json["single"],
        noCopyrightRcmd: json["noCopyrightRcmd"],
        rtype: json["rtype"],
        rurl: json["rurl"],
        mst: json["mst"],
        cp: json["cp"],
        mv: json["mv"],
        publishTime: json["publishTime"],
        tns: json["tns"] == null ? [] : List<String>.from(json["tns"]!.map((x) => x)),
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "id": id,
        "pst": pst,
        "t": t,
        "ar": List<dynamic>.from(ar.map((x) => x.toJson())),
        "alia": List<dynamic>.from(alia.map((x) => x)),
        "pop": pop,
        "st": st,
        "rt": rt,
        "fee": fee,
        "v": v,
        "crbt": crbt,
        "cf": cf,
        "al": al.toJson(),
        "dt": dt,
        "h": h.toJson(),
        "m": m.toJson(),
        "l": l.toJson(),
        "sq": sq?.toJson(),
        "hr": hr?.toJson(),
        "a": a,
        "cd": cd,
        "no": no,
        "rtUrl": rtUrl,
        "ftype": ftype,
        "rtUrls": List<dynamic>.from(rtUrls.map((x) => x)),
        "djId": djId,
        "copyright": copyright,
        "s_id": sId,
        "mark": mark,
        "originCoverType": originCoverType,
        "originSongSimpleData": originSongSimpleData?.toJson(),
        "tagPicList": tagPicList,
        "resourceState": resourceState,
        "version": version,
        "songJumpInfo": songJumpInfo,
        "entertainmentTags": entertainmentTags,
        "awardTags": awardTags,
        "single": single,
        "noCopyrightRcmd": noCopyrightRcmd,
        "rtype": rtype,
        "rurl": rurl,
        "mst": mst,
        "cp": cp,
        "mv": mv,
        "publishTime": publishTime,
        "tns": tns == null ? [] : List<dynamic>.from(tns!.map((x) => x)),
      };
}

class Al {
  final int id;
  final String name;
  final String picUrl;
  final List<String> tns;
  final String picStr;
  final double pic;

  Al({
    required this.id,
    required this.name,
    required this.picUrl,
    required this.tns,
    required this.picStr,
    required this.pic,
  });

  Al copyWith({
    int? id,
    String? name,
    String? picUrl,
    List<String>? tns,
    String? picStr,
    double? pic,
  }) =>
      Al(
        id: id ?? this.id,
        name: name ?? this.name,
        picUrl: picUrl ?? this.picUrl,
        tns: tns ?? this.tns,
        picStr: picStr ?? this.picStr,
        pic: pic ?? this.pic,
      );

  factory Al.fromRawJson(String str) => Al.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Al.fromJson(Map<String, dynamic> json) => Al(
        id: json["id"],
        name: json["name"],
        picUrl: json["picUrl"],
        tns: List<String>.from(json["tns"].map((x) => x)),
        picStr: json["pic_str"],
        pic: json["pic"]?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "picUrl": picUrl,
        "tns": List<dynamic>.from(tns.map((x) => x)),
        "pic_str": picStr,
        "pic": pic,
      };
}

class Ar {
  final int id;
  final String name;
  final List<dynamic> tns;
  final List<dynamic> alias;

  Ar({
    required this.id,
    required this.name,
    required this.tns,
    required this.alias,
  });

  Ar copyWith({
    int? id,
    String? name,
    List<dynamic>? tns,
    List<dynamic>? alias,
  }) =>
      Ar(
        id: id ?? this.id,
        name: name ?? this.name,
        tns: tns ?? this.tns,
        alias: alias ?? this.alias,
      );

  factory Ar.fromRawJson(String str) => Ar.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Ar.fromJson(Map<String, dynamic> json) => Ar(
        id: json["id"],
        name: json["name"],
        tns: List<dynamic>.from(json["tns"].map((x) => x)),
        alias: List<dynamic>.from(json["alias"].map((x) => x)),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "tns": List<dynamic>.from(tns.map((x) => x)),
        "alias": List<dynamic>.from(alias.map((x) => x)),
      };
}

class H {
  final int br;
  final int fid;
  final int size;
  final int vd;
  final int sr;

  H({
    required this.br,
    required this.fid,
    required this.size,
    required this.vd,
    required this.sr,
  });

  H copyWith({
    int? br,
    int? fid,
    int? size,
    int? vd,
    int? sr,
  }) =>
      H(
        br: br ?? this.br,
        fid: fid ?? this.fid,
        size: size ?? this.size,
        vd: vd ?? this.vd,
        sr: sr ?? this.sr,
      );

  factory H.fromRawJson(String str) => H.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory H.fromJson(Map<String, dynamic> json) => H(
        br: json["br"],
        fid: json["fid"],
        size: json["size"],
        vd: json["vd"],
        sr: json["sr"],
      );

  Map<String, dynamic> toJson() => {
        "br": br,
        "fid": fid,
        "size": size,
        "vd": vd,
        "sr": sr,
      };
}

class OriginSongSimpleData {
  final int songId;
  final String name;
  final List<AlbumMeta> artists;
  final AlbumMeta albumMeta;

  OriginSongSimpleData({
    required this.songId,
    required this.name,
    required this.artists,
    required this.albumMeta,
  });

  OriginSongSimpleData copyWith({
    int? songId,
    String? name,
    List<AlbumMeta>? artists,
    AlbumMeta? albumMeta,
  }) =>
      OriginSongSimpleData(
        songId: songId ?? this.songId,
        name: name ?? this.name,
        artists: artists ?? this.artists,
        albumMeta: albumMeta ?? this.albumMeta,
      );

  factory OriginSongSimpleData.fromRawJson(String str) => OriginSongSimpleData.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory OriginSongSimpleData.fromJson(Map<String, dynamic> json) => OriginSongSimpleData(
        songId: json["songId"],
        name: json["name"],
        artists: List<AlbumMeta>.from(json["artists"].map((x) => AlbumMeta.fromJson(x))),
        albumMeta: AlbumMeta.fromJson(json["albumMeta"]),
      );

  Map<String, dynamic> toJson() => {
        "songId": songId,
        "name": name,
        "artists": List<dynamic>.from(artists.map((x) => x.toJson())),
        "albumMeta": albumMeta.toJson(),
      };
}

class AlbumMeta {
  final int id;
  final String name;

  AlbumMeta({
    required this.id,
    required this.name,
  });

  AlbumMeta copyWith({
    int? id,
    String? name,
  }) =>
      AlbumMeta(
        id: id ?? this.id,
        name: name ?? this.name,
      );

  factory AlbumMeta.fromRawJson(String str) => AlbumMeta.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory AlbumMeta.fromJson(Map<String, dynamic> json) => AlbumMeta(
        id: json["id"],
        name: json["name"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
      };
}

class Privilege {
  final int id;
  final int fee;
  final int payed;
  final int realPayed;
  final int st;
  final int pl;
  final int dl;
  final int sp;
  final int cp;
  final int subp;
  final bool cs;
  final int maxbr;
  final int fl;
  final dynamic pc;
  final bool toast;
  final int flag;
  final bool paidBigBang;
  final bool preSell;
  final int playMaxbr;
  final int downloadMaxbr;
  final Level maxBrLevel;
  final Level playMaxBrLevel;
  final Level downloadMaxBrLevel;
  final Level plLevel;
  final Level dlLevel;
  final FlLevel flLevel;
  final dynamic rscl;
  final FreeTrialPrivilege freeTrialPrivilege;
  final int rightSource;
  final List<ChargeInfoList> chargeInfoList;

  Privilege({
    required this.id,
    required this.fee,
    required this.payed,
    required this.realPayed,
    required this.st,
    required this.pl,
    required this.dl,
    required this.sp,
    required this.cp,
    required this.subp,
    required this.cs,
    required this.maxbr,
    required this.fl,
    required this.pc,
    required this.toast,
    required this.flag,
    required this.paidBigBang,
    required this.preSell,
    required this.playMaxbr,
    required this.downloadMaxbr,
    required this.maxBrLevel,
    required this.playMaxBrLevel,
    required this.downloadMaxBrLevel,
    required this.plLevel,
    required this.dlLevel,
    required this.flLevel,
    required this.rscl,
    required this.freeTrialPrivilege,
    required this.rightSource,
    required this.chargeInfoList,
  });

  Privilege copyWith({
    int? id,
    int? fee,
    int? payed,
    int? realPayed,
    int? st,
    int? pl,
    int? dl,
    int? sp,
    int? cp,
    int? subp,
    bool? cs,
    int? maxbr,
    int? fl,
    dynamic pc,
    bool? toast,
    int? flag,
    bool? paidBigBang,
    bool? preSell,
    int? playMaxbr,
    int? downloadMaxbr,
    Level? maxBrLevel,
    Level? playMaxBrLevel,
    Level? downloadMaxBrLevel,
    Level? plLevel,
    Level? dlLevel,
    FlLevel? flLevel,
    dynamic rscl,
    FreeTrialPrivilege? freeTrialPrivilege,
    int? rightSource,
    List<ChargeInfoList>? chargeInfoList,
  }) =>
      Privilege(
        id: id ?? this.id,
        fee: fee ?? this.fee,
        payed: payed ?? this.payed,
        realPayed: realPayed ?? this.realPayed,
        st: st ?? this.st,
        pl: pl ?? this.pl,
        dl: dl ?? this.dl,
        sp: sp ?? this.sp,
        cp: cp ?? this.cp,
        subp: subp ?? this.subp,
        cs: cs ?? this.cs,
        maxbr: maxbr ?? this.maxbr,
        fl: fl ?? this.fl,
        pc: pc ?? this.pc,
        toast: toast ?? this.toast,
        flag: flag ?? this.flag,
        paidBigBang: paidBigBang ?? this.paidBigBang,
        preSell: preSell ?? this.preSell,
        playMaxbr: playMaxbr ?? this.playMaxbr,
        downloadMaxbr: downloadMaxbr ?? this.downloadMaxbr,
        maxBrLevel: maxBrLevel ?? this.maxBrLevel,
        playMaxBrLevel: playMaxBrLevel ?? this.playMaxBrLevel,
        downloadMaxBrLevel: downloadMaxBrLevel ?? this.downloadMaxBrLevel,
        plLevel: plLevel ?? this.plLevel,
        dlLevel: dlLevel ?? this.dlLevel,
        flLevel: flLevel ?? this.flLevel,
        rscl: rscl ?? this.rscl,
        freeTrialPrivilege: freeTrialPrivilege ?? this.freeTrialPrivilege,
        rightSource: rightSource ?? this.rightSource,
        chargeInfoList: chargeInfoList ?? this.chargeInfoList,
      );

  factory Privilege.fromRawJson(String str) => Privilege.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Privilege.fromJson(Map<String, dynamic> json) => Privilege(
        id: json["id"],
        fee: json["fee"],
        payed: json["payed"],
        realPayed: json["realPayed"],
        st: json["st"],
        pl: json["pl"],
        dl: json["dl"],
        sp: json["sp"],
        cp: json["cp"],
        subp: json["subp"],
        cs: json["cs"],
        maxbr: json["maxbr"],
        fl: json["fl"],
        pc: json["pc"],
        toast: json["toast"],
        flag: json["flag"],
        paidBigBang: json["paidBigBang"],
        preSell: json["preSell"],
        playMaxbr: json["playMaxbr"],
        downloadMaxbr: json["downloadMaxbr"],
        maxBrLevel: levelValues.map[json["maxBrLevel"]]!,
        playMaxBrLevel: levelValues.map[json["playMaxBrLevel"]]!,
        downloadMaxBrLevel: levelValues.map[json["downloadMaxBrLevel"]]!,
        plLevel: levelValues.map[json["plLevel"]]!,
        dlLevel: levelValues.map[json["dlLevel"]]!,
        flLevel: flLevelValues.map[json["flLevel"]]!,
        rscl: json["rscl"],
        freeTrialPrivilege: FreeTrialPrivilege.fromJson(json["freeTrialPrivilege"]),
        rightSource: json["rightSource"],
        chargeInfoList: List<ChargeInfoList>.from(json["chargeInfoList"].map((x) => ChargeInfoList.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "fee": fee,
        "payed": payed,
        "realPayed": realPayed,
        "st": st,
        "pl": pl,
        "dl": dl,
        "sp": sp,
        "cp": cp,
        "subp": subp,
        "cs": cs,
        "maxbr": maxbr,
        "fl": fl,
        "pc": pc,
        "toast": toast,
        "flag": flag,
        "paidBigBang": paidBigBang,
        "preSell": preSell,
        "playMaxbr": playMaxbr,
        "downloadMaxbr": downloadMaxbr,
        "maxBrLevel": levelValues.reverse[maxBrLevel],
        "playMaxBrLevel": levelValues.reverse[playMaxBrLevel],
        "downloadMaxBrLevel": levelValues.reverse[downloadMaxBrLevel],
        "plLevel": levelValues.reverse[plLevel],
        "dlLevel": levelValues.reverse[dlLevel],
        "flLevel": flLevelValues.reverse[flLevel],
        "rscl": rscl,
        "freeTrialPrivilege": freeTrialPrivilege.toJson(),
        "rightSource": rightSource,
        "chargeInfoList": List<dynamic>.from(chargeInfoList.map((x) => x.toJson())),
      };
}

class ChargeInfoList {
  final int rate;
  final dynamic chargeUrl;
  final dynamic chargeMessage;
  final int chargeType;

  ChargeInfoList({
    required this.rate,
    required this.chargeUrl,
    required this.chargeMessage,
    required this.chargeType,
  });

  ChargeInfoList copyWith({
    int? rate,
    dynamic chargeUrl,
    dynamic chargeMessage,
    int? chargeType,
  }) =>
      ChargeInfoList(
        rate: rate ?? this.rate,
        chargeUrl: chargeUrl ?? this.chargeUrl,
        chargeMessage: chargeMessage ?? this.chargeMessage,
        chargeType: chargeType ?? this.chargeType,
      );

  factory ChargeInfoList.fromRawJson(String str) => ChargeInfoList.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ChargeInfoList.fromJson(Map<String, dynamic> json) => ChargeInfoList(
        rate: json["rate"],
        chargeUrl: json["chargeUrl"],
        chargeMessage: json["chargeMessage"],
        chargeType: json["chargeType"],
      );

  Map<String, dynamic> toJson() => {
        "rate": rate,
        "chargeUrl": chargeUrl,
        "chargeMessage": chargeMessage,
        "chargeType": chargeType,
      };
}

enum Level { EXHIGH, HIRES, LOSSLESS }

final levelValues = EnumValues({"exhigh": Level.EXHIGH, "hires": Level.HIRES, "lossless": Level.LOSSLESS});

enum FlLevel { EXHIGH, NONE, STANDARD }

final flLevelValues = EnumValues({"exhigh": FlLevel.EXHIGH, "none": FlLevel.NONE, "standard": FlLevel.STANDARD});

class FreeTrialPrivilege {
  final bool resConsumable;
  final bool userConsumable;
  final dynamic listenType;
  final dynamic cannotListenReason;

  FreeTrialPrivilege({
    required this.resConsumable,
    required this.userConsumable,
    required this.listenType,
    required this.cannotListenReason,
  });

  FreeTrialPrivilege copyWith({
    bool? resConsumable,
    bool? userConsumable,
    dynamic listenType,
    dynamic cannotListenReason,
  }) =>
      FreeTrialPrivilege(
        resConsumable: resConsumable ?? this.resConsumable,
        userConsumable: userConsumable ?? this.userConsumable,
        listenType: listenType ?? this.listenType,
        cannotListenReason: cannotListenReason ?? this.cannotListenReason,
      );

  factory FreeTrialPrivilege.fromRawJson(String str) => FreeTrialPrivilege.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory FreeTrialPrivilege.fromJson(Map<String, dynamic> json) => FreeTrialPrivilege(
        resConsumable: json["resConsumable"],
        userConsumable: json["userConsumable"],
        listenType: json["listenType"],
        cannotListenReason: json["cannotListenReason"],
      );

  Map<String, dynamic> toJson() => {
        "resConsumable": resConsumable,
        "userConsumable": userConsumable,
        "listenType": listenType,
        "cannotListenReason": cannotListenReason,
      };
}

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
