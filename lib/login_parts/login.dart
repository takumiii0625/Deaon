import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'authentication_error.dart';
import 'registration.dart';
import '../../home.dart';
import 'email_check.dart';
import 'admin_home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Login extends StatefulWidget {
  @override
  _Login createState() => _Login();
}

class _Login extends State<Login> {
  // Firebase 認証
  final _auth = FirebaseAuth.instance;

  String _login_Email = ""; // 入力されたメールアドレス
  String _login_Password = ""; // 入力されたパスワード
  String _infoText = ""; // ログインに関する情報を表示

  // エラーメッセージを日本語化するためのクラス
  final auth_error = Authentication_error_to_ja();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // メールアドレスの入力フォーム
            Padding(
                padding: EdgeInsets.fromLTRB(25.0, 0, 25.0, 0),
                child: TextFormField(
                  decoration: InputDecoration(labelText: "メールアドレス"),
                  onChanged: (String value) {
                    _login_Email = value;
                  },
                )),

            // パスワードの入力フォーム
            Padding(
              padding: EdgeInsets.fromLTRB(25.0, 0, 25.0, 10.0),
              child: TextFormField(
                decoration: InputDecoration(labelText: "パスワード（8～20文字）"),
                obscureText: true, // パスワードが見えないようRにする
                maxLength: 20, // 入力可能な文字数
                // maxLength: 20, // 入力可能な文字数の制限を20文字に設定
                onChanged: (String value) {
                  _login_Password = value;
                },
              ),
            ),

            // ログイン失敗時のエラーメッセージ
            Padding(
              padding: EdgeInsets.fromLTRB(20.0, 0, 20.0, 5.0),
              child: Text(
                _infoText,
                style: TextStyle(color: Colors.red),
              ),
            ),

            // ログインボタンの配置
            SizedBox(
              width: 350.0,
              // height: 100.0,
              child: ElevatedButton(
                // ボタンの形状や背景色など
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue, // background-color
                  onPrimary: Colors.white, //text-color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // ボタン内の文字と書式
                child: Text(
                  'ログイン',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                onPressed: () async {
                  try {
                    // メール/パスワードでログイン
                    UserCredential _result =
                        await _auth.signInWithEmailAndPassword(
                      email: _login_Email,
                      password: _login_Password,
                    );

                    // ログイン成功
                    User _user = _result.user!; // ログインユーザーのIDを取得

                    // ユーザーのドキュメントを Firestore から取得
                    DocumentSnapshot userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_user.uid)
                        .get();

                    // ドキュメントから isAdmin フィールドを読み取る
                    bool isAdmin =
                        (userDoc.data() as Map<String, dynamic>)['isAdmin'] ??
                            false;

                    // Email確認が済んでいるかつ、isAdmin が true の場合は管理者画面へ遷移
                    if (_user.emailVerified && isAdmin) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdminHomeScreen(), // 管理者用ホーム画面に遷移
                        ),
                      );
                    } else if (_user.emailVerified) {
                      // 通常のユーザーで Email 確認済みの場合は通常のホーム画面へ
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              Home(userId: _user.uid, auth: _auth),
                        ),
                      );
                    } else {
                      // Email 確認が未完了の場合
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Emailcheck(
                              email: _login_Email,
                              pswd: _login_Password,
                              from: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    // ログインに失敗した場合
                    setState(() {
                      _infoText =
                          auth_error.login_error_msg(e.hashCode, e.toString());
                    });
                  }
                },
              ),
            ),

            // ログイン失敗時のエラーメッセージ
            TextButton(
              child: Text('上記メールアドレスにパスワード再設定メールを送信'),
              onPressed: () =>
                  _auth.sendPasswordResetEmail(email: _login_Email),
            ),
          ],
        ),
      ),

      // 画面下にアカウント作成画面への遷移ボタンを配置
      bottomNavigationBar:
          Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: 350.0,
            // height: 100.0,
            child: ElevatedButton(
                // ボタンの形状や背景色など
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue[50], // background-color
                  onPrimary: Colors.blue, //text-color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'アカウントを作成する',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                // ボタンクリック後にアカウント作成用の画面の遷移する。
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (BuildContext context) => Registration(),
                    ),
                  );
                }),
          ),
        ),
      ]),
    );
  }
}
