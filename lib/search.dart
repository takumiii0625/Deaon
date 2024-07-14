import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers/current_song_provide.dart'; // Providerをインポート（パスを確認してください）
import 'package:firebase_core/firebase_core.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:convert';
import 'artistpage.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final AudioPlayer audioPlayer = AudioPlayer();
  String searchQuery = '';
  String? currentPlayingUrl; // 現在再生中の曲のURLを保持する変数

  Stream<QuerySnapshot> getUploadsStream() {
    if (searchQuery.isEmpty) {
      return FirebaseFirestore.instance.collection('uploads').snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('uploads')
          .where('artistName', isEqualTo: searchQuery)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration(
            hintText: 'アーティスト名で検索',
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value.trim();
            });
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getUploadsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('エラーが発生しました');
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final documents = snapshot.data!.docs;

          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              final songId = doc.id;
              final songInfo = {
                'songId': songId,
                'songTitle': doc['songTitle'],
                'artistName': doc['artistName'],
                'imageUrl': doc['imageUrl'],
                'audioUrl': doc['audioUrl'],
              };

              return ListTile(
                leading: doc['imageUrl'] != null
                    ? Image.network(doc['imageUrl'],
                        width: 100, height: 100, fit: BoxFit.cover)
                    : Icon(Icons.music_note),
                title: Text(doc['songTitle'] ?? 'タイトル不明'),
                subtitle: Text(doc['artistName'] ?? 'アーティスト不明'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 再生ボタン
                    IconButton(
                      icon: Icon(
                        currentPlayingUrl == doc['audioUrl']
                            ? Icons.stop
                            : Icons.play_arrow,
                      ),
                      onPressed: () async {
                        if (currentPlayingUrl == doc['audioUrl']) {
                          await Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .stopAllMusic();
                          setState(() {
                            currentPlayingUrl = null;
                          });
                        } else {
                          await Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .playMusicFromSearchPage(doc['audioUrl']);
                          setState(() {
                            currentPlayingUrl = doc['audioUrl'];
                          });
                        }
                      },
                    ),

                    // お気に入りボタン
                    IconButton(
                      icon: Icon(
                        Provider.of<CurrentSongProvider>(context, listen: true)
                                .isSongFavorite(songId)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Provider.of<CurrentSongProvider>(context,
                                    listen: true)
                                .isSongFavorite(songId)
                            ? Colors.red
                            : null,
                      ),
                      onPressed: () {
                        Map<String, dynamic> songInfo = {
                          'songTitle': doc['songTitle'],
                          'artistName': doc['artistName'],
                          'imageUrl': doc['imageUrl'],
                          'audioUrl': doc['audioUrl'],
                        };
                        Provider.of<CurrentSongProvider>(context, listen: false)
                            .toggleFavorite(songId, songInfo);
                      },
                    ),
                    // ポップアップメニューボタン
                    PopupMenuButton<int>(
                      icon: Icon(Icons.more_vert), // 3点リーダのアイコン
                      onSelected: (int result) {
                        switch (result) {
                          case 1:
                            Provider.of<CurrentSongProvider>(context,
                                    listen: false)
                                .downloadSearchedSong(context, {
                              'songTitle': doc['songTitle'],
                              'artistName': doc['artistName'],
                              'imageUrl': doc['imageUrl'],
                              'audioUrl': doc['audioUrl'],
                            });
                            break;
                          case 2:
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ArtistPage(artistName: doc['artistName']),
                              ),
                            );
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<int>>[
                        PopupMenuItem<int>(
                          value: 1,
                          child: Row(
                            children: [
                              Icon(Icons.download), // Download用のアイコン
                              SizedBox(width: 8), // アイコンとテキストの間隔
                              Text('Download'),
                            ],
                          ),
                        ),
                        PopupMenuItem<int>(
                          value: 2,
                          child: Row(
                            children: [
                              Icon(Icons.person), // Artist Page用のアイコン
                              SizedBox(width: 8), // アイコンとテキストの間隔
                              Text('Artist Page'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
