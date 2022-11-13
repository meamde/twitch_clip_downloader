//created by meamde @2022-11-12
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:twitch_clip_downloader/config.dart';
import 'package:twitch_clip_downloader/logger.dart';
import 'package:twitch_clip_downloader/main.dart';

class TwitchManager {
  static final TwitchManager _instance = TwitchManager._();
  factory TwitchManager() => _instance;
  TwitchManager._();

  BroadcasterData? _broadcasterData;
  BroadcasterData? get broadcasterData => _broadcasterData;

  final _clientId = Config.clientId;
  final _clientSecret = Config.clientSecret;
  String? _accessToken;
  DateTime? tokenExpiredTime;

  Map<String, String> get authHeader =>
      {'Client-Id': _clientId, 'Authorization': 'Bearer $_accessToken'};

  bool get isVaildAccessToken => _accessToken != null && tokenExpiredTime!.isAfter(DateTime.now());

  Future<bool> getAccessToken() async {
    final res = await http.post(Uri.parse("https://id.twitch.tv/oauth2/token"),
        body: {'client_id': _clientId, 'client_secret': _clientSecret, 'grant_type': 'client_credentials'},
        encoding: Encoding.getByName('utf8'));
    final resMap = json.decode(res.body);
    if (res.statusCode != 200) {
      return false;
    }
    // print(resMap);
    _accessToken = resMap['access_token'];
    tokenExpiredTime = DateTime.now().add(Duration(seconds: resMap['expires_in']));
    return true;
  }

  Future<BroadcasterData?> getBroadcasterId(BuildContext context, String broadcasterLogin) async {
    if (broadcasterLogin.isEmpty) {
      showDefaultDialog(context, '스트리머 아이디를 입력해주세요');
      return null;
    }

    if (!TwitchManager().isVaildAccessToken) {
      if (!await TwitchManager().getAccessToken()) {
        Logger.add(const Text('twitch server error.', style: TextStyle(color: Colors.red)));
        showDefaultDialog(context, "앱 인증 실패 / 트위치 서버 오류");
        return null;
      }
    }

    final res = await http.get(Uri.https('api.twitch.tv', '/helix/users', {'login': broadcasterLogin}),
        headers: authHeader);

    final resMap = json.decode(res.body);
    List<dynamic> dataList = resMap['data'];
    if (res.statusCode != 200 || dataList.isEmpty) {
      showDefaultDialog(context, "존재하지 않는 스트리머입니다.");
      return null;
    }
    final data = dataList[0];
    _broadcasterData = BroadcasterData(data['id'], DateTime.parse(data['created_at']), data['display_name'], broadcasterLogin);
    return _broadcasterData;
  }
}

class BroadcasterData {
  final String broadcasterId;
  final DateTime createdDate;
  final String broadcasterNick;
  final String broadcasterLoginId;

  BroadcasterData(this.broadcasterId, this.createdDate, this.broadcasterNick, this.broadcasterLoginId);
}