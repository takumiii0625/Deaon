import 'package:flutter/foundation.dart'; // kIsWebを使用するために必要
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_parts/login.dart';
import 'firebase_options.dart'; // Firebaseの設定を含むファイル
import 'home.dart'; // ログイン後に表示するホーム画面のウィジェットをインポート
import 'home_ios.dart'; // `Homeios`クラスを定義したファイルをインポート
import 'LikePage.dart';
import 'search.dart';
import 'artistpage.dart';
import 'download.dart';
import 'mypage.dart';
import 'package:provider/provider.dart';
import 'providers/current_song_provide.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'music_detail_screen.dart';
import 'providers/subscription_provider.dart';

void printFavoritesFilePath() async {
  if (!kIsWeb) {
    // Webではない場合のみ実行
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    final favoritesFilePath = File('$path/favorites.json');
    print('favorites.json file path: ${favoritesFilePath.path}');
  } else {
    print('Web platform does not support path_provider.');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutterエンジンの初期化を確実に行う
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // プラットフォームに適した設定を使用
  );

  // Web版の場合、CurrentSongProviderの初期化やloadDownloadsを呼び出さない
  if (!kIsWeb) {
    var currentSongProvider = CurrentSongProvider();
    await currentSongProvider.loadDownloads(); // ロード処理を待つ

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => currentSongProvider),
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ],
        child: MyAppHome(),
      ),
    );
  } else {
    // Web版の場合、ログイン画面を表示
    runApp(MyApp());
  }
}

// ログイン不要で直接ホーム画面にアクセスするiOS/Android版用のアプリ
class MyAppHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home_ios',
      home: SplashScreen(), // スプラッシュスクリーンを最初に表示
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth',
      home: Login(),
      routes: <String, WidgetBuilder>{
        '/login': (_) => new Login(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) {
          final currentSongProvider =
              Provider.of<CurrentSongProvider>(context, listen: false);
          currentSongProvider.initializeProvider(autoPlay: true); // 自動再生を有効にする
          return MainScreen();
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset('assets/splash_image.png'), // スプラッシュ画像を表示
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _widgetOptions = [
    Homeios(),
    LikePage(),
    SearchPage(),
    DownloadPage(),
    MyPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // フレームワークがフレームの描画を終えた後に、お気に入りの状態をロードする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSongProvider =
          Provider.of<CurrentSongProvider>(context, listen: false);
      currentSongProvider.initializeProvider(autoPlay: false); // ここでは自動再生しない

      Provider.of<CurrentSongProvider>(context, listen: false).loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<CurrentSongProvider>(context);
    bool isPlaying = songProvider.isPlaying; // 現在再生中かどうかを取得

    return Scaffold(
      body: Stack(
        children: <Widget>[
          _widgetOptions.elementAt(_selectedIndex), // 現在選択されているページのウィジェット
          if (songProvider.isMusicStarted &&
              songProvider.playingSource == 'download') // コントロールバーを表示する条件
            Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (BuildContext context) =>
                        MusicDetailScreen(), // 音楽詳細コンテンツを表示するウィジェット
                  );
                },
                child: Container(
                  height: 100, // コントロールバーの高さを100に調整
                  color: Color.fromARGB(255, 3, 181, 252)
                      .withOpacity(0.7), // 高級感のある濃い青色に変更
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // タイトルとアーティスト名の表示
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              songProvider.currentSong['songTitle'] ?? '曲名不明',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Color.fromARGB(
                                      255, 249, 248, 246)), // ゴールドカラーに変更
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              songProvider.currentSong['artistName'] ??
                                  'アーティスト不明',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Color.fromARGB(
                                      255, 248, 249, 246)), // 明るい緑色に変更
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // コントロールボタン
                      // コントロールボタン
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          IconButton(
                            iconSize: 30, // アイコンサイズを大きくする
                            icon: Icon(Icons.skip_previous,
                                color: Color.fromARGB(
                                    255, 255, 255, 255)), // サーモンピンク色に変更
                            onPressed: () =>
                                songProvider.playPreviousDownload(),
                          ),
                          IconButton(
                            iconSize: 30, // アイコンサイズを大きくする
                            icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Color.fromARGB(
                                    255, 251, 254, 254)), // 淡い青色に変更
                            onPressed: () {
                              if (isPlaying) {
                                songProvider
                                    .pauseDownloadMusic(); // ここをpauseMusicに修正
                              } else {
                                songProvider.resumeDownloadMusic();
                              }
                            },
                          ),
                          IconButton(
                            iconSize: 30, // アイコンサイズを大きくする
                            icon: Icon(Icons.skip_next,
                                color: Color.fromARGB(
                                    255, 245, 247, 248)), // ラベンダー色に変更
                            onPressed: () => songProvider.playNextDownload(),
                          ),
                          IconButton(
                            iconSize: 30, // アイコンサイズを大きくする
                            icon: Icon(Icons
                                .keyboard_arrow_up), // Material Icons の矢印アップ
                            color: Colors.white,
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (BuildContext context) =>
                                    MusicDetailScreen(),
                              );
                            },
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              iconSize: 30, // アイコンサイズを大きくする
                              icon: Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                songProvider
                                    .hideMusicControlBar(); // コントロールバーを非表示にする
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'お気に入り'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '検索'),
          BottomNavigationBarItem(icon: Icon(Icons.download), label: 'ダウンロード'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'マイページ'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color.fromARGB(255, 2, 194, 247),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
