import 'dart:io';
import 'package:yaml/yaml.dart';

const headerSize = 24.0;
const padding = 10.0;
const paddingSmall = padding / 2;
const prefsTokenKey = 'DropboxPlaylist:accessToken';
const prefsFolderKey = 'DropboxPlaylist:folder';
const prefsRepeatKey = 'DropboxPlaylist:repeat';
const prefsShuffleKey = 'DropboxPlaylist:shuffle';

class Property {
  final String name;
  final String value;

  static Map<String, Property> _cache = new Map<String, Property>();

  factory Property(String name) {
    if(_cache.isEmpty) {
      _loadProperties();
    }

    if(_cache.containsKey(name)) {
      return _cache[name];
    } else {
      return new Property._internal(name, null);
    }
  }

  Property._internal(this.name, this.value);

  static void _loadProperties() {
    File file = new File('env/config.dev.yaml');
    if(file?.existsSync() == true) {
      Map app = loadYaml(file.readAsStringSync());
      Map properties = app['properties'];
      properties.forEach((key, value) => _cache[key] = new Property._internal(key, value.toString()));
    }
  }
}
