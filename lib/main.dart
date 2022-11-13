//created by meamde @2022-11-12
import 'dart:core';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:twitch_clip_downloader/twitch_clip_downloader.dart';

void showDefaultDialog(BuildContext context, String text) {
  showDialog(
      context: context,
      builder: (context) => Dialog(
          child: SizedBox(
            width: 250,
            height: 130,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(text),
                const SizedBox(
                  height: 30,
                ),
                SizedBox(
                    height: 30,
                    width: 100,
                    child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인')))
              ],
            ),
          )));
}
late PackageInfo packageInfo;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  packageInfo = await PackageInfo.fromPlatform();
  runApp(const TwitchClipDownloader());

  doWhenWindowReady(() {
    const initialSize = Size(700, 450);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

