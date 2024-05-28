import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:audioplayers/audioplayers.dart';

class AdminHomeScreen extends StatelessWidget {
  final AudioPlayer audioPlayer = AudioPlayer();

  // ユーザーデータを取得するためのストリーム
  Stream<QuerySnapshot> getUsersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  // 楽曲データを取得するためのストリーム
  Stream<QuerySnapshot> getUploadsStream() {
    return FirebaseFirestore.instance.collection('uploads').snapshots();
  }

  Future<void> deleteUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    // 関連する楽曲データも削除する処理を追加する場合はここにコードを記述
  }

  Future<void> deleteSong(String docId, String imageUrl) async {
    await FirebaseFirestore.instance.collection('uploads').doc(docId).delete();
    if (imageUrl.isNotEmpty) {
      await FirebaseStorage.instance.refFromURL(imageUrl).delete();
    }
  }

  Future<void> confirmDelete(
      BuildContext context, VoidCallback onConfirm) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('確認'),
          content: Text('本当に削除してもよろしいですか？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('いいえ'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('はい'),
            ),
          ],
        );
      },
    );

    if (isConfirmed ?? false) {
      onConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('管理者ホーム'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('ユーザー一覧', style: Theme.of(context).textTheme.headline6),
          ),
          Expanded(
            flex: 1, // ユーザー一覧と楽曲一覧の表示比を調整可能
            child: StreamBuilder<QuerySnapshot>(
              stream: getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('エラーが発生しました');
                }
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final userDocs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: userDocs.length,
                  itemBuilder: (context, index) {
                    final userDoc = userDocs[index];
                    return ListTile(
                      title: Text(userDoc['email'] ?? 'メールアドレス不明'),
                      subtitle: Text(
                          'アーティスト名: ${userDoc['artistName'] ?? '未設定'}\n' +
                              '登録日時: ${userDoc['createdAt'].toDate().toString()}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => confirmDelete(
                            context, () => deleteUser(userDoc.id)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('楽曲一覧', style: Theme.of(context).textTheme.headline6),
          ),
          Expanded(
            flex: 2, // 楽曲一覧の表示領域をユーザー一覧よりも大きくする
            child: StreamBuilder<QuerySnapshot>(
              stream: getUploadsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('エラーが発生しました');
                }
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final songDocs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: songDocs.length,
                  itemBuilder: (context, index) {
                    final songDoc = songDocs[index];
                    // TimestampからDateTimeに変換し、文字列としてフォーマット
                    String uploadedAt =
                        songDoc['uploadedAt']?.toDate()?.toString() ?? '不明';

                    return ListTile(
                      leading: songDoc['imageUrl'] != null
                          ? Image.network(songDoc['imageUrl'],
                              width: 100, height: 100, fit: BoxFit.cover)
                          : null,
                      title: Text(songDoc['songTitle'] ?? 'タイトル不明'),
                      // アーティスト名と登録日時を表示
                      subtitle: Text(
                          '${songDoc['artistName'] ?? 'アーティスト不明'}\n登録日時: $uploadedAt'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => confirmDelete(
                            context,
                            () => deleteSong(
                                songDoc.id, songDoc['imageUrl'] ?? '')),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
