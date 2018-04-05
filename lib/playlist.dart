import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayer/audioplayer.dart';
import 'package:path_provider/path_provider.dart';
import './settings.dart';
import './properties.dart';
import './dropbox.dart';

class Playlist extends StatefulWidget {
  @override
  createState() => new PlayListState();
}

enum PlayerState { Playing, Stopped }

class PlaySettings {
  bool repeat;
  bool shuffle;

  PlaySettings(this.repeat, this.shuffle);
}

class PlayListState extends State<Playlist> {
  DropBox dropBox;
  AudioPlayer audioPlayer;
  PlayerState playerState = PlayerState.Stopped;
  Queue<PlayListItem> playQueue;
  PlaySettings playSettings;

  var items = new Set<PlayListItem>();

  PlayListItem activePlayListItem;

  void play(PlayListItem item) async {
    if (playerState == PlayerState.Playing) {
      await stop();
      if (item != activePlayListItem) {
        enqueue(item);
      }
    } else {
      enqueue(item);
    }
  }

  enqueue(PlayListItem item) {
    initQueueFrom(item);
    playNew(playQueue.removeFirst());
  }

  playNew(PlayListItem item) async {
    final file = await dropBox.loadFile(item.path);

    if (await file.exists()) {
      setState(() {
        activePlayListItem = item;
        playerState = PlayerState.Playing;
        start(file.path);
      });
    }
  }

  initQueueFrom(PlayListItem item) {
    playQueue = new Queue<PlayListItem>();
    playQueue.add(item);
    List<PlayListItem> playList = new List.from(items);
    var index = 0;
    final length = playList.length;

    /// Find start index in original list
    for (var i = 0; i < length; i++) {
      if (item == playList.elementAt(i)) {
        index = i + 1;
        break;
      }
    }

    if (playSettings.shuffle) {
      playList.shuffle(new Random());
    }

    for (num i = 0; i < length; i++) {
      playQueue.add(items.elementAt((index + i) % length));
    }

    print('Starting new queue with ${playQueue
        .length} items starting from number $index');
  }

  start(path) async {
    await audioPlayer.play(path, isLocal: true);
  }

  stop() async {
    await audioPlayer.stop();
    setState(() {
      activePlayListItem.stop();
      playerState = PlayerState.Stopped;
    });
  }

  void _onSettings() {
    Navigator
        .of(context)
        .push(new MaterialPageRoute(builder: (context) => new Settings()));
  }

  @override
  void initState() {
    super.initState();
    initDropBoxClient().then((ready) {
      if (ready) {
        initAudioPlayer();
      }
    });
    SharedPreferences.getInstance().then((prefs) {
      var repeat = prefs.get(prefsRepeatKey) ?? false;
      var shuffle = prefs.get(prefsShuffleKey) ?? false;

      this.playSettings = new PlaySettings(repeat, shuffle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = items.map((item) => item.buildItemRow(play));
    final divided =
    ListTile.divideTiles(context: context, tiles: rows).toList();

    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Dropbox Playlist'),
        actions: <Widget>[
          new IconButton(icon: new Icon(Icons.settings), onPressed: _onSettings)
        ],
      ),
      body: (rows.length > 0
          ? new ListView(children: divided)
          : new Center(
        child: new RaisedButton(
            elevation: 4.0,
            child: new Text(
              'Retrieve Playlist', style: new TextStyle(color: Colors.white),),
            color: Colors.blueAccent,
            onPressed: () => retrievePlayList()),)),
    );
  }

  void retrievePlayList() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final folder = preferences.getString(prefsFolderKey);
    if (folder != null) {
      var entries = await dropBox.listFolder(folder, includeMediaInfo: true);
      Set<PlayListItem> playListItems = entries.where((entry) => entry.isFile()
          && (entry.pathLower.endsWith('mp3') || entry.pathLower.endsWith('m4a')))
          .map((entry) => new PlayListItem(entry.name, 'Me', entry.pathLower))
          .toSet();
      setState(() {
        items = playListItems;
      });
    }
  }

  Future<bool> initDropBoxClient() async {
    final accessToken = new Property('accessToken');
    var dir = await getApplicationDocumentsDirectory();
    dropBox = new DropBox(token: accessToken.value, appFolder: dir.path);
    return true;
  }

  void initAudioPlayer() {
    audioPlayer = new AudioPlayer();
    audioPlayer.setDurationHandler((d) =>
        setState(() {
          activePlayListItem.play(d);
        }));
    audioPlayer.setPositionHandler((p) =>
        setState(() {
          activePlayListItem.progress(p);
        }));
    audioPlayer.setCompletionHandler(() => onComplete());
    audioPlayer.setErrorHandler((msg) => onComplete());
  }

  void onComplete() {
    stop();
    PlayListItem newItem = playQueue.removeFirst();
    if (newItem != null) {
      if (playQueue.isEmpty && playSettings.repeat) {
        enqueue(newItem);
      } else {
        playNew(newItem);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    audioPlayer.stop();
  }
}

class PlayListItem {
  String name;
  String author;
  String path;
  Duration duration;
  Duration position;
  bool playing = false;

  final iconSize = 32.0;

  PlayListItem(this.name, this.author, this.path);

  void play(Duration duration) {
    this.position = new Duration();
    this.duration = duration;
    this.playing = true;
  }

  void progress(Duration position) {
    this.position = position;
  }

  void stop() => this.playing = false;

  Widget buildProgressIndicator() {
    final progress = (position?.inMilliseconds?.toDouble() ?? 0.0) /
        (duration?.inMilliseconds?.toDouble() ?? 0.0);
    return new Stack(
      children: <Widget>[
        new Icon(
          Icons.stop,
          size: iconSize,
          color: Colors.blue,
        ),
        new CircularProgressIndicator(
          value: 1.0,
          valueColor: new AlwaysStoppedAnimation(Colors.grey[300]),
        ),
        new CircularProgressIndicator(
          value:
          position != null && position.inMilliseconds > 0 ? progress : 0.0,
          valueColor: new AlwaysStoppedAnimation(Colors.blue),
          backgroundColor: Colors.yellow,
        )
      ],
    );
  }

  Widget buildItemRow(playCallback) {
    return new ListTile(
      leading: new Icon(
        Icons.music_note,
        size: iconSize,
      ),
      title: new Text(
        name,
        style: new TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: new Text(
        author,
        style: new TextStyle(fontStyle: FontStyle.italic),
      ),
      trailing: new IconButton(
        icon: (playing == true
            ? buildProgressIndicator()
            : new Icon(Icons.play_circle_outline)),
        iconSize: iconSize,
        color: Colors.blue,
        onPressed: () => playCallback(this),
      ),
    );
  }
}
