import 'package:flutter/material.dart';

class Logger {
  static final loggerNotifier = ValueNotifier<int>(0);
  static final logs = <Widget>[
    const Text(
      '- 스트리머 아이디(트위치 방송 주소 끝부분) SET, 다운로드 경로 선택후 시작을 눌러주세요.',
      style: TextStyle(color: Colors.black45),
    ),
    const SizedBox(
      height: 20,
    ),
    const Text(
      '- 시작일은 계정생성일로 자동선택되나, 변경하면 선택한 날짜 이후의 클립만 받습니다.',
      style: TextStyle(color: Colors.black45),
    ),
    const SizedBox(
      height: 20,
    ),
    const Text(
      '- 트위치 제공 API의 문제로 한번 전체 검색을 해도 누락되는 클립이 있기에 루프 횟수를 늘리면 추가로 찾아지는 클립이 있을 수 있습니다.',
      style: TextStyle(color: Colors.black45),
    ),
  ];

  static void _notifyLog() => loggerNotifier.value = loggerNotifier.value + 1;
  static void add(Widget log) {
    logs.add(log);
    _notifyLog();
  }
  static void remove(Widget log) {
    logs.remove(log);
    _notifyLog();
  }
  static void addAll(List<Widget> newLogs){
    logs.addAll(newLogs);
    _notifyLog();
  }

  static void clear() {
    logs.clear();
    _notifyLog();
  }
}