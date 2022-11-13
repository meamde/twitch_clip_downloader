//created by meamde @2022-11-12
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:twitch_clip_downloader/clip_data.dart';
import 'package:twitch_clip_downloader/logger.dart';
import 'package:twitch_clip_downloader/twitch_manager.dart';
import 'package:http/http.dart' as http;

import 'main.dart';

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._();

  factory DownloadManager() => _instance;

  DownloadManager._();

  double _fullVideoDuration = 0;
  int? _fullCount;

  int? get fullCount => _fullCount;
  int _count = 0;

  int get count => _count;
  int _failedCount = 0;
  int? _oneClipSize;

  int? get oneClipSize => _oneClipSize;
  int? _streamedClipSize;

  String get sizeProgressString => '${filesize(_streamedClipSize)} / ${filesize(_oneClipSize)}';
  int _fullFileSize = 0;
  bool initial = true;
  final List<ClipData> clipDatas = [];
  String? downloadPath;
  String? _shortPath;

  String? get shortPath => _shortPath;

  ValueNotifier<double> progress = ValueNotifier(0);
  ValueNotifier<double>? fileProgress;

  Completer<void>? pauseCompleter;
  var downloadCompleter = Completer<bool>();
  final ValueNotifier<bool> onDownload = ValueNotifier<bool>(false);
  Function? _setStateCallBack;

  void setCallBack(Function? setStateCallBack) {
    _setStateCallBack = setStateCallBack;
  }

  void setShortPath() {
    if (downloadPath != null) {
      _shortPath = '';
      if (Platform.isWindows) {
        final pathList = downloadPath!.split('\\');
        if (pathList.isNotEmpty) {
          _shortPath =
          '${pathList.length > 1 ? "\\${pathList[pathList.length - 2]}" : ''}\\${pathList.last}';
        }
        if (pathList.length > 2) {
          _shortPath = '....$_shortPath';
        }
      } else {
        final pathList = downloadPath!.split('/');
        if (pathList.isNotEmpty) {
          _shortPath =
          '${pathList.length > 1 ? "/${pathList[pathList.length - 2]}" : ''}/${pathList.last}';
        }
        if (pathList.length > 2) {
          _shortPath = '....$_shortPath';
        }
      }
    } else {
      _shortPath = null;
    }
  }

  void startDownload(BuildContext context, DateTime selectedDate, int loopCount) async {
    final turnCompleter = downloadCompleter;
    Logger.clear();
    final countNotifier = ValueNotifier<int>(0);
    final loopNotifier = ValueNotifier<int>(0);
    initial = false;

    Logger.addAll([
      ValueListenableBuilder(
          valueListenable: loopNotifier, builder: (context, value, child) => Text('클립 목록 불러오는중... 현재 루프 : $value')),
      Row(
        children: [
          ValueListenableBuilder(
              valueListenable: countNotifier,
              builder: (context, value, child) =>
                  Text("$value개 / 예상용량 : ${filesize((_fullVideoDuration * 774000).round())}  ")),
          FutureBuilder(
              key: ValueKey('${DateTime
                  .now()
                  .millisecondsSinceEpoch}'),
              future: turnCompleter.future,
              builder: (context, snap) =>
              snap.hasData
                  ? Container()
                  : const SizedBox(width: 15, height: 15, child: CircularProgressIndicator()))
        ],
      ),
      const SizedBox(
        height: 5,
      ),
      const Text(
        '- 예상 용량은 영상 길이만 측정하여 매우 부정확합니다.',
        style: TextStyle(color: Colors.black45),
      ),
    ]);

    onDownload.value = true;

    clipDatas.clear();
    String? nextPage;
    final Set<String> clipIds = {};
    var startAt = selectedDate;
    var endAt = DateTime.now(); //_selectedDate!.add(const Duration(days: 60)); //
    _fullVideoDuration = 0;
    // print("$startAt / $endAt");
    for (int i = 0; i < loopCount; i++) {
      loopNotifier.value = i + 1;
      do {
        if (!TwitchManager().isVaildAccessToken) {
          if (!await TwitchManager().getAccessToken()) {
            showDefaultDialog(context, "트위치 서버 에러");
            break;
          }
        }
        final res = await http.get(
            Uri.https('api.twitch.tv', '/helix/clips', {
              'broadcaster_id': TwitchManager().broadcasterData?.broadcasterId,
              'started_at': startAt.toUtc().toIso8601String(),
              'ended_at': endAt.toUtc().toIso8601String(),
              'first': '50',
              if (nextPage != null) 'after': nextPage
            }),
            headers: TwitchManager().authHeader);
        final resMap = json.decode(utf8.decode(res.bodyBytes));
        // print(resMap);
        List<dynamic> dataList = resMap['data'];

        for (final element in dataList) {
          if (clipIds.contains(element['id'])) {
            continue;
          }
          if (pauseCompleter != null) {
            print('paused');
            await pauseCompleter!.future;
          }
          clipIds.add(element['id']);
          clipDatas.add(ClipData(element['broadcaster_name'], element['creator_name'],
              DateTime.parse(element['created_at']), element['title'], element['thumbnail_url']));
          _fullVideoDuration += element['duration'];
          if (turnCompleter.isCompleted) {
            break;
          }
        }
        countNotifier.value = clipDatas.length;
        if (turnCompleter.isCompleted) {
          break;
        }
        nextPage = resMap['pagination']?['cursor'];
      } while (nextPage != null);

      if (turnCompleter.isCompleted) {
        break;
      }
    }
    //print(clipDatas.length);
    if (!turnCompleter.isCompleted) {
      _fullCount = clipDatas.length;
      Logger.clear();
      Logger.addAll([
        Text('클립 로드 완료! 총 $_fullCount 개의 클립을 찾았습니다.\n예상용량 : ${filesize((_fullVideoDuration * 774000).round())}'),
        const Text('Download Start...')
      ]);
      downloadClips();
    }
  }

  void downloadClips() async {
    _count = 0;
    _fullFileSize = 0;
    var client = http.Client();
    for (final clip in clipDatas) {
      final request = http.Request('GET', Uri.parse(clip.getUrl()));
      final streamRes = await client.send(request);
      if (streamRes.statusCode != 200) {
        _failedCount++;
        Logger.add(Text('다운로드 실패! : $clip', style: const TextStyle(color: Colors.red),));
        continue;
      }

      _oneClipSize = streamRes.contentLength;
      _fullFileSize += _oneClipSize!;
      _streamedClipSize = 0;
      fileProgress = ValueNotifier<double>(0);
      _setStateCallBack?.call();

      Logger.add(Text(
        "다운로드중 : ${clip.filename()}",
        overflow: TextOverflow.ellipsis,
      ));
      try {
        final file = File("${downloadPath!}${Platform.isWindows ? '\\' : '/'}${clip.filename()}");
        await file.create();
        // final openFile = file.openWrite();
        List<int> fileBytes = [];
        await for (List<int> bytes in streamRes.stream) {
          // openFile.write(bytes);
          _streamedClipSize = _streamedClipSize! + bytes.length;
          fileProgress!.value = _streamedClipSize! / _oneClipSize!;
          fileBytes.addAll(bytes);

          if (!onDownload.value) {
            finishDownload(false);
            // await openFile.close();
            return;
          }
          if (pauseCompleter != null) {
            await pauseCompleter!.future;
          }
        }
        await file.writeAsBytes(fileBytes);
      } catch (e) {
        Logger.add(Text(
          "에러발생! clip: $clip\n$e",
          style: const TextStyle(color: Colors.red),
        ));
        finishDownload(false);
        return;
      }
      _count++;
      progress.value = _count / _fullCount!;
    }
    Logger.addAll([
      Text(
        "다운로드 완료! 총 $_count개 / ${filesize(_fullFileSize)}",
        style: const TextStyle(color: Colors.blue),
      ),
      if(_failedCount > 0)
        Text("다운로드 실패 수 : $_failedCount", style: const TextStyle(color: Colors.orange))
    ]);
    finishDownload(true);
  }

  void stopDownload(BuildContext context) async {
    if (await showDialog(
        context: context,
        builder: (context) =>
            Dialog(
                child: SizedBox(
                  width: 300,
                  height: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("다운로드를 중단하시겠습니까?"),
                      const SizedBox(
                        height: 30,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text(
                                '중단',
                                style: TextStyle(color: Colors.red),
                              )),
                          const SizedBox(
                            width: 20,
                          ),
                          OutlinedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('계속')),
                        ],
                      )
                    ],
                  ),
                )))) {
      return;
    }
    Logger.add(const Text(
      "다운로드가 중단되었습니다.",
      style: TextStyle(color: Colors.red),
    ));
    finishDownload(false);
  }

  void finishDownload(bool complete) {
    if (pauseCompleter?.isCompleted == false) {
      pauseCompleter!.complete();
    }
    pauseCompleter = null;
    downloadCompleter.complete(complete);
    downloadCompleter = Completer<bool>();
    onDownload.value = false;
    progress.value = 0;
    fileProgress?.value = 0;
    fileProgress = null;
    _fullCount = null;
    _count = 0;
    _failedCount = 0;
    _oneClipSize = null;
    _streamedClipSize = null;
    _setStateCallBack?.call();
  }

  final pauseTxt = const Text('다운로드 일시중지됨.', style: TextStyle(color: Colors.deepOrange),);
  void togglePause() {
    if (pauseCompleter?.isCompleted == false) {
      pauseCompleter!.complete();
      pauseCompleter = null;
      Logger.remove(pauseTxt);
    } else {
      pauseCompleter = Completer<void>();
      Logger.add(pauseTxt);
    }
    _setStateCallBack?.call();
  }
}