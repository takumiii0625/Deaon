import 'package:flutter/foundation.dart';

class SubscriptionProvider with ChangeNotifier {
  bool _isSubscribed = false; // ユーザーのサブスクリプション状態

  bool get isSubscribed => _isSubscribed;

  void subscribe() {
    _isSubscribed = true;
    notifyListeners(); // 状態が更新されたことをリスナーに通知
  }

  void unsubscribe() {
    _isSubscribed = false;
    notifyListeners(); // 状態が更新されたことをリスナーに通知
  }
}
