import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'providers/current_song_provide.dart';
import 'songdetailpage.dart';
import 'package:collection/collection.dart';

class LikePage extends StatefulWidget {
  @override
  _LikePageState createState() => _LikePageState();
}

class _LikePageState extends State<LikePage> {
  List<dynamic> favorites = [];
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> clearFavorites() async {
    final dir = await getApplicationDocumentsDirectory();
    final favoriteFile = File('${dir.path}/favorites.json');
    // 空のリストをファイルに書き込むことで、お気に入りリストをクリアする
    await favoriteFile.writeAsString(json.encode([]));
    setState(() {
      favorites = []; // UIも更新する
    });
  }

  Future<void> loadFavorites() async {
    final dir = await getApplicationDocumentsDirectory();
    final favoriteFile = File('${dir.path}/favorites.json');
    if (await favoriteFile.exists()) {
      final content = await favoriteFile.readAsString();
      final List<dynamic> decodedList = json.decode(content);
      // 各要素をMap<String, dynamic>にキャストする
      favorites =
          decodedList.map((item) => item as Map<String, dynamic>).toList();
      setState(() {});
    }
    print("Loaded favorites: $favorites");
  }

  Future<void> removeFromFavorites(int index) async {
    favorites.removeAt(index);
    final dir = await getApplicationDocumentsDirectory();
    final favoriteFile = File('${dir.path}/favorites.json');
    await favoriteFile.writeAsString(json.encode(favorites));
    setState(() {});
    // お気に入りの変更を全体に通知
    Provider.of<CurrentSongProvider>(context, listen: false)
        .loadFavorites(); // お気に入りデータを再読込して通知
  }

  @override
  Widget build(BuildContext context) {
    final currentSongProvider = Provider.of<CurrentSongProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('お気に入り'),
        // actions: [
        // IconButton(
        // icon: Icon(Icons.delete),
        //onPressed: clearFavorites, // お気に入りをクリアするボタンを追加
        //),
        //],
      ),
      body: favorites.isEmpty
          ? Center(child: Text('お気に入りがありません'))
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return ListTile(
                  leading: favorite['imageUrl'] != null
                      ? Image.network(favorite['imageUrl'],
                          width: 50, height: 50, fit: BoxFit.cover)
                      : Icon(Icons.music_note),
                  title: Text(favorite['songTitle'] ?? '曲名不明'),
                  subtitle: Text(favorite['artistName'] ?? 'アーティスト不明'),
                  trailing: Wrap(
                    children: [
                      Consumer<CurrentSongProvider>(
                        builder: (context, currentSongProvider, child) {
                          bool isCurrentSong =
                              currentSongProvider.selectedSongUrl ==
                                  favorite['audioUrl'];
                          bool isPlaying =
                              isCurrentSong && currentSongProvider.isPlaying;

                          return IconButton(
                            icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: () {
                              if (isPlaying) {
                                currentSongProvider.pauseMusic('likePage');
                              } else {
                                currentSongProvider.playFavoriteSong(favorite);
                              }
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.download),
                        onPressed: () {
                          var songInfo = {
                            'songTitle': favorite['songTitle'],
                            'artistName': favorite['artistName'],
                            'imageUrl': favorite['imageUrl'],
                            'audioUrl': favorite['audioUrl'],
                          };
                          Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .downloadFavoriteSong(context, songInfo);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.favorite, color: Colors.red),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: Text('確認'),
                            content: Text('お気に入りから削除してもよろしいですか？'),
                            actions: <Widget>[
                              TextButton(
                                child: Text('キャンセル'),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              TextButton(
                                child: Text('削除'),
                                onPressed: () {
                                  removeFromFavorites(index);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
