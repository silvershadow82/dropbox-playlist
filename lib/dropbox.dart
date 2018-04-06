import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import './storage.dart';
import './properties.dart';

typedef void OnError(Exception exception);

class DropBox {
  Property token;
  Storage storage;

  DropBox() {
    this.token = new Property('accessToken');
    Storage.getInstance().then((storage) => this.storage = storage);
  }

  /// List contents of a folder
  Future<List<Entry>> listFolder(String folder,
      {bool recursive = false,
        bool includeMediaInfo = false,
        bool includeDeleted = false}) async {
    var uri = new Uri.https('api.dropboxapi.com', '/2/files/list_folder');
    var response = await http.post(uri.toString(), headers: {
    'Authorization': 'Bearer ${token.value}',
    'Content-Type': 'application/json'
    }, body: json.encode({
      'path': folder,
      'recursive': recursive,
      'include_media_info': includeMediaInfo,
      'include_deleted': includeDeleted
    }));
    var responseBody = response.body;
    Map jsonData = json.decode(responseBody);
    List<Map> entries = jsonData['entries'];

    return entries.map((entry) => new Entry.fromJson(entry)).toList();
  }

  Future<File> loadFile(String path) async {
    var localFile = await storage.getLocalFile(path);

    /// Just return local file - no need to re-download
    if(await localFile.exists()) {
      return localFile;
    }

    localFile = await storage.createLocalFile(path);

    final arg = json.encode({'path': path});
    var uri = new Uri.https('content.dropboxapi.com', '/2/files/download');
    var request = await new HttpClient().postUrl(uri);

    request.headers.add('Authorization', 'Bearer ${token.value}');
    request.headers.add('Dropbox-API-Arg', arg);

    var response = await request.close();

    await response.pipe(localFile.openWrite());

    return localFile;
  }
}

class Entry {
  String tag;
  String name;
  String id;
  String rev;
  num size;
  String pathLower;
  String pathDisplay;
  bool hasExplicitSharedMembers;
  String contentHash;
  SharingInfo sharingInfo;
  List<PropertyGroup> propertyGroups;

  Entry(String tag) {
    this.tag = tag;
  }

  Entry.fromJson(Map json)
      : tag = json['.tag'],
        name = json['name'],
        id = json['id'],
        rev = json['rev'],
        size = json['size'],
        pathLower = json['path_lower'],
        pathDisplay = json['path_display'];

  bool isFile() => tag == 'file';

  bool isAudioFile() => isFile() && (pathLower.endsWith('mp3') || pathLower.endsWith('m4a'));

  bool isFolder() => tag == 'folder';
}

class DropBoxFolder extends Entry {
  DropBoxFolder() : super('folder');

  DropBoxFolder.fromJson(Map data) : super.fromJson(data);
}

class DropBoxFile extends Entry {
  DropBoxFile() : super('file');

  DropBoxFile.fromJson(Map data) : super.fromJson(data);
}

class SharingInfo {
  bool readOnly;
  String modifiedBy;
}

class PropertyGroup {
  String templateId;
  List<Field> fields;
}

class Field {
  String name;
  String value;

  Field(this.name, this.value);
}
