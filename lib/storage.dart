import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Storage {
  Directory appFolder;
  static Storage _instance;

  Storage._internal(this.appFolder);

  static Future<Storage> getInstance() async {
    if (_instance == null) {
      Directory dir = await getApplicationDocumentsDirectory();
      _instance = new Storage._internal(dir);
    }
    return _instance;
  }

  listLocalItems({recursive: false}) async {
    return appFolder
        .list(recursive: recursive)
        .map((entity) => entity.path)
        .toList();
  }

  clearLocalItems() async {
    var items = appFolder.list(recursive: true);
    return items.forEach((file) => file.delete(recursive: true));
  }

  getLocalFile(String path) async {
    return new File('${appFolder.path}$path');
  }

  createLocalFile(String path) async {
    var file = getLocalFile(path);

    if (await file.exists()) {
      return file;
    }

    return await file.create(recursive: true);
  }
}
