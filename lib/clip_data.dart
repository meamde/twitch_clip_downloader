//created by meamde @2022-11-12
import 'package:sanitize_filename/sanitize_filename.dart';

String dateformat(DateTime time) {
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}T${time.hour.toString().padLeft(2, '0')}-${time.minute.toString().padLeft(2, '0')}-${time.second.toString().padLeft(2, '0')}';
}

class ClipData {
  final String broadcasterName;
  final String cliperName;
  final DateTime createdTime;
  final String title;
  final String thumbnailUrl;
  final String clipUrl;
  String? _url;
  String? _filename;

  ClipData(this.broadcasterName, this.cliperName, this.createdTime, this.title, this.thumbnailUrl, this.clipUrl);

  String filename() => _filename ??=
      sanitizeFilename('[$broadcasterName][${dateformat(createdTime)}][cliper-$cliperName] $title.mp4');

  String getUrl() {
    if (_url != null) {
      return _url!;
    }
    final splited = thumbnailUrl.split('-preview-');
    // print(splited.join(','));
    if (splited.isNotEmpty) {
      _url = thumbnailUrl.replaceAll('-preview-${splited.last}', '.mp4');
    }
    // print(_url);
    return _url ?? '';
  }

  Map<String, dynamic> toMap() => {
    'broadcasterName': broadcasterName,
    'cliper': cliperName,
    'createdAt': createdTime.toIso8601String(),
    'title': title,
    'url': getUrl(),
    'filename': filename(),
    'clipUrl': clipUrl
  };

  @override
  String toString() => 'url : ${getUrl()}\nname : ${filename()}';
}
