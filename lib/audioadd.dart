import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data'; // Uint8Listを使用するために必要
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AudioAdd extends StatefulWidget {
  @override
  _AudioAddState createState() => _AudioAddState();
}

class _AudioAddState extends State<AudioAdd> {
  final TextEditingController _songController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  Uint8List? audioBytes;
  String? audioFileName;
  Uint8List? imageBytes;
  String? imageFileName;
  bool isLoading = false; // ローディング状態

  @override
  void dispose() {
    _songController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchArtistName();
  }

  // ユーザーのアーティスト名を取得し、_artistControllerに設定するメソッド
  Future<void> fetchArtistName() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final artistName = userDoc.data()?['artistName'];
        if (artistName != null) {
          setState(() {
            _artistController.text = artistName; // アーティスト名をテキストフィールドに設定
          });
        }
      } catch (e) {
        print("アーティスト名の取得に失敗しました: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("楽曲登録"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading ? CircularProgressIndicator() : buildForm(user),
      ),
    );
  }

  Widget buildForm(User? user) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          TextField(
            controller: _songController,
            decoration: InputDecoration(labelText: '楽曲名'),
          ),
          TextField(
            controller: _artistController,
            decoration: InputDecoration(labelText: 'アーティスト名'),
            enabled: false, // ユーザーの入力を受け付けないようにする
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => pickFile(FileType.audio),
            child: Text('音楽ファイルを選択'),
          ),
          if (audioFileName != null) Text("選択された音楽ファイル: $audioFileName"),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => pickFile(FileType.image),
            child: Text('写真ファイルを選択'),
          ),
          if (imageBytes != null) Image.memory(imageBytes!, height: 150),
          if (imageFileName != null) Text("選択された画像ファイル: $imageFileName"),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: user != null ? () => uploadFiles(user) : null,
            child: Text('アップロード'),
          ),
        ],
      ),
    );
  }

  Future<void> pickFile(FileType fileType) async {
    final result =
        await FilePicker.platform.pickFiles(type: fileType, withData: true);
    if (result != null) {
      setState(() {
        if (fileType == FileType.audio) {
          audioBytes = result.files.single.bytes;
          audioFileName = result.files.single.name;
        } else {
          imageBytes = result.files.single.bytes;
          imageFileName = result.files.single.name;
        }
      });
    }
  }

  Future<void> uploadFiles(User user) async {
    setState(() {
      isLoading = true; // ローディング開始
    });
    try {
      // 音楽ファイルのアップロード
      String? audioUrl;
      if (audioBytes != null && audioFileName != null) {
        final audioRef = FirebaseStorage.instance.ref('audio/$audioFileName');
        await audioRef.putData(audioBytes!);
        audioUrl = await audioRef.getDownloadURL();
      }

      // 写真ファイルのアップロード
      String? imageUrl;
      if (imageBytes != null && imageFileName != null) {
        final imageRef = FirebaseStorage.instance.ref('images/$imageFileName');
        await imageRef.putData(imageBytes!);
        imageUrl = await imageRef.getDownloadURL();
      }

      // Firestoreに楽曲情報を保存します。
      // Firestoreに楽曲情報を保存
      await FirebaseFirestore.instance.collection('uploads').add({
        'userId': user.uid, // ユーザーIDを追加
        'songTitle': _songController.text,
        'artistName': _artistController.text,
        'audioUrl': audioUrl,
        'imageUrl': imageUrl,
        'uploadedAt': DateTime.now(),
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('アップロード成功')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('アップロード失敗: $e')));
    } finally {
      setState(() {
        isLoading = false; // ローディング終了
      });
    }
  }
}
