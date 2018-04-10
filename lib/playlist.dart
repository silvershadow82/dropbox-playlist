import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayer/audioplayer.dart';
import './settings.dart';
import './properties.dart';
import './dropbox.dart';
import './storage.dart';

class Playlist extends StatefulWidget {
  @override
  createState() => new PlayListState();
}

enum PlayerState { Playing, Stopped, Paused }

class PlaySettings {
  bool repeat;
  bool shuffle;

  PlaySettings(this.repeat, this.shuffle);
}

class PlayListState extends State<Playlist> {
  DropBox dropBox;
  Storage storage;
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
        item.downloaded = true;
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
    index = playList.indexOf(item) + 1;

    if (playSettings.shuffle) {
      playList.shuffle(new Random());
    }

    for (var i = 0; i < length; i++) {
      playQueue.add(playList.elementAt((index + i) % length));
    }

    print('New queue with ${playQueue.length} items from index $index');
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

  pause() async {
    await audioPlayer.pause();
    setState(() {
      activePlayListItem.pause();
      playerState = PlayerState.Paused;
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

    initDropBoxClient();
    initAudioPlayer();

    Storage.getInstance().then((storage) => this.storage = storage);

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
      List<String> localItems = await storage.listLocalItems(recursive: true);
      Set<PlayListItem> playListItems = entries.where((entry) =>
          entry.isAudioFile())
          .map((entry) {
        final local = localItems.firstWhere((item) =>
            item.endsWith(entry.pathLower), orElse: () => null);
        return new PlayListItem(entry.name, 'Me', entry.pathLower, downloaded: local != null);
      }).toSet();
      setState(() {
        items = playListItems;
      });
    }
  }

  void initDropBoxClient() {
    dropBox = new DropBox();
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
  PlayerState playerState = PlayerState.Stopped;
  bool downloaded = false;

  final iconSize = 32.0;

  PlayListItem(this.name, this.author, this.path, {downloaded: false}) {
    this.downloaded = downloaded;
  }

  void play(Duration duration) {
    this.position = new Duration();
    this.duration = duration;
    this.playerState = PlayerState.Playing;
  }

  void progress(Duration position) {
    this.position = position;
  }

  void stop() => this.playerState = PlayerState.Stopped;

  void pause() => this.playerState = PlayerState.Paused;

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
        icon: (playerState == PlayerState.Playing
            ? buildProgressIndicator()
            : (playerState == PlayerState.Paused
              ? new Icon(Icons.pause_circle_outline)
              : new Icon(Icons.play_circle_outline))),
        iconSize: iconSize,
        color: (downloaded == true ? Colors.green : Colors.blue),
        onPressed: () => playCallback(this),
      ),
    );
  }
}
