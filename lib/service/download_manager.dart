//created by meamde @2022-11-12
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:pool/pool.dart';
import 'package:twitch_clip_downloader/clip_data.dart';
import 'package:twitch_clip_downloader/logger.dart';
import 'package:twitch_clip_downloader/service/twitch_manager.dart';
import 'package:http/http.dart' as http;

import '../main.dart';

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

  String sizeProgressString(int streamedClipSize, int originClipSize) =>
      '${filesize(streamedClipSize)} / ${filesize(originClipSize)}';
  int _fullFileSize = 0;
  bool initial = true;
  final List<ClipData> clipDatas = [];
  String? downloadPath;
  String? _shortPath;

  String? get shortPath => _shortPath;

  ValueNotifier<double> progress = ValueNotifier(0);

  Completer<void>? pauseCompleter;
  var downloadCompleter = Completer<bool>();
  final ValueNotifier<bool> onDownload = ValueNotifier<bool>(false);
  Function? _setStateCallBack;

  int _poolSize = 3;
  Pool? _downloadPool;

  void setCallBack(Function? setStateCallBack) {
    _setStateCallBack = setStateCallBack;
  }

  void setShortPath() {
    if (downloadPath != null) {
      _shortPath = '';
      if (Platform.isWindows) {
        final pathList = downloadPath!.split('\\');
        if (pathList.isNotEmpty) {
          _shortPath = '${pathList.length > 1 ? "\\${pathList[pathList.length - 2]}" : ''}\\${pathList.last}';
        }
        if (pathList.length > 2) {
          _shortPath = '....$_shortPath';
        }
      } else {
        final pathList = downloadPath!.split('/');
        if (pathList.isNotEmpty) {
          _shortPath = '${pathList.length > 1 ? "/${pathList[pathList.length - 2]}" : ''}/${pathList.last}';
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

    if (_poolSize <= 0) {
      _poolSize = 1;
    } else if (_poolSize > 5) {
      _poolSize = 5;
    }
    _downloadPool = Pool(_poolSize);

    Logger.addAll([
      ValueListenableBuilder(
          valueListenable: loopNotifier, builder: (context, value, child) => Text('?????? ?????? ???????????????... ?????? ?????? : $value')),
      Row(
        children: [
          ValueListenableBuilder(
              valueListenable: countNotifier,
              builder: (context, value, child) =>
                  Text("$value??? / ???????????? : ${filesize((_fullVideoDuration * 774000).round())}  ")),
          FutureBuilder(
              key: ValueKey('${DateTime.now().millisecondsSinceEpoch}'),
              future: turnCompleter.future,
              builder: (context, snap) => snap.hasData
                  ? Container()
                  : const SizedBox(width: 15, height: 15, child: CircularProgressIndicator()))
        ],
      ),
      const SizedBox(
        height: 5,
      ),
      const Text(
        '- ?????? ????????? ?????? ????????? ???????????? ?????? ??????????????????.',
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
            showDefaultDialog(context, "????????? ?????? ??????");
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
              DateTime.parse(element['created_at']), element['title'], element['thumbnail_url'], element['url']));
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
    final clipJsonFile = File('$downloadPath/${TwitchManager().broadcasterData?.broadcasterNick}_clipList.json');
    clipJsonFile.create();
    clipJsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(clipDatas.map((e) => e.toMap()).toList()));

    if (!turnCompleter.isCompleted) {
      _fullCount = clipDatas.length;
      Logger.clear();
      Logger.addAll([
        Text('?????? ?????? ??????! ??? $_fullCount ?????? ????????? ???????????????.\n???????????? : ${filesize((_fullVideoDuration * 774000).round())}'),
        const Text('Download Start...')
      ]);
      downloadClips(context);
    }
  }

  void downloadClips(BuildContext context) async {
    _count = 0;
    _fullFileSize = 0;
    var client = http.Client();
    final Completer<bool> allClipCompleter = Completer();
    for (var clip in clipDatas) {
      if (!onDownload.value) {
        return;
      }
      final resource = await _downloadPool!.request();
      () async {
          final request = http.Request('GET', Uri.parse(clip.getUrl()));
          final streamRes = await client.send(request);
          if (streamRes.statusCode != 200) {
            _failedCount++;
            Logger.add(Text(
              '???????????? ??????! : $clip',
              style: const TextStyle(color: Colors.red),
            ));
            if((_count + _failedCount) == _fullCount!){
              print('$_count : ${(_count + _failedCount) == _fullCount!}');
              allClipCompleter.complete(false);
            }
            return;
          }

          final originCLipSize = streamRes.contentLength!;
          _fullFileSize += originCLipSize;
          var streamedClipSize = 0;
          final fileProgress = ValueNotifier<double>(0);
          _setStateCallBack?.call();

          Logger.add(Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ValueListenableBuilder(
                          valueListenable: fileProgress,
                          builder: (context, value, child) => LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.transparent,
                                color: Colors.blue.withOpacity(0.3),
                              )),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            "??????????????? : ${clip.filename()}",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(filesize(originCLipSize), style: const TextStyle(color: Colors.black45),)
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ));
          try {
            final file = File("${downloadPath!}${Platform.isWindows ? '\\' : '/'}${clip.filename()}");
            await file.create();
            List<int> fileBytes = [];
            await for (List<int> bytes in streamRes.stream) {
              if (!onDownload.value) {
                break;
              }
              streamedClipSize += bytes.length;
              fileProgress.value = streamedClipSize / originCLipSize;
              fileBytes.addAll(bytes);

              if (pauseCompleter != null) {
                await pauseCompleter!.future;
              }
            }
            await file.writeAsBytes(fileBytes);
          } catch (e) {
            Logger.add(Text(
              "????????????! clip: $clip\nerror : $e",
              style: const TextStyle(color: Colors.red),
            ));
            finishDownload(false);
            return;
          }
          if(!onDownload.value) {
            return;
          }

          _count++;
          progress.value = _count / _fullCount!;
          print('$_count : ${(_count + _failedCount) == _fullCount!}');
          if((_count + _failedCount) == _fullCount!) {
            allClipCompleter.complete(true);
          }
      }.call().whenComplete(() => resource.release());
    }
    await allClipCompleter.future;
    Logger.addAll([
      Text(
        "???????????? ??????! ??? $_count??? / ${filesize(_fullFileSize)}",
        style: const TextStyle(color: Colors.blue),
      ),
      if (_failedCount > 0) Text("???????????? ?????? ??? : $_failedCount", style: const TextStyle(color: Colors.orange))
    ]);
    showDefaultDialog(context, "??????????????? ?????????????????????!");
    finishDownload(true);
  }

  void stopDownload(BuildContext context) async {
    if (await showDialog(
        context: context,
        builder: (context) => Dialog(
                child: SizedBox(
              width: 300,
              height: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("??????????????? ?????????????????????????"),
                  const SizedBox(
                    height: 30,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text(
                            '??????',
                            style: TextStyle(color: Colors.red),
                          )),
                      const SizedBox(
                        width: 20,
                      ),
                      OutlinedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('??????')),
                    ],
                  )
                ],
              ),
            )))) {
      return;
    }
    Logger.add(const Text(
      "??????????????? ?????????????????????.",
      style: TextStyle(color: Colors.red),
    ));
    finishDownload(false);
  }

  void finishDownload(bool complete) {
    _downloadPool?.close();
    if (pauseCompleter?.isCompleted == false) {
      pauseCompleter!.complete();
    }
    pauseCompleter = null;
    downloadCompleter.complete(complete);
    downloadCompleter = Completer<bool>();
    onDownload.value = false;
    progress.value = 0;
    _fullCount = null;
    _count = 0;
    _failedCount = 0;
    _setStateCallBack?.call();
  }

  final pauseTxt = const Text(
    '???????????? ???????????????.',
    style: TextStyle(color: Colors.deepOrange),
  );

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
