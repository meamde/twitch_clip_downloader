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
  String? _url;

  ClipData(this.broadcasterName, this.cliperName, this.createdTime, this.title, this.thumbnailUrl);

  String filename() =>
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

  @override
  String toString() => 'url : ${getUrl()}\nname : ${filename()}';
}
