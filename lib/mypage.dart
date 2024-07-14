import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/subscription_provider.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('マイページ'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(subscriptionProvider.isSubscribed
                ? 'サブスクリプション登録済み'
                : 'サブスクリプション未登録'),
            SizedBox(height: 20), // ボタンの上に20ピクセルの空間を追加
            ElevatedButton(
              onPressed: () {
                if (subscriptionProvider.isSubscribed) {
                  subscriptionProvider.unsubscribe();
                } else {
                  subscriptionProvider.subscribe();
                }
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(
                    Color.fromARGB(255, 2, 194, 247)), // ボタンの背景色を青にする
                foregroundColor: MaterialStateProperty.all<Color>(
                    Colors.white), // ボタンの文字色を白にする
                padding: MaterialStateProperty.all<EdgeInsets>(
                    EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 30.0)), // ボタンのパディングを設定
                minimumSize: MaterialStateProperty.all<Size>(
                    Size(80, 30)), // ボタンの最小サイズを設定
              ),
              child: Text(
                subscriptionProvider.isSubscribed ? '登録解除' : '登録\n(500円/月)',
                textAlign: TextAlign.center, // テキストを中央揃えにする
                maxLines: 2, // 最大行数を設定
              ),
            ),
          ],
        ),
      ),
    );
  }
}
