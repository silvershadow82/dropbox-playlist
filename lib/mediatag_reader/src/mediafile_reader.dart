import 'dart:async';
import './string_utils.dart';
import './types.dart';

abstract class MediaFileReader {
  num size;
  bool isInitialized;

  MediaFileReader([path]) {
    isInitialized = false;
    size = 0;
  }

  Future init({SuccessCallback onSuccess, ErrorCallback onError}) async {
    Completer completer = new Completer();
    if (isInitialized) {
      completer.complete(onSuccess);
    } else {
      this._init().then((value) {
        this.isInitialized = true;
        completer.complete(onSuccess);
      }, onError: onError);
    }
    return completer.future;
  }

  /// Abstract method
  bool canReadFile(dynamic file);

  /// Abstract method
  Future _init({ErrorCallback onError});

  /// Abstract method
  int getByteAt(int offset);

  /// Abstract method
  Future<void> loadRange(List<int> range);

  int getSize() {
    if (!isInitialized) {
      throw new Exception("init() must be called first.");
    }

    return size;
  }

  List<int> getBytesAt(int offset, int length) {
    var bytes = new List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = getByteAt(offset + i);
    }
    return bytes;
  }

  bool isBitSetAt(int offset, int bit) {
    int iByte = getByteAt(offset);
    return (iByte & (1 << bit)) != 0;
  }

  int getSByteAt(int offset) {
    int iByte = getByteAt(offset);
    return iByte > 127 ? iByte - 256 : iByte;
  }

  int getShortAt(int offset, bool isBigEndian) {
    var iShort = isBigEndian
        ? (getByteAt(offset) << 8) + getByteAt(offset + 1)
        : (getByteAt(offset + 1) << 8) + getByteAt(offset);
    if (iShort < 0) {
      iShort += 65536;
    }
    return iShort;
  }

  int getSShortAt(int offset, bool isBigEndian) {
    var iUShort = getShortAt(offset, isBigEndian);
    if (iUShort > 32767) {
      return iUShort - 65536;
    } else {
      return iUShort;
    }
  }

  int getLongAt(int offset, bool isBigEndian) {
    var iByte1 = getByteAt(offset),
        iByte2 = getByteAt(offset + 1),
        iByte3 = getByteAt(offset + 2),
        iByte4 = getByteAt(offset + 3);

    var iLong = isBigEndian
        ? (((((iByte1 << 8) + iByte2) << 8) + iByte3) << 8) + iByte4
        : (((((iByte4 << 8) + iByte3) << 8) + iByte2) << 8) + iByte1;

    if (iLong < 0) {
      iLong += 4294967296;
    }

    return iLong;
  }

  int getSLongAt(int offset, bool isBigEndian) {
    var iULong = getLongAt(offset, isBigEndian);

    if (iULong > 2147483647) {
      return iULong - 4294967296;
    } else {
      return iULong;
    }
  }

  int getInteger24At(int offset, bool isBigEndian) {
    var iByte1 = this.getByteAt(offset),
        iByte2 = this.getByteAt(offset + 1),
        iByte3 = this.getByteAt(offset + 2);

    var iInteger = isBigEndian
        ? ((((iByte1 << 8) + iByte2) << 8) + iByte3)
        : ((((iByte3 << 8) + iByte2) << 8) + iByte1);

    if (iInteger < 0) {
      iInteger += 16777216;
    }

    return iInteger;
  }

  String getStringAt(int offset, int length) {
    var string = [];
    for (var i = offset, j = 0; i < offset + length; i++, j++) {
      string[j] = new String.fromCharCode(getByteAt(i));
    }
    return string.join("");
  }

  DecodedString getStringWithCharsetAt(
      int offset, int length, CharsetType charset) {
    var bytes = this.getBytesAt(offset, length);
    var string;

    switch (charset) {
      case CharsetType.utf16:
      case CharsetType.utf16le:
      case CharsetType.utf16be:
        string = StringUtils.readUTF16String(
            bytes: bytes, bigEndian: charset == CharsetType.utf16be);
        break;

      case CharsetType.utf8:
        string = StringUtils.readUTF8String(bytes: bytes);
        break;

      default:
        string = StringUtils.readNullTerminatedString(bytes: bytes);
        break;
    }

    return string;
  }

  String getCharAt(int offset) {
    return new String.fromCharCode(getByteAt(offset));
  }

  /// The ID3v2 tag/frame size is encoded with four bytes where the most
  /// significant bit (bit 7) is set to zero in every byte, making a total of 28
  /// bits. The zeroed bits are ignored, so a 257 bytes long tag is represented
  /// as $00 00 02 01.
  int getSynchsafeInteger32At(int offset) {
    var size1 = this.getByteAt(offset);
    var size2 = this.getByteAt(offset + 1);
    var size3 = this.getByteAt(offset + 2);
    var size4 = this.getByteAt(offset + 3);
    // 0x7f = 0b01111111
    var size = size4 & 0x7f |
        ((size3 & 0x7f) << 7) |
        ((size2 & 0x7f) << 14) |
        ((size1 & 0x7f) << 21);

    return size;
  }
}
