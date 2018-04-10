import './mediafile_reader.dart';

typedef void SuccessCallback([dynamic data]);
typedef void ErrorCallback(Object error);

class CallbackType {
  SuccessCallback onSuccess;
  ErrorCallback onError;
}

enum CharsetType { utf16, utf16le, utf16be, utf8, iso8859_1 }

class DecodedString {
  String _value;
  int bytesReadCount;
  int length;

  DecodedString(String value, this.bytesReadCount) {
    this._value = value;
    this.length = value.length;
  }

  @override
  String toString() {
    return _value;
  }
}

class ByteRange {
  int offset;
  int length;
}

class ChunkType {
  int offset;
  dynamic data;
}

typedef dynamic FrameReaderSignature(
  int offset,
  int length,
  MediaFileReader data,
  Object flags,
  TagHeader id3header,
);

class TagFrame {
  String id;
  int size;
  String description;
  dynamic data;
}

class TagFrameHeader {
  String id;
  int size;
  int headerSize;
  TagFrameFlags flags;
}

class TagFrameFlags {
  Message message;
  Format format;
}

class Format {
  bool groupingIdentity;
  bool compression;
  bool encryption;
  bool unsynchronization;
  bool dataLengthIndicator;
}

class Message {
  bool tagAlterPreservation;
  bool fileAlterPreservation;
  bool readOnly;
}

class TagHeader {
  String version;
  int major;
  int revision;
  TagHeaderFlags flags;
  int size;
}

class TagHeaderFlags {
  bool unsynchronisation;
  bool extendedHeader;
  bool experimentalIndicator;
  bool footerPresent;
}

class TagType {
  String type;
  Map<String, dynamic> tags;
}

class FrameType {
  String id;
  String description;
  dynamic data;
}
