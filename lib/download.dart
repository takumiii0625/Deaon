import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'songdetailpage.dart';
import 'package:provider/provider.dart';
import 'providers/current_song_provide.dart';

class DownloadPage extends StatefulWidget {
  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  List<dynamic> downloads = [];
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
// フレームの描画後にCurrentSongProviderからダウンロードリストをロードする
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Providerを通じてCurrentSongProviderを取得
      await Provider.of<CurrentSongProvider>(context, listen: false)
          .loadDownloads();
      // CurrentSongProviderからダウンロードリストを取得して、ローカルのdownloadsリストを更新
      setState(() {
        downloads =
            Provider.of<CurrentSongProvider>(context, listen: false).downloads;
      });
    });
  }

  Future<void> removeDownload(String path) async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsFile = File('${dir.path}/downloads.json');

    if (await downloadsFile.exists()) {
      final content = await downloadsFile.readAsString();
      List<dynamic> currentDownloads = json.decode(content);
      currentDownloads.removeWhere((download) => download['path'] == path);
      await downloadsFile.writeAsString(json.encode(currentDownloads));

      // ファイルを実際に削除
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      // CurrentSongProviderからダウンロードリストを再ロード
      await Provider.of<CurrentSongProvider>(context, listen: false)
          .loadDownloads();

      // ローカルのdownloadsリストを更新
      setState(() {
        downloads =
            Provider.of<CurrentSongProvider>(context, listen: false).downloads;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ダウンロード一覧'),
      ),
      body: downloads.isEmpty
          ? Center(child: Text('ダウンロードした曲がありません'))
          : ListView.builder(
              itemCount: downloads.length,
              itemBuilder: (context, index) {
                final download = downloads[index];
                return ListTile(
                  leading: download['imageUrl'] != null
                      ? Image.network(download['imageUrl'],
                          width: 50, height: 50, fit: BoxFit.cover)
                      : null,
                  title: Text(download['songTitle'] ?? '不明な曲'),
                  subtitle: Text(download['artistName'] ?? '不明なアーティスト'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.play_arrow),
                        onPressed: () async {
                          // CurrentSongProviderを取得
                          final songProvider = Provider.of<CurrentSongProvider>(
                              context,
                              listen: false);
                          // 再生ソースを 'download' に設定

                          print(
                              "IconButton pressed: Attempting to play a song");

                          // ダウンロードされた曲のリストと現在の曲のインデックスを取得
                          List<dynamic> downloads = songProvider.downloads;
                          int index = downloads.indexWhere((downloadItem) =>
                              downloadItem['path'].trim() ==
                              download['path'].trim());

                          print("Index of the song to play: $index");

                          // 選択された曲の情報を設定
                          if (index != -1) {
                            print(
                                "Found song at index $index, setting current song and playing");
                            songProvider.setDownloadIndex(index); // 曲のインデックスを設定
                            songProvider.setCurrentSong(
                                downloads[index]['path'],
                                downloads[index]['songTitle'],
                                downloads[index]['artistName'],
                                downloads[index]['imageUrl']);

                            // 曲を再生
                            await songProvider.playDownloadedMusic(
                                downloads[index]['path'],
                                source: 'download');

                            // コントロールバーを表示
                            setState(() {
                              songProvider.isMusicStarted = true;
                              songProvider.playingSource = 'download';
                            });
                          } else {
                            print(
                                "downloadItem['path']: ${downloads.map((d) => d['path']).join(', ')}");
                            print("download['path']: ${download['path']}");
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              // ダイアログのUIを定義
                              return AlertDialog(
                                title: Text("確認"),
                                content: Text("このダウンロードを削除しますか？"),
                                actions: <Widget>[
                                  // キャンセルボタン
                                  TextButton(
                                    child: Text("キャンセル"),
                                    onPressed: () {
                                      Navigator.of(context).pop(); // ダイアログを閉じる
                                    },
                                  ),
                                  // 削除ボタン
                                  TextButton(
                                    child: Text("削除"),
                                    onPressed: () {
                                      // 実際の削除処理を呼び出し
                                      removeDownload(download['path']);
                                      Navigator.of(context).pop(); // ダイアログを閉じる
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
