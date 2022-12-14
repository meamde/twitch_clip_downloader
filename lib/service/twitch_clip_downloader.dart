//created by meamde @2022-11-12
import 'dart:core';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twitch_clip_downloader/service/download_manager.dart';
import 'package:twitch_clip_downloader/logger.dart';
import 'package:twitch_clip_downloader/main.dart';
import 'package:twitch_clip_downloader/service/twitch_manager.dart';
import 'package:url_launcher/url_launcher.dart';

class TwitchClipDownloaderWidget extends StatefulWidget {
  const TwitchClipDownloaderWidget({super.key});

  @override
  State<TwitchClipDownloaderWidget> createState() => _TwitchClipDownloaderWidgetState();
}

class _TwitchClipDownloaderWidgetState extends State<TwitchClipDownloaderWidget> {
  final TextEditingController broadcasterCtrl = TextEditingController();
  final TextEditingController loopCountCtrl = TextEditingController(text: '5');
  String broadcasterLoginId = '';
  String? broadcasterNick;
  String? broadcasterId;
  DateTime? _selectedDate;
  ValueNotifier<bool> onPathSelect = ValueNotifier(false);
  bool _onPause = false;

  @override
  void initState() {
    super.initState();
    TwitchManager().getAccessToken();
    DownloadManager().setCallBack(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder(
                  valueListenable: DownloadManager().onDownload,
                  builder: (context, onDownload, child) {
                    return SizedBox(
                      width: 310,
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                      width: 110, alignment: Alignment.centerRight, child: const Text('???????????? ????????? : ')),
                                  Expanded(
                                    child: TextField(
                                      controller: broadcasterCtrl,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 35,
                                    child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                                        onPressed: () async {
                                          final data = await TwitchManager()
                                              .getBroadcasterId(context, broadcasterCtrl.text.trim());
                                          if (data != null) {
                                            broadcasterId = data.broadcasterId;
                                            broadcasterNick = data.broadcasterNick;
                                            _selectedDate = data.createdDate;
                                            broadcasterCtrl.text = data.broadcasterLoginId;
                                            setState(() {});
                                          }
                                        },
                                        child: const Text("SET")),
                                  )
                                ],
                              ),
                              const SizedBox(
                                height: 30,
                              ),
                              Row(
                                children: [
                                  Container(
                                      width: 110, alignment: Alignment.centerRight, child: const Text('???????????? ????????? : ')),
                                  GestureDetector(
                                    onTap: broadcasterNick == null
                                        ? null
                                        : () async {
                                            final uri = Uri.parse('https://twitch.tv/$broadcasterLoginId');
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri);
                                            }
                                          },
                                    child: Row(
                                      children: [
                                        Text(
                                          broadcasterNick ?? "???????????? ???????????? SET????????????",
                                          style:
                                              TextStyle(color: broadcasterNick == null ? Colors.black45 : Colors.blue),
                                        ),
                                        if (broadcasterNick != null)
                                          const SizedBox(
                                            width: 5,
                                          ),
                                        if (broadcasterNick != null)
                                          const Icon(
                                            Icons.open_in_new,
                                            size: 16,
                                            color: Colors.blue,
                                          )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 30,
                              ),
                              Row(
                                children: [
                                  Container(
                                      width: 110, alignment: Alignment.centerRight, child: const Text('?????? ????????? : ')),
                                  Expanded(
                                    child: SizedBox(
                                      height: 30,
                                      child: OutlinedButton(
                                        child: _selectedDate == null
                                            ? const Text('Date not selected')
                                            : Text(
                                                '${_selectedDate?.year}-${_selectedDate?.month.toString().padLeft(2, '0')}-${_selectedDate?.day.toString().padLeft(2, '0')}'),
                                        onPressed: () async {
                                          final tmpDate = await showDatePicker(
                                            context: context,
                                            initialDate: _selectedDate ?? DateTime.now(),
                                            firstDate: DateTime(1999, 01, 01),
                                            lastDate: DateTime(2100, 12, 31),
                                          );
                                          if (tmpDate != null) {
                                            setState(() {
                                              _selectedDate = tmpDate;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 30,
                              ),
                              Row(
                                children: [
                                  Container(
                                      width: 110, alignment: Alignment.centerRight, child: const Text('???????????? ?????? : ')),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                            child: GestureDetector(
                                          onTap: DownloadManager().shortPath == null
                                              ? null
                                              : () async {
                                                  await launchUrl(Uri.file(DownloadManager().downloadPath!,
                                                      windows: Platform.isWindows));
                                                },
                                          child: Text(
                                            DownloadManager().shortPath ?? '????????? ????????? ?????????',
                                            style: TextStyle(
                                                color:
                                                    DownloadManager().shortPath == null ? Colors.black45 : Colors.blue),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                        SizedBox(
                                          width: 25,
                                          height: 25,
                                          child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                                              onPressed: () async {
                                                onPathSelect.value = true;
                                                final selectedPath =
                                                    await FilePicker.platform.getDirectoryPath(dialogTitle: '?????? ??????');
                                                if (selectedPath == null) {
                                                  onPathSelect.value = false;
                                                  return;
                                                }
                                                DownloadManager().downloadPath = selectedPath;
                                                DownloadManager().setShortPath();
                                                onPathSelect.value = false;
                                                setState(() {});
                                              },
                                              child: const Icon(Icons.folder, size: 20)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 15,
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                      width: 110, alignment: Alignment.centerRight, child: const Text('?????? ?????? ?????? : ')),
                                  SizedBox(
                                    width: 50,
                                    child: TextField(
                                      controller: loopCountCtrl,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      maxLength: 2,
                                      textAlignVertical: TextAlignVertical.bottom,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(counter: Container()),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (onDownload) Positioned.fill(child: Container(color: Colors.black12)),
                          Positioned(
                            bottom: 20,
                            left: 30,
                            width: 250,
                            child: SizedBox(
                              height: 40,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          side: const BorderSide(width: 1, color: Colors.black26)),
                                      onPressed: onDownload
                                          ? () => DownloadManager().stopDownload(context)
                                          : (() => validation()
                                              ? DownloadManager().startDownload(
                                                  context, _selectedDate!, int.parse(loopCountCtrl.text.trim()))
                                              : null),
                                      child: Text(onDownload ? "???????????? ??????" : "???????????? ??????",
                                          style: onDownload ? const TextStyle(color: Colors.red) : null),
                                    ),
                                  ),
                                  if (onDownload)
                                    SizedBox(
                                      width: 40,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 10),
                                        child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                                padding: EdgeInsets.zero, backgroundColor: Colors.white),
                                            onPressed: () {
                                              setState(() {
                                                _onPause = !_onPause;
                                              });
                                              DownloadManager().togglePause();
                                            },
                                            child: _onPause
                                                ? const Icon(Icons.play_arrow)
                                                : const Icon(Icons.pause, color: Colors.grey)),
                                      ),
                                    )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              const SizedBox(
                width: 30,
              ),
              Expanded(
                  child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.black12, width: 2)),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: ValueListenableBuilder(
                            valueListenable: Logger.loggerNotifier,
                            builder: (context, value, child) {
                              return SingleChildScrollView(
                                reverse: !DownloadManager().initial,
                                padding: const EdgeInsets.only(left: 5, right: 5, top: 5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: Logger.logs,
                                ),
                              );
                            }),
                      ),
                    ),
                    Column(
                      children: [
                        ValueListenableBuilder(
                            valueListenable: DownloadManager().progress,
                            builder: (context, value, child) => Stack(
                                  children: [
                                    LinearProgressIndicator(
                                      color: Colors.blue,
                                      value: value,
                                      minHeight: 20,
                                    ),
                                    if (DownloadManager().fullCount != null)
                                      Positioned.fill(
                                          child: Center(
                                              child: Text(
                                        "${DownloadManager().count} / ${DownloadManager().fullCount}",
                                        style: const TextStyle(color: Colors.black54),
                                      )))
                                  ],
                                )),
                      ],
                    ),
                  ],
                ),
              ))
            ],
          ),
        ),
        Positioned(
          bottom: 3,
          right: 15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text(
                "????????? : meamde",
                style: TextStyle(color: Colors.black45, fontSize: 12),
              ),
              const SizedBox(
                width: 10,
              ),
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse('https://github.com/meamde/twitch_clip_downloader/issues');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: Row(
                  children: const [
                    Text("????????????/?????? (Github)", style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                    Icon(
                      Icons.open_in_new,
                      size: 12,
                      color: Colors.blue,
                    )
                  ],
                ),
              )
            ],
          ),
        ),
        Positioned(
          bottom: 3,
          left: 15,
          child: Text(
            "v${packageInfo.buildNumber}",
            style: const TextStyle(color: Colors.black45, fontSize: 12),
          ),
        ),
        ValueListenableBuilder(
            valueListenable: onPathSelect,
            builder: (context, value, child) => value
                ? Positioned.fill(
                    child: Container(
                      color: Colors.black12,
                    ),
                  )
                : Container()),
      ],
    ));
  }

  bool validation() {
    if (broadcasterCtrl.text.trim().isEmpty) {
      showDefaultDialog(context, "???????????? ???????????? ??????????????????");
      return false;
    }
    if (_selectedDate == null) {
      showDefaultDialog(context, "?????? ???????????? ??????????????????");
      return false;
    }
    if (DownloadManager().downloadPath == null) {
      showDefaultDialog(context, "???????????? ????????? ??????????????????");
      return false;
    }
    if (loopCountCtrl.text.isEmpty || loopCountCtrl.text.startsWith('0')) {
      showDefaultDialog(context, "?????? ????????? 1~99??? ???????????? ??????????????????");
      return false;
    }
    return true;
  }
}
