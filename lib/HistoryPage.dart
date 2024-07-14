import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'providers/current_song_provide.dart';
import 'package:audioplayers/audioplayers.dart';
import 'artistpage.dart';

class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final AudioPlayer audioPlayer = AudioPlayer();
  String? currentPlayingUrl;

  Future<List<Map<String, dynamic>>> fetchSongsFromHistory() async {
    List<Map<String, dynamic>> songDetails = [];
    List<String> songHistory =
        Provider.of<CurrentSongProvider>(context, listen: false).songHistory;

    for (String songId in songHistory.reversed.take(10)) {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('uploads')
          .doc(songId)
          .get();
      if (docSnapshot.exists) {
        songDetails.add(docSnapshot.data() as Map<String, dynamic>);
      }
    }
    return songDetails;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchSongsFromHistory(), // Corrected method name here
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text('エラーが発生しました');
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          final songs = snapshot.data!;

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final songId = song['songId']; // 曲ID

              return ListTile(
                leading: song['imageUrl'] != null
                    ? Image.network(song['imageUrl'],
                        width: 100, height: 100, fit: BoxFit.cover)
                    : Icon(Icons.music_note),
                title: Text(song['songTitle']),
                subtitle: Text(song['artistName']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        currentPlayingUrl == song['audioUrl']
                            ? Icons.stop
                            : Icons.play_arrow,
                      ),
                      onPressed: () async {
                        if (currentPlayingUrl == song['audioUrl']) {
                          await Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .stopAllMusic();
                          setState(() {
                            currentPlayingUrl = null;
                          });
                        } else {
                          await Provider.of<CurrentSongProvider>(context,
                                  listen: false)
                              .playMusicFromSearchPage(song['audioUrl']);
                          setState(() {
                            currentPlayingUrl = song['audioUrl'];
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.person),
                      tooltip: 'Go to Artist Page', // ツールチップを追加
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ArtistPage(artistName: song['artistName']),
                          ),
                        );
                      },
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
