import 'dart:async';
import './types.dart';
import './mediafile_reader.dart';

abstract class MediaTagReader {
  MediaFileReader _mediaFileReader;
  List<String> _tags;

  MediaTagReader(MediaFileReader mediaFileReader) {
    this._mediaFileReader = mediaFileReader;
    this._tags = null;
  }

  ByteRange getTagIdentifierByteRange();

  bool canReadTagFormat(List<int> tagIdentifier);

  Future _loadData(MediaFileReader mediaFileReader);

  TagType _parseData(MediaFileReader mediaFileReader, List<String> tags);

  MediaTagReader setTagsToRead(List<String> tags) {
    this._tags = tags;
    return this;
  }

  Map<String, dynamic> getShortcuts() {
    return {};
  }

  Future read({ErrorCallback onError}) async {
    await _mediaFileReader.init();
    await _loadData(_mediaFileReader);
    try {
      var tags = _parseData(_mediaFileReader, _tags);
      return new Future.value(tags);
    } catch (e) {
      if (onError != null) {
        onError({'type': 'parseData', 'info': e.message});
        return new Future.error(e, e.stackTrace);
      }
    }
  }

  List<String> _expandShortcutTags([List<String> tagsWithShortcuts]) {
    if (tagsWithShortcuts == null) return null;

    var tags = [];
    var shortcuts = getShortcuts();
    tagsWithShortcuts.forEach(
        (tagOrShortcut) => tags += shortcuts[tagOrShortcut] ?? tagOrShortcut);

    return tags;
  }
}
