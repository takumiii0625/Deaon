import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'dart:convert'; // JSON操作用
import 'package:provider/provider.dart';
import 'providers/current_song_provide.dart';

class ArtistPage extends StatefulWidget {
  final String artistName;

  ArtistPage({required this.artistName});

  @override
  _ArtistPageState createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final AudioPlayer audioPlayer = AudioPlayer();
  String? _currentPlayingUrl;

  Future<void> saveDownloadInfo(Map<String, dynamic> downloadInfo) async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsFile = File('${dir.path}/downloads.json');

    List<dynamic> downloads = [];
    if (await downloadsFile.exists()) {
      final content = await downloadsFile.readAsString();
      downloads = json.decode(content);
    }

    downloads.add(downloadInfo);
    await downloadsFile.writeAsString(json.encode(downloads));
  }

  @override
  Widget build(BuildContext context) {
    final currentSongProvider = Provider.of<CurrentSongProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artistName),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('uploads')
            .where('artistName', isEqualTo: widget.artistName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text('エラーが発生しました');
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final documents = snapshot.data!.docs;

          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              bool isCurrentPlaying = _currentPlayingUrl == doc['audioUrl'];
              String songId = doc.id; // 曲ID

              return ListTile(
                leading: doc['imageUrl'] != null
                    ? Image.network(doc['imageUrl'],
                        width: 100, height: 100, fit: BoxFit.cover)
                    : null,
                title: Text(doc['songTitle']),
                subtitle: Text(doc['artistName']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                          isCurrentPlaying ? Icons.stop : Icons.play_arrow),
                      onPressed: () async {
                        if (isCurrentPlaying) {
                          await Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .stopAllMusic();
                          setState(() {
                            _currentPlayingUrl = null;
                          });
                        } else {
                          await Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .playMusicFromArtistPage(doc['audioUrl']);
                          setState(() {
                            _currentPlayingUrl = doc['audioUrl'];
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        currentSongProvider.isSongFavorite(songId)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: currentSongProvider.isSongFavorite(songId)
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
                        currentSongProvider.toggleFavorite(songId, songInfo);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.download),
                      onPressed: () {
                        // コンテキストをメソッドに渡す
                        Provider.of<CurrentSongProvider>(context, listen: false)
                            .downloadMusic(context);
                      },
                    )
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
