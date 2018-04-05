import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './properties.dart';
import './dropbox.dart';
import './storage.dart';

class Settings extends StatefulWidget {
  @override
  State createState() => new SettingsState();
}

class SettingsState extends State<Settings> {
  // Part of state
  DropBox dropBox;
  Storage storage;
  String folder;
  bool showDropBoxFolders;
  num downloadedItemCount = 0;
  bool repeat = false;
  bool shuffle = false;
  List<String> dropBoxFolders = [];

  SettingsState() : super() {
    dropBox = new DropBox();
  }

  _configureFolder() async {
    List<Entry> folders = await dropBox.listFolder('');

    this.dropBoxFolders = folders
        .where((folder) => folder.isFolder())
        .map((folder) => folder.pathDisplay)
        .toList();

    setState(() {
      showDropBoxFolders = true;
    });
  }

  _onFolderSelected(String folder) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.setString(prefsFolderKey, folder);
    preferences.commit();
    setState(() {
      this.folder = folder;
      this.showDropBoxFolders = false;
    });
  }

  _clearDownloadedItems() async {
    await storage.clearLocalItems();

    setState(() {
      this.downloadedItemCount = 0;
    });
  }

  _onRepeatChanged(repeat) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.setBool(prefsRepeatKey, repeat);
    preferences.commit();
    setState(() {
      this.repeat = repeat;
    });
  }

  _onShuffleChanged(shuffle) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.setBool(prefsShuffleKey, shuffle);
    preferences.commit();
    setState(() {
      this.shuffle = shuffle;
    });
  }

  _buildSettingsUI() {
    final configureButton = new FlatButton(
        child: new Text('CONFIGURE', style: new TextStyle(fontWeight: FontWeight.bold)),
        textColor: Colors.blue,
        onPressed: _configureFolder);
    final clearDownloadedItemsButton = new FlatButton(
      onPressed: _clearDownloadedItems,
      disabledTextColor: Colors.grey[400],
      child: new Text('CLEAR ITEMS', style: new TextStyle(fontWeight: FontWeight.bold)),
      textColor: Colors.blue,
    );

    final valueStyle =
        new TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600);

    List<Widget> widgets = [
      new Container(
          padding: new EdgeInsets.all(padding - 4.0),
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              new Text(
                'Folder',
                style: valueStyle,
              ),
              new Row(
                children: <Widget>[
                  (this.folder != null
                      ? new Text(
                          this.folder,
                          style: valueStyle,
                        )
                      : new Container()),
                  configureButton
                ],
              )
            ],
          )),
      new Divider(),
      new Container(
        padding: new EdgeInsets.all(padding - 4.0),
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            new Text(
              'Downloaded Items',
              style: valueStyle,
            ),
            new Row(
              children: <Widget>[
                new Text(
                  '$downloadedItemCount',
                  style: valueStyle,
                ),
                clearDownloadedItemsButton
              ],
            )
          ],
        ),
      ),
      new Divider(),
      new Container(
        padding: new EdgeInsets.symmetric(horizontal: padding),
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            new Text(
              'Repeat',
              style: valueStyle,
            ),
            new Switch(value: this.repeat, onChanged: _onRepeatChanged)
          ],
        ),
      ),
      new Divider(),
      new Container(
        padding: new EdgeInsets.symmetric(horizontal: padding),
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            new Text(
              'Shuffle',
              style: valueStyle,
            ),
            new Switch(value: this.shuffle, onChanged: _onShuffleChanged)
          ],
        ),
      ),
      new Divider()
    ];

    if (showDropBoxFolders) {
      widgets.add(new Container(
        constraints: new BoxConstraints.tight(new Size.fromHeight(295.0)),
        child: new ListView(
          padding: new EdgeInsets.all(paddingSmall),
          children: _buildDropBoxFolders(),
        ),
      ));
    }

    return widgets;
  }

  _buildDropBoxFolders() {
    final tiles = dropBoxFolders.map((folder) => new ListTile(
          leading: new Icon(
            Icons.folder,
            size: headerSize,
          ),
          title: new Text(folder),
          trailing: new Radio(
              groupValue: this.folder,
              value: folder,
              onChanged: _onFolderSelected),
        ));
    final divided = ListTile.divideTiles(context: context, tiles: tiles);

    return divided.toList();
  }

  @override
  void initState() {
    super.initState();
    showDropBoxFolders = false;
    SharedPreferences.getInstance().then((preferences) {
      this.folder = preferences.getString(prefsFolderKey) ?? '';
      this.repeat = preferences.get(prefsRepeatKey) ?? false;
      this.shuffle = preferences.get(prefsShuffleKey) ?? false;
    });

    Storage.getInstance().then((storage) {
      this.storage = storage;
      return storage.listLocalItems(recursive: true);
    }).then((items) => this.downloadedItemCount = items.length);
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Dropbox Settings'),
      ),
      body: new Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: _buildSettingsUI(),
      ),
    );
  }
}
