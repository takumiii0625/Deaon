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
            ElevatedButton(
              onPressed: () {
                if (subscriptionProvider.isSubscribed) {
                  subscriptionProvider.unsubscribe();
                } else {
                  subscriptionProvider.subscribe();
                }
              },
              child: Text(subscriptionProvider.isSubscribed ? '登録解除' : '登録'),
            ),
          ],
        ),
      ),
    );
  }
}
