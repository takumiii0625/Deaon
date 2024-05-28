import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<UserRecord> _userRecords = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    // Firebase Admin SDKや独自API経由でユーザーリストを取得するロジックをここに実装
    // この例では、モックとして空のリストを設定しています
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("管理者画面"),
      ),
      body: ListView.builder(
        itemCount: _userRecords.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_userRecords[index].email),
            // 他にもユーザー情報を表示する
          );
        },
      ),
    );
  }
}

class UserRecord {
  final String uid;
  final String email;
  // 必要に応じて他のフィールドを追加

  UserRecord({required this.uid, required this.email});
}
