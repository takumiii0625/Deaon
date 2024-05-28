import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart'; // `ChangeNotifier`を使うため
import 'dart:async';
import 'package:flutter/foundation.dart';

class CurrentSongProvider with ChangeNotifier {
  AudioPlayer homePlayer = AudioPlayer();
  AudioPlayer downloadPlayer = AudioPlayer(); // `downloadPlayer` だけを保持
  AudioPlayer searchPlayer = AudioPlayer(); // Search page用のプレイヤー

// 再生中のソースを追跡するためのプロパティ
  String _playingSource = '';
  // 再生ソースと一致しているかをチェックするメソッド
  bool isPlayingFromSource(String source) {
    return _isPlaying && _playingSource == source;
  }

  bool _isPlaying = false;
  bool _isFavorite = false;
  bool _isMusicStarted = false;
  String? _selectedSongUrl;
  String? _selectedSongTitle;
  String? _selectedArtistName;
  String? _selectedImageUrl;

  //再生時間

  // 再生時間
  Duration _homeCurrentPosition = Duration.zero;
  Duration _homeSongDuration = Duration.zero;
  Duration _downloadCurrentPosition = Duration.zero;
  Duration _downloadSongDuration = Duration.zero;
  Duration? _downloadLastPosition;
  Duration? _homeLastPosition;

  String get playingSource => _playingSource;

  set playingSource(String value) {
    _playingSource = value;
    notifyListeners();
  }

  Duration get currentPosition {
    return playingSource == 'home'
        ? _homeCurrentPosition
        : _downloadCurrentPosition;
  }

  Duration get songDuration {
    return playingSource == 'home' ? _homeSongDuration : _downloadSongDuration;
  }

  Duration? get downloadLastPosition => _downloadLastPosition;

  // 再生位置を保持する変数

  // Getters to expose private fields
  // 現在の再生位置を取得するゲッター

  // 再生中かどうかを取得するゲッター
  bool get isPlaying => _isPlaying;
  bool get isMusicStarted => _isMusicStarted;
  set isMusicStarted(bool value) {
    _isMusicStarted = value;
    notifyListeners();
  }

  bool get isFavorite => _isFavorite;
  // 現在の曲情報
  String _currentSongTitle = '';
  String _currentArtistName = '';
  String _currentImageUrl = '';

  String? get selectedSongUrl => _selectedSongUrl;
  String? get selectedSongTitle => _selectedSongTitle;
  String? get selectedArtistName => _selectedArtistName;
  String? get selectedImageUrl => _selectedImageUrl;

  // 状態更新関数は独立したプレイヤーの状態を更新するように修正
  void updateCurrentPosition(Duration newPosition) {
    if (playingSource == 'home') {
      _homeCurrentPosition = newPosition;
    } else {
      _downloadCurrentPosition = newPosition;
    }
    notifyListeners();
  }

  void updateSongDuration(Duration newDuration) {
    if (playingSource == 'home') {
      _homeSongDuration = newDuration;
    } else {
      _downloadSongDuration = newDuration;
    }
    notifyListeners();
  }

  void seek(Duration position) {
    if (playingSource == 'home') {
      homePlayer.seek(position);
    } else if (playingSource == 'download') {
      downloadPlayer.seek(position);
    }
  }

  CurrentSongProvider() {
    initializeHomePlayer();
    initializeDownloadPlayer();
    initializeProvider(); // Initialize the provider
  }

  void initializeProvider() {
    fetchSongIfNeeded(); // 初期曲の取得
  }

// Home Playerのリスナーをセットアップ
  void initializeHomePlayer() {
    homePlayer.onAudioPositionChanged.listen((newPosition) {
      if (playingSource == 'home') {
        _homeCurrentPosition = newPosition;
        if (playingSource == 'home') {
          // アクティブなソースチェック
          notifyListeners();
        }
      }
    });

    homePlayer.onPlayerStateChanged.listen((state) {
      if (playingSource == 'home') {
        _isPlaying = state == PlayerState.PLAYING;
        if (state == PlayerState.COMPLETED) {
          nextSong(); // 曲が終了したら次の曲を自動で再生
        }
        if (playingSource == 'home') {
          // アクティブなソースチェック
          notifyListeners();
        }
      }
    });

    homePlayer.onDurationChanged.listen((newDuration) {
      if (playingSource == 'home') {
        _homeSongDuration = newDuration;
        if (playingSource == 'home') {
          // アクティブなソースチェック
          notifyListeners();
        }
      }
    });
  }

// Download Playerのリスナーをセットアップ
  void initializeDownloadPlayer() {
    downloadPlayer.onAudioPositionChanged.listen((newPosition) {
      if (playingSource == 'download') {
        _downloadCurrentPosition = newPosition;
        notifyListeners();
      }
    });

    downloadPlayer.onPlayerStateChanged.listen((state) {
      if (playingSource == 'download') {
        _isPlaying = state == PlayerState.PLAYING;
        if (state == PlayerState.COMPLETED) {
          nextSong(); // 曲が終了したら次の曲を自動で再生
        }
        notifyListeners();
      }
    });

    downloadPlayer.onDurationChanged.listen((newDuration) {
      if (playingSource == 'download') {
        _downloadSongDuration = newDuration;
        notifyListeners();
      }
    });
  }

  void nextSong() async {
    AudioPlayer activePlayer =
        (playingSource == 'home') ? homePlayer : downloadPlayer;
    Duration? lastPosition =
        (playingSource == 'home') ? _homeLastPosition : _downloadLastPosition;

    if (homePlayer.state == PlayerState.PLAYING && playingSource != 'home') {
      await homePlayer.stop();
    }
    if (downloadPlayer.state == PlayerState.PLAYING &&
        playingSource != 'download') {
      await downloadPlayer.stop();
    }

    await activePlayer.stop();
    await activePlayer.seek(Duration.zero);

    lastPosition = Duration.zero; // 対応する最後の位置をリセット

    try {
      await fetchRandomSong();
    } catch (e) {
      print("Error fetching or playing next song: $e");
    }

    notifyListeners();
  }

  void backSong() async {
    if (songHistory.length > 1) {
      songHistory.removeLast();
      String? previousSongId = songHistory.last;

      if (previousSongId != null) {
        AudioPlayer activePlayer =
            (playingSource == 'home') ? homePlayer : downloadPlayer;
        Duration? lastPosition = (playingSource == 'home')
            ? _homeLastPosition
            : _downloadLastPosition;

        await activePlayer.stop();
        await activePlayer.seek(Duration.zero);

        lastPosition = Duration.zero;

        await fetchSongById(previousSongId);

        notifyListeners();
      }
    } else {
      print("Not enough history to go back to a previous song.");
    }
  }

  void downloadPauseMusic() async {
    try {
      if (downloadPlayer.state == PlayerState.PLAYING) {
        _downloadLastPosition =
            Duration(milliseconds: await downloadPlayer.getCurrentPosition());
        await downloadPlayer.pause();
        _isPlaying = false;
        playingSource = ''; // 再生ソースをクリア
        notifyListeners(); // UIを更新し、状態変更を通知
        print("Download music paused at position: $_downloadLastPosition");
      } else {
        print("Download player is not currently playing.");
      }
    } catch (e) {
      print("Error pausing download music: $e");
    }
  }

  void resumeMusic(String source) async {
    AudioPlayer activePlayer;
    Duration? lastPosition;

    if (source != 'home' && homePlayer.state == PlayerState.PLAYING) {
      await homePlayer.stop();
      _homeLastPosition = null;
    }
    if (source != 'download' && downloadPlayer.state == PlayerState.PLAYING) {
      await downloadPlayer.stop();
      _downloadLastPosition = null;
    }
    if (source != 'searchPage' && searchPlayer.state == PlayerState.PLAYING) {
      await searchPlayer.stop();
    }

    switch (source) {
      case 'home':
        activePlayer = homePlayer;
        lastPosition = _homeLastPosition;
        break;
      case 'download':
        activePlayer = downloadPlayer;
        lastPosition = _downloadLastPosition;
        break;
      case 'searchPage':
        activePlayer = searchPlayer;
        break;
      default:
        print("Unknown source for resuming music.");
        return;
    }

    print("Resuming music from source: $source at position: $lastPosition");

    if (lastPosition != null && activePlayer.state == PlayerState.PAUSED) {
      print("Seeking to $lastPosition before resuming playback");
      await activePlayer.seek(lastPosition);
      await activePlayer.resume();
      print("Resumed music from position: $lastPosition");
      print("Player state after resume: ${activePlayer.state}");
      _isPlaying = true;
      playingSource = source;
      notifyListeners();
    } else {
      if (_selectedSongUrl != null) {
        await activePlayer.play(_selectedSongUrl!);
        _isPlaying = true;
        playingSource = source;
        notifyListeners();
      } else {
        print(
            "No last position recorded or player not paused, and no song URL available.");
      }
    }
  }

  void fetchSongIfNeeded() {
    if (selectedSongUrl == null) {
      fetchRandomSong();
    }
  }

  void playMusic(String source) async {
    AudioPlayer player;

    if (source != 'home' && homePlayer.state == PlayerState.PLAYING) {
      await homePlayer.stop();
      _isPlaying = false;
    }
    if (source != 'download' && downloadPlayer.state == PlayerState.PLAYING) {
      await downloadPlayer.stop();
      _isPlaying = false;
    }
    if (source != 'searchPage' && searchPlayer.state == PlayerState.PLAYING) {
      await searchPlayer.stop();
      _isPlaying = false;
    }

    switch (source) {
      case 'home':
        player = homePlayer;
        break;
      case 'download':
        player = downloadPlayer;
        break;
      case 'searchPage':
        player = searchPlayer;
        break;
      default:
        print("Unknown source for playing music.");
        return;
    }

    print("Playing music from source: $source with URL: $_selectedSongUrl");

    if (_selectedSongUrl != null) {
      await player.play(_selectedSongUrl!);
      _isPlaying = true;
      playingSource = source;
      notifyListeners();
    }
  }

  void pauseMusic(String source) async {
    AudioPlayer player;
    Duration? lastPosition;

    switch (source) {
      case 'home':
        player = homePlayer;
        break;
      case 'download':
        player = downloadPlayer;
        break;
      case 'searchPage':
      case 'likePage': // お気に入り画面と検索ページの再生位置を保存
        player = searchPlayer;
        break;
      default:
        print("Unknown source for pausing music.");
        return;
    }

    if (_isPlaying && playingSource == source) {
      print("Attempting to pause music from source: $source");
      print("Current player state before pause: ${player.state}");
      lastPosition = Duration(milliseconds: await player.getCurrentPosition());
      await player.pause();
      print("Player paused, current position: $lastPosition");

      // ソースごとの再生位置を保存
      switch (source) {
        case 'home':
          _homeLastPosition = lastPosition;
          break;
        case 'download':
          _downloadLastPosition = lastPosition;
          break;
        case 'searchPage':
          // 検索ページの再生位置を保存するためのコード（例：_searchLastPosition = lastPosition;）
          break;
      }

      // 一時停止後の状態を再確認
      print("Re-checking player state after pause: ${player.state}");

      _isPlaying = false;
      // playingSource = ''; // ソースをクリアしない

      notifyListeners();
      print(
          "Music paused from source: $source, player state after pause: ${player.state}");
    } else {
      print("Pause condition not met or wrong source/player state");
    }
  }

  //コントロールバーの実装ーーーーーーーーーーーーーーーーーーーーーーーーーー
  Map<String, dynamic> _currentSong = {};

  // 再生状態のsetter
  void setMusicStarted(bool started) {
    _isMusicStarted = started;
    notifyListeners();
  }

  void setCurrentSong(
      String filePath, String title, String artist, String imageUrl) {
    // 曲情報を_currentSongマップに設定
    _currentSong = {
      'filePath': filePath,
      'songTitle': title,
      'artistName': artist,
      'imageUrl': imageUrl,
    };

    // 曲情報を個別のプロパティにも設定
    _selectedSongUrl = filePath;
    _currentSongTitle = title;
    _currentArtistName = artist;
    _currentImageUrl = imageUrl;
    notifyListeners();
  }

  Map<String, dynamic> get currentSong => _currentSong;

  // 現在の曲情報のゲッター
  String get currentSongTitle => _currentSongTitle;
  String get currentArtistName => _currentArtistName;
  String get currentImageUrl => _currentImageUrl;

  // コントロールバーを非表示にし、曲の再生も停止するメソッド
  // コントロールバーの表示/非表示を引数で制御できるように変更
  void hideMusicControlBar({bool hide = true}) async {
    AudioPlayer activePlayer =
        (playingSource == 'home') ? homePlayer : downloadPlayer;

    if (hide) {
      await activePlayer.stop(); // 音楽の再生を停止
      _isMusicStarted = false;
      _isPlaying = false;
      notifyListeners(); // ウィジェットの再構築をトリガー
    }
  }

  //ーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーー
// ダウンロード一覧画面での処理ーーーーーーーーーーーーーーーーーーーーーーーーーーーーー

  Future<void> printDownloadsContent() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsFilePath = '${dir.path}/downloads.json';
    final downloadsFile = File(downloadsFilePath);

    if (await downloadsFile.exists()) {
      print('downloads.json exists. Printing content:');
      final content = await downloadsFile.readAsString();
      print(content);
    } else {
      print('downloads.json does not exist.');
    }
  }

  //ホーム画面からのダウンロード処理
  Future<void> downloadMusic(BuildContext context) async {
    if (_selectedSongUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ダウンロードする曲が選択されていません。")),
      );
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final downloadsFile = File('${dir.path}/downloads.json');

    List<dynamic> existingDownloads = [];
    if (await downloadsFile.exists()) {
      final content = await downloadsFile.readAsString();
      existingDownloads = json.decode(content);
    }

    // 既にダウンロード済みかどうかをチェック
    bool isAlreadyDownloaded = existingDownloads
        .any((download) => download['audioUrl'] == _selectedSongUrl);
    if (isAlreadyDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("この曲は既にダウンロード済みです。")),
      );
      return;
    }

    // ダウンロード処理
    final file = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${Uri.parse(_selectedSongUrl!).pathSegments.last}');
    try {
      final dio = Dio();
      await dio.download(_selectedSongUrl!, file.path);

      // ダウンロード成功時の処理: メタデータも含めて保存
      Map<String, dynamic> downloadInfo = {
        'path': file.path,
        'songTitle': _selectedSongTitle,
        'artistName': _selectedArtistName,
        'audioUrl': _selectedSongUrl,
        'imageUrl': _selectedImageUrl,
        'downloaded': true,
      };

      // 修正部分: ダウンロード情報を保存するメソッドを呼び出し
      await saveDownloadInfo(downloadInfo);
      await printDownloadsContent(); // ダウンロード完了後にファイル内容を表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ダウンロード成功しました。")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ダウンロードに失敗しました。: $e")),
      );
    }
  }

  //お気に入り画面からのダウンロード処理
  Future<void> downloadFavoriteSong(
      BuildContext context, Map<String, dynamic> songInfo) async {
    final String? audioUrl = songInfo['audioUrl'];
    if (audioUrl == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final downloadsFile = File('${dir.path}/downloads.json');

    List<dynamic> existingDownloads = [];
    if (await downloadsFile.exists()) {
      final content = await downloadsFile.readAsString();
      existingDownloads = json.decode(content);
    }

    // 既にダウンロード済みかどうかをチェック
    bool isAlreadyDownloaded =
        existingDownloads.any((download) => download['audioUrl'] == audioUrl);
    if (isAlreadyDownloaded) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("既にダウンロード済みです。")));
      // ここでユーザーに通知する処理を追加（例: Snackbarを表示）
      return;
    }

    // ダウンロード処理
    final file = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${Uri.parse(audioUrl).pathSegments.last}');
    try {
      final dio = Dio();
      await dio.download(audioUrl, file.path);

      // ダウンロード成功時の処理: メタデータも含めて保存
      Map<String, dynamic> downloadInfo = {
        'path': file.path,
        'songTitle': songInfo['songTitle'],
        'artistName': songInfo['artistName'],
        'audioUrl': audioUrl,
        'imageUrl': songInfo['imageUrl'],
        'downloaded': true,
      };

      // 修正部分: ダウンロード情報を保存するメソッドを呼び出し
      await saveDownloadInfo(downloadInfo);
      await printDownloadsContent(); // ダウンロード完了後にファイル内容を表示
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("ダウンロード成功しました。")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("ダウンロードに失敗しました。:$e")));
    }
  }

  //検索画面からのダウンロード処理
  Future<void> downloadSearchedSong(
      BuildContext context, Map<String, dynamic> songInfo) async {
    final String? audioUrl = songInfo['audioUrl'];
    if (audioUrl == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final downloadsFile = File('${dir.path}/downloads.json');

    List<dynamic> existingDownloads = [];
    if (await downloadsFile.exists()) {
      final content = await downloadsFile.readAsString();
      existingDownloads = json.decode(content);
    }

    // 既にダウンロード済みかどうかをチェック
    bool isAlreadyDownloaded =
        existingDownloads.any((download) => download['audioUrl'] == audioUrl);
    if (isAlreadyDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("既にダウンロード済みです。")),
      );
      return;
    }

    // ダウンロード処理
    final file = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${Uri.parse(audioUrl).pathSegments.last}');
    try {
      final dio = Dio();
      await dio.download(audioUrl, file.path);

      // ダウンロード成功時の処理: メタデータも含めて保存
      Map<String, dynamic> downloadInfo = {
        'path': file.path,
        'songTitle': songInfo['songTitle'],
        'artistName': songInfo['artistName'],
        'audioUrl': audioUrl,
        'imageUrl': songInfo['imageUrl'],
        'downloaded': true,
      };

      // 修正部分: ダウンロード情報を保存するメソッドを呼び出し
      await saveDownloadInfo(downloadInfo);
      await printDownloadsContent(); // ダウンロード完了後にファイル内容を表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ダウンロード成功しました。")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ダウンロードに失敗しました。: $e")),
      );
    }
  }

  Future<void> saveDownloadInfo(Map<String, dynamic> downloadInfo) async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsFile = File('${dir.path}/downloads.json');

    List<dynamic> downloads = [];
    if (await downloadsFile.exists()) {
      final content = await downloadsFile.readAsString();
      downloads = json.decode(content);
    }
    downloads.add(downloadInfo);
    await downloadsFile.writeAsString(json.encode(downloads));
  }

  String? _selectedSongId; // 選択された曲のIDを保存するプロパティ

  //オフライン再生

  // ダウンロードされた音楽を再生するメソッド、再生位置の復帰を含む
  // CurrentSongProvider クラス内のメソッドを更新
  Future<void> playDownloadedMusic(String filePath,
      {String source = 'download'}) async {
    try {
      AudioPlayer player;
      Duration? lastPosition;

      await homePlayer.stop();
      await downloadPlayer.stop();
      await searchPlayer.stop();

      switch (source) {
        case 'home':
          player = homePlayer;
          lastPosition = _homeLastPosition;
          break;
        case 'download':
          player = downloadPlayer;
          lastPosition = _downloadLastPosition;
          break;
        default:
          print("Unknown source for playing downloaded music.");
          return;
      }

      print("Starting seekAndPlay for downloaded music");
      await seekAndPlay(player, filePath, lastPosition);

      _isPlaying = true;
      _isMusicStarted = true;
      playingSource = source;
      print("Playing source set to: $playingSource");
      notifyListeners();
    } catch (e) {
      print("Error playing downloaded audio: $e");
      _isPlaying = false;
      _isMusicStarted = false;
      playingSource = '';
      notifyListeners();
    }
  }

// コントロールバーを表示するための情報を設定するメソッド

  //ダウンロード済みの曲をインデックス管理
  List<Map<String, dynamic>> _downloads = [];
  int _currentDownloadIndex = 0;

  List<Map<String, dynamic>> get downloads => _downloads;
  int get currentDownloadIndex => _currentDownloadIndex;
//ダウンロード一覧をロードする

  Future<void> loadDownloads() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadsFile = File('${dir.path}/downloads.json');
    if (await downloadsFile.exists()) {
      final content = await downloadsFile.readAsString();
      _downloads = List<Map<String, dynamic>>.from(json.decode(content));
      notifyListeners();
      print("Loaded downloads: $_downloads"); // この行を追加
    } else {
      print("Downloads file does not exist."); // この行を追加
    }
  }

  Future<void> seekAndPlay(
      AudioPlayer player, String filePath, Duration? lastPosition) async {
    try {
      if (lastPosition != null && lastPosition.inMilliseconds > 0) {
        print("Attempting to seek to $lastPosition");
        await player.seek(lastPosition);
        print("Seek operation completed to $lastPosition");
      } else {
        print("No last position found or last position is 0");
      }

      print(
          "Starting playback of file: $filePath after seeking to $lastPosition");
      await player.play(filePath, isLocal: true);
      print("Playback started for file: $filePath");
      print("Player state after play: ${player.state}");
    } catch (e) {
      print("Error playing downloaded audio: $e");
    }
  }

  void cleanup() {
    // プレイヤーのリソースをクリーンアップするロジック
    homePlayer.dispose();
    downloadPlayer.dispose();
    searchPlayer.dispose();
  }

  Future<void> playCurrentDownload() async {
    if (_downloads.isNotEmpty &&
        _currentDownloadIndex >= 0 &&
        _currentDownloadIndex < _downloads.length) {
      final currentDownload = _downloads[_currentDownloadIndex];
      try {
        // 他のプレイヤーを停止
        await homePlayer.stop();
        await downloadPlayer.stop();
        await searchPlayer.stop();

        // 再生位置を確認
        print(
            "Attempting to play download from position: $_downloadLastPosition");

        // 現在のダウンロード曲を再生
        await seekAndPlay(
            downloadPlayer, currentDownload['path'], _downloadLastPosition);

        // 状態を更新
        _isPlaying = true;
        _isMusicStarted = true;
        playingSource = 'download';

        // 再生成功のログ出力
        print("Download music playing from position: $_downloadLastPosition");
      } catch (e) {
        print("Error playing current download: $e");
        _isPlaying = false;
        _isMusicStarted = false;
      } finally {
        notifyListeners();
      }
    } else {
      print('No downloads available or index out of range');
    }
  }

  void setDownloadIndex(int index) {
    _currentDownloadIndex = index;
    notifyListeners();
  }

  Future<void> playNextDownload() async {
    // 現在のダウンロードインデックスを更新
    if (_downloads.isNotEmpty) {
      _currentDownloadIndex = (_currentDownloadIndex + 1) % _downloads.length;
      if (_currentDownloadIndex < _downloads.length) {
        // 次の曲を設定して再生
        var nextDownload = _downloads[_currentDownloadIndex];
        setCurrentSong(
          nextDownload['path'],
          nextDownload['songTitle'],
          nextDownload['artistName'],
          nextDownload['imageUrl'],
        );
        playDownloadedMusic(nextDownload['path']);
      } else {
        // リストの最後に達したら、再生を停止またはリストの最初に戻るなどの処理を行う
      }
    }
  }

  void playPreviousDownload() async {
    if (_downloads.isNotEmpty) {
      // 現在のインデックスを前の曲に更新
      _currentDownloadIndex =
          (_currentDownloadIndex - 1 + _downloads.length) % _downloads.length;

      // インデックスが更新された曲の情報を取得
      final currentDownload = _downloads[_currentDownloadIndex];

      // 現在の曲情報を更新
      setCurrentSong(
        currentDownload['path'],
        currentDownload['songTitle'],
        currentDownload['artistName'],
        currentDownload['imageUrl'],
      );

      // downloadPlayerを使って再生を停止
      await downloadPlayer.stop();

      // `downloadPlayer` で前のダウンロード曲を再生
      await playDownloadedMusic(currentDownload['path'], source: 'downloads');
    }
  }

  void disposePlayers() {
    homePlayer.dispose();
    downloadPlayer.dispose();
    searchPlayer.dispose();
  }

  @override
  void dispose() {
    homePlayer.dispose();
    downloadPlayer.dispose();
    searchPlayer.dispose();
    super.dispose();
  }

// 一時停止時に再生位置を保存
  void pauseDownloadMusic() async {
    if (downloadPlayer.state == PlayerState.PLAYING) {
      _downloadLastPosition =
          Duration(milliseconds: await downloadPlayer.getCurrentPosition());
      await downloadPlayer.pause();
      _isPlaying = false;
      notifyListeners();
      print("Download music paused at position: $_downloadLastPosition");
    }
  }

  void resumeDownloadMusic() async {
    if (_downloadLastPosition != null) {
      await downloadPlayer.seek(_downloadLastPosition!);
      await downloadPlayer.resume();
      _isPlaying = true;
      notifyListeners();
      print("Download music resumed from position: $_downloadLastPosition");
    }
  }

  // bool get isMusicStarted => _isMusicStarted; // ゲッターを追加

  //-----------------------------------------------------------------------------------------

  // ランダムな曲を取得するメソッド
  Future<void> fetchRandomSong() async {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('uploads').get();
    final allSongs = querySnapshot.docs;

    if (allSongs.isNotEmpty) {
      final randomIndex = Random().nextInt(allSongs.length);
      final selectedSongDoc = allSongs[randomIndex];

      // 履歴リストの管理
      if (_songHistory.length == 5) {
        _songHistory.removeAt(0); // リストが最大サイズに達したら、最も古い要素を削除
      }
      _songHistory.add(selectedSongDoc.id); // 新しい曲のIDをリストに追加

      final selectedSong = selectedSongDoc.data() as Map<String, dynamic>;
      _selectedSongId = selectedSongDoc.id; // ドキュメントのIDを保存
      _selectedSongUrl = selectedSong['audioUrl'];
      _selectedSongTitle = selectedSong['songTitle'];
      _selectedArtistName = selectedSong['artistName'];
      _selectedImageUrl = selectedSong['imageUrl'];

      // お気に入り状態を確認
      await checkIfSongIsFavorite();

      // 曲の情報を更新した後、曲を自動的に再生
      if (_selectedSongUrl != null) {
        await homePlayer.play(_selectedSongUrl!); // homePlayerを使用して再生
        _isPlaying = true; // 再生状態を更新
        playingSource = 'home'; // 再生ソースを 'home' に設定
      }

      notifyListeners(); // UIを更新
    } else {
      // 曲が一つも取得できなかった場合のエラーハンドリング
      print("No songs found in the database.");
    }
    notifyListeners();
  }

  String? get selectedSongId => _selectedSongId;

  Future<void> checkIfSongIsFavorite() async {
    final dir = await getApplicationDocumentsDirectory();
    final favoriteFile = File('${dir.path}/favorites.json');
    if (await favoriteFile.exists()) {
      final content = await favoriteFile.readAsString();
      List<dynamic> decodedContent = json.decode(content);
      List<Map<String, dynamic>> favorites =
          decodedContent.cast<Map<String, dynamic>>();
      // _selectedSongIdを使用してお気に入り状態を確認
      _isFavorite = favorites.any((item) => item['songId'] == _selectedSongId);
      notifyListeners();
    }
  }

  //お気に入りボタンを押した時の処理
  Future<void> addFavorite(Map<String, dynamic> newFavorite) async {
    final dir = await getApplicationDocumentsDirectory();
    final favoriteFile = File('${dir.path}/favorites.json');

    List<dynamic> favorites;
    if (await favoriteFile.exists()) {
      final content = await favoriteFile.readAsString();
      favorites = json.decode(content);
    } else {
      favorites = [];
    }

    favorites.add(newFavorite);
    await favoriteFile.writeAsString(json.encode(favorites));
  }

// CurrentSongProvider クラス内
  Future<void> addCurrentSongToFavorites() async {
    if (_selectedSongId == null) {
      print("No song selected.");
      return;
    }

    Map<String, dynamic> newFavorite = {
      'songId': _selectedSongId,
      'songTitle': _selectedSongTitle,
      'artistName': _selectedArtistName,
      'audioUrl': _selectedSongUrl,
      'imageUrl': _selectedImageUrl,
    };

    addFavorite(newFavorite); // 上述の addFavorite メソッドを呼び出す
  }

  List<Map<String, dynamic>> _favorites = []; // お気に入りリストをMapのリストとして管理

  Future<void> loadFavorites() async {
    final dir = await getApplicationDocumentsDirectory();
    final favoriteFile = File('${dir.path}/favorites.json');
    if (await favoriteFile.exists()) {
      final content = await favoriteFile.readAsString();
      _favorites = List<Map<String, dynamic>>.from(json.decode(content));
      _isFavorite = _favorites.any((fav) => fav['songId'] == _selectedSongId);

      notifyListeners(); // リストの更新後にリスナーに通知
    } else {
      _favorites = [];
      _isFavorite = false;
      notifyListeners();
    }
  }

  // 特定の曲がお気に入りかどうかをチェックするメソッド
  bool isSongFavorite(String songId) {
    return _favorites.any((song) => song['songId'] == songId);
  }

  Future<void> toggleFavorite(
      String songId, Map<String, dynamic>? songInfo) async {
    final dir = await getApplicationDocumentsDirectory();
    final favoriteFile = File('${dir.path}/favorites.json');
    List<dynamic> favoritesList;

    if (await favoriteFile.exists()) {
      final content = await favoriteFile.readAsString();
      favoritesList = json.decode(content);
    } else {
      favoritesList = [];
    }

    int index = favoritesList.indexWhere((item) => item['songId'] == songId);
    bool isCurrentlyFavorite = index != -1;

    if (isCurrentlyFavorite) {
      favoritesList.removeAt(index);
    } else if (songInfo != null) {
      favoritesList.add({
        'songId': songId,
        'songTitle': songInfo['songTitle'],
        'artistName': songInfo['artistName'],
        'audioUrl': songInfo['audioUrl'],
        'imageUrl': songInfo['imageUrl']
      });
    }

    // 更新したお気に入りリストをファイルに書き込む
    await favoriteFile.writeAsString(json.encode(favoritesList));
    // お気に入りリストを再ロードして、_isFavoriteを更新
    loadFavorites();
    // 内部のお気に入り状態を更新
    _favorites = List<Map<String, dynamic>>.from(favoritesList);
    // UIに状態変更を通知
    notifyListeners();
  }

// 引数で渡されたパスから音楽を再生するメソッド
  Future<void> playMusicFromPath(String path) async {
    AudioPlayer activePlayer =
        (playingSource == 'home') ? homePlayer : downloadPlayer;

    await activePlayer.play(path, isLocal: true);
    _isPlaying = true; // 再生状態を更新
    _isMusicStarted = true;
    notifyListeners(); // 再生状態が変わったことをリスナーに通知
  }

  List<String> _songHistory = []; // 移動: この行は変更なし
// 履歴リストへのアクセスを提供するメソッド
  Future<void> fetchSongById(String songId) async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('uploads')
        .doc(songId)
        .get();

    if (docSnapshot.exists) {
      final selectedSong = docSnapshot.data() as Map<String, dynamic>;
      _selectedSongId = docSnapshot.id;
      _selectedSongUrl = selectedSong['audioUrl'];
      _selectedSongTitle = selectedSong['songTitle'];
      _selectedArtistName = selectedSong['artistName'];
      _selectedImageUrl = selectedSong['imageUrl'];

      // お気に入り状態を確認するロジックがあればここに追加
      await checkIfSongIsFavorite();

      // アクティブなプレイヤーを決定
      AudioPlayer activePlayer =
          (playingSource == 'home') ? homePlayer : downloadPlayer;

      if (_selectedSongUrl != null) {
        await activePlayer.stop(); // 既に再生中の曲があれば停止
        await activePlayer.play(_selectedSongUrl!); // 新しい曲を再生
        _isPlaying = true; // 再生状態を更新
      }

      notifyListeners(); // 状態が更新されたことをリスナーに通知
    } else {
      print("Document does not exist on the database.");
    }
  }

  // 再生/一時停止をトグルする
  Future<void> togglePlay() async {
    AudioPlayer activePlayer =
        (playingSource == 'home') ? homePlayer : downloadPlayer;

    if (_isPlaying) {
      await activePlayer.pause();
      if (playingSource == 'home') {
        _homeLastPosition =
            Duration(milliseconds: await homePlayer.getCurrentPosition());
      } else {
        _downloadLastPosition =
            Duration(milliseconds: await downloadPlayer.getCurrentPosition());
      }
    } else {
      if (playingSource == 'home') {
        await seekAndPlay(homePlayer, _selectedSongUrl!, _homeLastPosition);
      } else {
        await seekAndPlay(
            downloadPlayer, _selectedSongUrl!, _downloadLastPosition);
      }
    }
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  List<String> get songHistory => _songHistory;
  // 曲の履歴を管理するメソッド
  void addSongToHistory(String songId) {
    if (_songHistory.length == 5) {
      _songHistory.removeAt(0);
    }
    _songHistory.add(songId);
    notifyListeners();
  }

  void removeLastSongFromHistory() {
    if (_songHistory.isNotEmpty) {
      _songHistory.removeLast();
      notifyListeners();
    }
  }

  String? get lastSongId => _songHistory.isNotEmpty ? _songHistory.last : null;

//お気に入り画面から曲を再生するーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーー
  Future<void> playFavoriteSong(Map<String, dynamic> song) async {
    _selectedSongId = song['songId'];
    _selectedSongUrl = song['audioUrl'];
    _selectedSongTitle = song['songTitle'];
    _selectedArtistName = song['artistName'];
    _selectedImageUrl = song['imageUrl'];
    await stopAllMusic(); // 全プレイヤーを停止する
    /// likePage専用のプレイヤーを使用
    AudioPlayer activePlayer = searchPlayer;

    // playingSource を 'likePage' に設定
    playingSource = 'likePage';

    // URLから音楽を再生する
    if (_selectedSongUrl != null && _selectedSongUrl!.isNotEmpty) {
      try {
        await activePlayer.stop(); // 既存の音楽を停止
        await activePlayer.play(_selectedSongUrl!); // 新しい音楽を再生
        _isPlaying = true;

        // 20秒後に音楽を停止する処理を追加
        Future.delayed(Duration(seconds: 20), () async {
          if (_isPlaying && activePlayer.state == PlayerState.PLAYING) {
            // 再生中の場合のみ停止する
            await activePlayer.pause();
            _isPlaying = false;
            notifyListeners();
          }
        });
      } catch (e) {
        print("Error playing audio: $e");
        _isPlaying = false;
      }
      notifyListeners();
    }
  }

  // 検索ページからの曲再生と自動停止のロジックーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーー
  Future<void> playMusicFromSearchPage(String url) async {
    await stopAllMusic(); // 全プレイヤーを停止する
    await searchPlayer.play(url);
    _isPlaying = true;
    playingSource = 'searchPage';
    notifyListeners();

    // 20秒後に自動的に音楽を停止する
    Future.delayed(Duration(seconds: 20), () async {
      if (_isPlaying && searchPlayer.state == PlayerState.PLAYING) {
        await searchPlayer.pause();
        _isPlaying = false;
        notifyListeners();
      }
    });
  }

  Future<void> stopAllMusic() async {
    await homePlayer.stop();
    await downloadPlayer.stop();
    await searchPlayer.stop();
    _isPlaying = false;
    playingSource = '';
    notifyListeners();
  }

  // アーティストページからの曲再生と自動停止のロジックーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーーー
  Future<void> playMusicFromArtistPage(String url) async {
    await stopAllMusic(); // 全プレイヤーを停止する
    await searchPlayer.play(url);
    _isPlaying = true;
    playingSource = 'artistpage';
    notifyListeners();

    // 20秒後に自動的に音楽を停止する
    Future.delayed(Duration(seconds: 20), () async {
      if (_isPlaying && searchPlayer.state == PlayerState.PLAYING) {
        await searchPlayer.pause();
        _isPlaying = false;
        notifyListeners();
      }
    });
  }
}
