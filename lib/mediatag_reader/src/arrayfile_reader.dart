import 'dart:async';
import './mediafile_reader.dart';

class ArrayFileReader extends MediaFileReader {
  List<int> _array;

  ArrayFileReader(List<int> array) : super() {
    this._array = array;
    this.size = array.length;
    this.isInitialized = true;
  }

  @override
  bool canReadFile(file) {
    return (file is List);
  }

  @override
  int getByteAt(int offset) {
    if(offset > size) {
      throw new Exception("Offset $offset hasn't been loaded yet.");
    }
    return _array[offset];
  }

  @override
  Future<void> loadRange(List<int> range) {
    return new Future.value();
  }

}