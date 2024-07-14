import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:math';
import 'download.dart';
import 'artistpage.dart';
import 'search.dart';
import 'LikePage.dart';
import 'mypage.dart';
import 'HistoryPage.dart';
import 'providers/current_song_provide.dart';
import 'package:provider/provider.dart';

class Homeios extends StatefulWidget {
  @override
  _HomeiosState createState() => _HomeiosState();
}

class _HomeiosState extends State<Homeios> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSongProvider =
          Provider.of<CurrentSongProvider>(context, listen: false);
      currentSongProvider.initializeProvider();
    });
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    final currentSongProvider =
        Provider.of<CurrentSongProvider>(context, listen: false);
    currentSongProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CurrentSongProviderにアクセス
    final currentSongProvider = Provider.of<CurrentSongProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('digOn'),
      ),
      body: Center(
        child: currentSongProvider.selectedSongUrl == null
            ? CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (currentSongProvider.selectedImageUrl != null)
                    Image.network(
                      currentSongProvider.selectedImageUrl!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  Text(
                      currentSongProvider.selectedSongTitle ?? '曲名を取得できませんでした'),
                  Text(currentSongProvider.selectedArtistName ??
                      'アーティスト名を取得できませんでした'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 35, // アイコンサイズを大きくする
                        icon: Icon(Icons.skip_previous),
                        color: Color.fromARGB(255, 31, 184, 227), // ボタンの色を青にする
                        onPressed: () => currentSongProvider.backSong(),
                      ),
                      SizedBox(width: 20), // ボタン間のスペースを追加
                      IconButton(
                        iconSize: 35, // アイコンサイズを大きくする
                        icon: Icon(
                            currentSongProvider.isPlayingFromSource('home')
                                ? Icons.pause
                                : Icons.play_arrow),
                        color: Color.fromARGB(255, 31, 184, 227), // ボタンの色を青にする
                        onPressed: () {
                          if (currentSongProvider.isPlayingFromSource('home')) {
                            currentSongProvider.pauseMusic('home');
                          } else {
                            // 再開のためには一時停止状態である必要があるため、条件を追加して確認
                            if (currentSongProvider.homePlayer.state ==
                                PlayerState.PAUSED) {
                              currentSongProvider.resumeMusic('home');
                            } else {
                              // 状態がPAUSEDでない場合、新たに再生
                              currentSongProvider.playMusic('home');
                            }
                          }
                        },
                      ),
                      SizedBox(width: 20), // ボタン間のスペースを追加
                      IconButton(
                        iconSize: 35, // アイコンサイズを大きくする
                        icon: Icon(Icons.skip_next),
                        color: Color.fromARGB(255, 31, 184, 227), // ボタンの色を青にする
                        onPressed: () => currentSongProvider.nextSong(),
                      ),
                      SizedBox(width: 30), // ボタン間のスペースを追加
                      IconButton(
                        iconSize: 25, // アイコンサイズを大きくする
                        icon: Icon(Icons.download),
                        color: Color.fromARGB(255, 31, 184, 227), // ボタンの色を青にする
                        onPressed: () {
                          // コンテキストをメソッドに渡す
                          Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .downloadMusic(context);
                        },
                      )
                    ],
                  ),
                  Consumer<CurrentSongProvider>(
                    builder: (context, music, child) => Column(
                      children: [
                        // Sliderの実装
                        if (music.playingSource == 'home')
                          Slider(
                              value: min(
                                  music.currentPosition.inSeconds.toDouble(),
                                  music.songDuration.inSeconds.toDouble()),
                              max: music.songDuration.inSeconds.toDouble(),
                              onChanged: music.isPlayingFromSource('home')
                                  ? (value) {
                                      music.seek(
                                          Duration(seconds: value.toInt()));
                                    }
                                  : null, // ホームからの再生時のみ有効
                              activeColor: Color.fromARGB(255, 31, 184, 227),
                              inactiveColor: Colors.grey),
                        if (music.playingSource == 'home')
                          Text(
                            "${formatDuration(music.currentPosition)} / ${formatDuration(music.songDuration)}",
                            style: TextStyle(
                                color: const Color.fromARGB(255, 19, 19, 19)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      // Provider.ofを使い、listen: trueを設定してデータの変更を監視
                      Provider.of<CurrentSongProvider>(context, listen: true)
                              .isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Provider.of<CurrentSongProvider>(context,
                                  listen: true)
                              .isFavorite
                          ? Colors.red
                          : null,
                    ),
                    onPressed: () async {
                      // 現在選択されている曲のIDがnullでない場合に限り処理
                      if (Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .selectedSongId !=
                          null) {
                        Map<String, dynamic> songInfo = {
                          'songTitle': Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .selectedSongTitle,
                          'artistName': Provider.of<CurrentSongProvider>(
                                  context,
                                  listen: false)
                              .selectedArtistName,
                          'imageUrl': Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .selectedImageUrl,
                          'audioUrl': Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .selectedSongUrl,
                        };
                        await Provider.of<CurrentSongProvider>(context,
                                listen: false)
                            .toggleFavorite(
                                Provider.of<CurrentSongProvider>(context,
                                        listen: false)
                                    .selectedSongId!,
                                songInfo);
                      }
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArtistPage(
                            artistName:
                                currentSongProvider.selectedArtistName!),
                      ),
                    ),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          Color.fromARGB(255, 92, 206, 238)),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                      padding: MaterialStateProperty.all<EdgeInsets>(
                          EdgeInsets.symmetric(vertical: 10, horizontal: 20)),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      elevation: MaterialStateProperty.all<double>(5.0),
                    ),
                    child: Text('アーティストページへ'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HistoryPage(),
                      ),
                    ),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          Color.fromARGB(255, 87, 203, 235)),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                      padding: MaterialStateProperty.all<EdgeInsets>(
                          EdgeInsets.symmetric(vertical: 10, horizontal: 20)),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      elevation: MaterialStateProperty.all<double>(5.0),
                    ),
                    child: Text('履歴ページへ'),
                  ),
                ],
              ),
      ),
    );
  }
}
