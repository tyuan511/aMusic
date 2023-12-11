import 'dart:convert';

class PlaylistDetailRes {
  final int? code;
  final dynamic relatedVideos;
  final Playlist? playlist;
  final dynamic urls;
  final List<Privilege>? privileges;
  final dynamic sharedPrivilege;
  final dynamic resEntrance;
  final dynamic fromUsers;
  final int? fromUserCount;
  final dynamic songFromUsers;

  PlaylistDetailRes({
    this.code,
    this.relatedVideos,
    this.playlist,
    this.urls,
    this.privileges,
    this.sharedPrivilege,
    this.resEntrance,
    this.fromUsers,
    this.fromUserCount,
    this.songFromUsers,
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
        playlist: json["playlist"] == null ? null : Playlist.fromJson(json["playlist"]),
        urls: json["urls"],
        privileges: json["privileges"] == null
            ? []
            : List<Privilege>.from(json["privileges"]!.map((x) => Privilege.fromJson(x))),
        sharedPrivilege: json["sharedPrivilege"],
        resEntrance: json["resEntrance"],
        fromUsers: json["fromUsers"],
        fromUserCount: json["fromUserCount"],
        songFromUsers: json["songFromUsers"],
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "relatedVideos": relatedVideos,
        "playlist": playlist?.toJson(),
        "urls": urls,
        "privileges": privileges == null ? [] : List<dynamic>.from(privileges!.map((x) => x.toJson())),
        "sharedPrivilege": sharedPrivilege,
        "resEntrance": resEntrance,
        "fromUsers": fromUsers,
        "fromUserCount": fromUserCount,
        "songFromUsers": songFromUsers,
      };
}

class Playlist {
  final int? id;
  final String? name;
  final double? coverImgId;
  final String? coverImgUrl;
  final String? coverImgIdStr;
  final int? adType;
  final int? userId;
  final int? createTime;
  final int? status;
  final bool? opRecommend;
  final bool? highQuality;
  final bool? newImported;
  final int? updateTime;
  final int? trackCount;
  final int? specialType;
  final int? privacy;
  final int? trackUpdateTime;
  final String? commentThreadId;
  final int? playCount;
  final int? trackNumberUpdateTime;
  final int? subscribedCount;
  final int? cloudTrackCount;
  final bool? ordered;
  final String? description;
  final List<String>? tags;
  final dynamic updateFrequency;
  final int? backgroundCoverId;
  final dynamic backgroundCoverUrl;
  final int? titleImage;
  final dynamic titleImageUrl;
  final dynamic englishTitle;
  final dynamic officialPlaylistType;
  final bool? copied;
  final dynamic relateResType;
  final List<Creator>? subscribers;
  final dynamic subscribed;
  final Creator? creator;
  final List<Track>? tracks;
  final dynamic videoIds;
  final dynamic videos;
  final List<TrackId>? trackIds;
  final dynamic bannedTrackIds;
  final dynamic mvResourceInfos;
  final int? shareCount;
  final int? commentCount;
  final dynamic remixVideo;
  final dynamic sharedUsers;
  final dynamic historySharedUsers;
  final String? gradeStatus;
  final dynamic score;
  final dynamic algTags;
  final int? trialMode;

  Playlist({
    this.id,
    this.name,
    this.coverImgId,
    this.coverImgUrl,
    this.coverImgIdStr,
    this.adType,
    this.userId,
    this.createTime,
    this.status,
    this.opRecommend,
    this.highQuality,
    this.newImported,
    this.updateTime,
    this.trackCount,
    this.specialType,
    this.privacy,
    this.trackUpdateTime,
    this.commentThreadId,
    this.playCount,
    this.trackNumberUpdateTime,
    this.subscribedCount,
    this.cloudTrackCount,
    this.ordered,
    this.description,
    this.tags,
    this.updateFrequency,
    this.backgroundCoverId,
    this.backgroundCoverUrl,
    this.titleImage,
    this.titleImageUrl,
    this.englishTitle,
    this.officialPlaylistType,
    this.copied,
    this.relateResType,
    this.subscribers,
    this.subscribed,
    this.creator,
    this.tracks,
    this.videoIds,
    this.videos,
    this.trackIds,
    this.bannedTrackIds,
    this.mvResourceInfos,
    this.shareCount,
    this.commentCount,
    this.remixVideo,
    this.sharedUsers,
    this.historySharedUsers,
    this.gradeStatus,
    this.score,
    this.algTags,
    this.trialMode,
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
    List<String>? tags,
    dynamic updateFrequency,
    int? backgroundCoverId,
    dynamic backgroundCoverUrl,
    int? titleImage,
    dynamic titleImageUrl,
    dynamic englishTitle,
    dynamic officialPlaylistType,
    bool? copied,
    dynamic relateResType,
    List<Creator>? subscribers,
    dynamic subscribed,
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
        tags: json["tags"] == null ? [] : List<String>.from(json["tags"]!.map((x) => x)),
        updateFrequency: json["updateFrequency"],
        backgroundCoverId: json["backgroundCoverId"],
        backgroundCoverUrl: json["backgroundCoverUrl"],
        titleImage: json["titleImage"],
        titleImageUrl: json["titleImageUrl"],
        englishTitle: json["englishTitle"],
        officialPlaylistType: json["officialPlaylistType"],
        copied: json["copied"],
        relateResType: json["relateResType"],
        subscribers:
            json["subscribers"] == null ? [] : List<Creator>.from(json["subscribers"]!.map((x) => Creator.fromJson(x))),
        subscribed: json["subscribed"],
        creator: json["creator"] == null ? null : Creator.fromJson(json["creator"]),
        tracks: json["tracks"] == null ? [] : List<Track>.from(json["tracks"]!.map((x) => Track.fromJson(x))),
        videoIds: json["videoIds"],
        videos: json["videos"],
        trackIds: json["trackIds"] == null ? [] : List<TrackId>.from(json["trackIds"]!.map((x) => TrackId.fromJson(x))),
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
        "tags": tags == null ? [] : List<dynamic>.from(tags!.map((x) => x)),
        "updateFrequency": updateFrequency,
        "backgroundCoverId": backgroundCoverId,
        "backgroundCoverUrl": backgroundCoverUrl,
        "titleImage": titleImage,
        "titleImageUrl": titleImageUrl,
        "englishTitle": englishTitle,
        "officialPlaylistType": officialPlaylistType,
        "copied": copied,
        "relateResType": relateResType,
        "subscribers": subscribers == null ? [] : List<dynamic>.from(subscribers!.map((x) => x.toJson())),
        "subscribed": subscribed,
        "creator": creator?.toJson(),
        "tracks": tracks == null ? [] : List<dynamic>.from(tracks!.map((x) => x.toJson())),
        "videoIds": videoIds,
        "videos": videos,
        "trackIds": trackIds == null ? [] : List<dynamic>.from(trackIds!.map((x) => x.toJson())),
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
  final bool? defaultAvatar;
  final int? province;
  final int? authStatus;
  final bool? followed;
  final String? avatarUrl;
  final int? accountStatus;
  final int? gender;
  final int? city;
  final int? birthday;
  final int? userId;
  final int? userType;
  final String? nickname;
  final String? signature;
  final String? description;
  final String? detailDescription;
  final double? avatarImgId;
  final double? backgroundImgId;
  final String? backgroundUrl;
  final int? authority;
  final bool? mutual;
  final dynamic expertTags;
  final dynamic experts;
  final int? djStatus;
  final int? vipType;
  final dynamic remarkName;
  final int? authenticationTypes;
  final dynamic avatarDetail;
  final String? avatarImgIdStr;
  final String? backgroundImgIdStr;
  final bool? anchor;
  final String? creatorAvatarImgIdStr;

  Creator({
    this.defaultAvatar,
    this.province,
    this.authStatus,
    this.followed,
    this.avatarUrl,
    this.accountStatus,
    this.gender,
    this.city,
    this.birthday,
    this.userId,
    this.userType,
    this.nickname,
    this.signature,
    this.description,
    this.detailDescription,
    this.avatarImgId,
    this.backgroundImgId,
    this.backgroundUrl,
    this.authority,
    this.mutual,
    this.expertTags,
    this.experts,
    this.djStatus,
    this.vipType,
    this.remarkName,
    this.authenticationTypes,
    this.avatarDetail,
    this.avatarImgIdStr,
    this.backgroundImgIdStr,
    this.anchor,
    this.creatorAvatarImgIdStr,
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
    double? backgroundImgId,
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
    String? avatarImgIdStr,
    String? backgroundImgIdStr,
    bool? anchor,
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
        avatarImgIdStr: avatarImgIdStr ?? this.avatarImgIdStr,
        backgroundImgIdStr: backgroundImgIdStr ?? this.backgroundImgIdStr,
        anchor: anchor ?? this.anchor,
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
        backgroundImgId: json["backgroundImgId"]?.toDouble(),
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
        avatarImgIdStr: json["avatarImgIdStr"],
        backgroundImgIdStr: json["backgroundImgIdStr"],
        anchor: json["anchor"],
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
        "avatarImgIdStr": avatarImgIdStr,
        "backgroundImgIdStr": backgroundImgIdStr,
        "anchor": anchor,
        "avatarImgId_str": creatorAvatarImgIdStr,
      };
}

class TrackId {
  final int? id;
  final int? v;
  final int? t;
  final int? at;
  final dynamic alg;
  final int? uid;
  final String? rcmdReason;
  final dynamic sc;
  final dynamic f;
  final dynamic sr;

  TrackId({
    this.id,
    this.v,
    this.t,
    this.at,
    this.alg,
    this.uid,
    this.rcmdReason,
    this.sc,
    this.f,
    this.sr,
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
  final String? name;
  final int? id;
  final int? pst;
  final int? t;
  final List<Ar>? ar;
  final List<dynamic>? alia;
  final int? pop;
  final int? st;
  final String? rt;
  final int? fee;
  final int? v;
  final dynamic crbt;
  final String? cf;
  final Al? al;
  final int? dt;
  final H? h;
  final H? m;
  final H? l;
  final H? sq;
  final H? hr;
  final dynamic a;
  final String? cd;
  final int? no;
  final dynamic rtUrl;
  final int? ftype;
  final List<dynamic>? rtUrls;
  final int? djId;
  final int? copyright;
  final int? sId;
  final int? mark;
  final int? originCoverType;
  final dynamic originSongSimpleData;
  final dynamic tagPicList;
  final bool? resourceState;
  final int? version;
  final dynamic songJumpInfo;
  final dynamic entertainmentTags;
  final dynamic awardTags;
  final int? single;
  final dynamic noCopyrightRcmd;
  final int? rtype;
  final dynamic rurl;
  final int? mst;
  final int? cp;
  final int? mv;
  final int? publishTime;

  Track({
    this.name,
    this.id,
    this.pst,
    this.t,
    this.ar,
    this.alia,
    this.pop,
    this.st,
    this.rt,
    this.fee,
    this.v,
    this.crbt,
    this.cf,
    this.al,
    this.dt,
    this.h,
    this.m,
    this.l,
    this.sq,
    this.hr,
    this.a,
    this.cd,
    this.no,
    this.rtUrl,
    this.ftype,
    this.rtUrls,
    this.djId,
    this.copyright,
    this.sId,
    this.mark,
    this.originCoverType,
    this.originSongSimpleData,
    this.tagPicList,
    this.resourceState,
    this.version,
    this.songJumpInfo,
    this.entertainmentTags,
    this.awardTags,
    this.single,
    this.noCopyrightRcmd,
    this.rtype,
    this.rurl,
    this.mst,
    this.cp,
    this.mv,
    this.publishTime,
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
    dynamic originSongSimpleData,
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
      );

  factory Track.fromRawJson(String str) => Track.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        name: json["name"],
        id: json["id"],
        pst: json["pst"],
        t: json["t"],
        ar: json["ar"] == null ? [] : List<Ar>.from(json["ar"]!.map((x) => Ar.fromJson(x))),
        alia: json["alia"] == null ? [] : List<dynamic>.from(json["alia"]!.map((x) => x)),
        pop: json["pop"],
        st: json["st"],
        rt: json["rt"],
        fee: json["fee"],
        v: json["v"],
        crbt: json["crbt"],
        cf: json["cf"],
        al: json["al"] == null ? null : Al.fromJson(json["al"]),
        dt: json["dt"],
        h: json["h"] == null ? null : H.fromJson(json["h"]),
        m: json["m"] == null ? null : H.fromJson(json["m"]),
        l: json["l"] == null ? null : H.fromJson(json["l"]),
        sq: json["sq"] == null ? null : H.fromJson(json["sq"]),
        hr: json["hr"] == null ? null : H.fromJson(json["hr"]),
        a: json["a"],
        cd: json["cd"],
        no: json["no"],
        rtUrl: json["rtUrl"],
        ftype: json["ftype"],
        rtUrls: json["rtUrls"] == null ? [] : List<dynamic>.from(json["rtUrls"]!.map((x) => x)),
        djId: json["djId"],
        copyright: json["copyright"],
        sId: json["s_id"],
        mark: json["mark"],
        originCoverType: json["originCoverType"],
        originSongSimpleData: json["originSongSimpleData"],
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
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "id": id,
        "pst": pst,
        "t": t,
        "ar": ar == null ? [] : List<dynamic>.from(ar!.map((x) => x.toJson())),
        "alia": alia == null ? [] : List<dynamic>.from(alia!.map((x) => x)),
        "pop": pop,
        "st": st,
        "rt": rt,
        "fee": fee,
        "v": v,
        "crbt": crbt,
        "cf": cf,
        "al": al?.toJson(),
        "dt": dt,
        "h": h?.toJson(),
        "m": m?.toJson(),
        "l": l?.toJson(),
        "sq": sq?.toJson(),
        "hr": hr?.toJson(),
        "a": a,
        "cd": cd,
        "no": no,
        "rtUrl": rtUrl,
        "ftype": ftype,
        "rtUrls": rtUrls == null ? [] : List<dynamic>.from(rtUrls!.map((x) => x)),
        "djId": djId,
        "copyright": copyright,
        "s_id": sId,
        "mark": mark,
        "originCoverType": originCoverType,
        "originSongSimpleData": originSongSimpleData,
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
      };
}

class Al {
  final int? id;
  final String? name;
  final String? picUrl;
  final List<dynamic>? tns;
  final String? picStr;
  final double? pic;

  Al({
    this.id,
    this.name,
    this.picUrl,
    this.tns,
    this.picStr,
    this.pic,
  });

  Al copyWith({
    int? id,
    String? name,
    String? picUrl,
    List<dynamic>? tns,
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
        tns: json["tns"] == null ? [] : List<dynamic>.from(json["tns"]!.map((x) => x)),
        picStr: json["pic_str"],
        pic: json["pic"]?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "picUrl": picUrl,
        "tns": tns == null ? [] : List<dynamic>.from(tns!.map((x) => x)),
        "pic_str": picStr,
        "pic": pic,
      };
}

class Ar {
  final int? id;
  final String? name;
  final List<dynamic>? tns;
  final List<dynamic>? alias;

  Ar({
    this.id,
    this.name,
    this.tns,
    this.alias,
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
        tns: json["tns"] == null ? [] : List<dynamic>.from(json["tns"]!.map((x) => x)),
        alias: json["alias"] == null ? [] : List<dynamic>.from(json["alias"]!.map((x) => x)),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "tns": tns == null ? [] : List<dynamic>.from(tns!.map((x) => x)),
        "alias": alias == null ? [] : List<dynamic>.from(alias!.map((x) => x)),
      };
}

class H {
  final int? br;
  final int? fid;
  final int? size;
  final int? vd;
  final int? sr;

  H({
    this.br,
    this.fid,
    this.size,
    this.vd,
    this.sr,
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

class Privilege {
  final int? id;
  final int? fee;
  final int? payed;
  final int? realPayed;
  final int? st;
  final int? pl;
  final int? dl;
  final int? sp;
  final int? cp;
  final int? subp;
  final bool? cs;
  final int? maxbr;
  final int? fl;
  final dynamic pc;
  final bool? toast;
  final int? flag;
  final bool? paidBigBang;
  final bool? preSell;
  final int? playMaxbr;
  final int? downloadMaxbr;
  final String? maxBrLevel;
  final String? playMaxBrLevel;
  final String? downloadMaxBrLevel;
  final String? plLevel;
  final String? dlLevel;
  final String? flLevel;
  final int? rscl;
  final FreeTrialPrivilege? freeTrialPrivilege;
  final int? rightSource;
  final List<ChargeInfoList>? chargeInfoList;

  Privilege({
    this.id,
    this.fee,
    this.payed,
    this.realPayed,
    this.st,
    this.pl,
    this.dl,
    this.sp,
    this.cp,
    this.subp,
    this.cs,
    this.maxbr,
    this.fl,
    this.pc,
    this.toast,
    this.flag,
    this.paidBigBang,
    this.preSell,
    this.playMaxbr,
    this.downloadMaxbr,
    this.maxBrLevel,
    this.playMaxBrLevel,
    this.downloadMaxBrLevel,
    this.plLevel,
    this.dlLevel,
    this.flLevel,
    this.rscl,
    this.freeTrialPrivilege,
    this.rightSource,
    this.chargeInfoList,
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
    String? maxBrLevel,
    String? playMaxBrLevel,
    String? downloadMaxBrLevel,
    String? plLevel,
    String? dlLevel,
    String? flLevel,
    int? rscl,
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
        maxBrLevel: json["maxBrLevel"],
        playMaxBrLevel: json["playMaxBrLevel"],
        downloadMaxBrLevel: json["downloadMaxBrLevel"],
        plLevel: json["plLevel"],
        dlLevel: json["dlLevel"],
        flLevel: json["flLevel"],
        rscl: json["rscl"],
        freeTrialPrivilege:
            json["freeTrialPrivilege"] == null ? null : FreeTrialPrivilege.fromJson(json["freeTrialPrivilege"]),
        rightSource: json["rightSource"],
        chargeInfoList: json["chargeInfoList"] == null
            ? []
            : List<ChargeInfoList>.from(json["chargeInfoList"]!.map((x) => ChargeInfoList.fromJson(x))),
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
        "maxBrLevel": maxBrLevel,
        "playMaxBrLevel": playMaxBrLevel,
        "downloadMaxBrLevel": downloadMaxBrLevel,
        "plLevel": plLevel,
        "dlLevel": dlLevel,
        "flLevel": flLevel,
        "rscl": rscl,
        "freeTrialPrivilege": freeTrialPrivilege?.toJson(),
        "rightSource": rightSource,
        "chargeInfoList": chargeInfoList == null ? [] : List<dynamic>.from(chargeInfoList!.map((x) => x.toJson())),
      };
}

class ChargeInfoList {
  final int? rate;
  final dynamic chargeUrl;
  final dynamic chargeMessage;
  final int? chargeType;

  ChargeInfoList({
    this.rate,
    this.chargeUrl,
    this.chargeMessage,
    this.chargeType,
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

class FreeTrialPrivilege {
  final bool? resConsumable;
  final bool? userConsumable;
  final dynamic listenType;
  final int? cannotListenReason;

  FreeTrialPrivilege({
    this.resConsumable,
    this.userConsumable,
    this.listenType,
    this.cannotListenReason,
  });

  FreeTrialPrivilege copyWith({
    bool? resConsumable,
    bool? userConsumable,
    dynamic listenType,
    int? cannotListenReason,
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
