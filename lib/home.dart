import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audioadd.dart'; // AudioAdd.dartファイルをインポート
import 'package:file_picker/file_picker.dart';

// [Themelist] インスタンスにおける処理。
class Home extends StatelessWidget {
  final String? userId; // ユーザーIDを保持するための変数

  final FirebaseAuth auth;

  Home({Key? key, required this.auth, this.userId}) : super(key: key);

  //AudioPlayerのインスタンスを生成
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  Widget build(BuildContext context) {
    // 現在ログインしているユーザーのIDを取得
    final String userId = auth.currentUser?.uid ?? '';

    return Scaffold(
      // Header部分
      appBar: AppBar(
        leading: Icon(Icons.home),
        title: Text('ログイン後の画面'),
        backgroundColor: Colors.black87,
        centerTitle: true,
        elevation: 0.0,

        // 右上メニューボタン
        actions: <Widget>[
          // overflow menu
          PopupMenuButton<String>(
            icon: Icon(Icons.menu),
            onSelected: (String s) {
              if (s == 'ログアウト') {
                auth.signOut();
                Navigator.of(context).pushNamed("/login");
              }
            },
            itemBuilder: (BuildContext context) {
              return ['テスト', 'ログアウト'].map((String s) {
                return PopupMenuItem(
                  child: Text(s),
                  value: s,
                );
              }).toList();
            },
          ),
        ],
      ),

      // メイン画面
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('登録した楽曲一覧',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(userId),
            // 楽曲一覧表示
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // ログインユーザーがアップロードした曲のみをフィルタリング
                stream: FirebaseFirestore.instance
                    .collection('uploads')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      Map<String, dynamic> data =
                          doc.data() as Map<String, dynamic>;

                      return ListTile(
                        //画像を表示する
                        leading: data['imageUrl'] != null
                            ? Image.network(
                                data['imageUrl'],
                                width: 100, // 画像の幅
                                height: 100, // 画像の高さ
                                fit: BoxFit.cover, // 画像のフィット
                              )
                            : null, // 画像URLがない場合は何も表示しない
                        title: Text(data['songTitle']),
                        subtitle: Text(data['artistName']),

                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.play_arrow),
                              onPressed: () => playMusic(data['audioUrl']),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () => deleteMusic(doc.id, context),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => AudioAdd())),
        child: Icon(Icons.add),
        tooltip: '楽曲を追加',
      ),
    );
  }

  // 音楽を再生するメソッド
  void playMusic(String audioUrl) async {
    if (audioUrl.isNotEmpty) {
      try {
        await audioPlayer.play(audioUrl);
      } catch (e) {
        print('音楽の再生に失敗しました: $e');
      }
    }
  }

  Future<void> deleteMusic(String docId, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('uploads')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('楽曲が削除されました')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('楽曲の削除に失敗しました: $e')));
    }
  }
}
