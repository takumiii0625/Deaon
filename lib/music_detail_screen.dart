import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/current_song_provide.dart'; // CurrentSongProviderのパスを適切に設定してください

class MusicDetailScreen extends StatelessWidget {
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    // CurrentSongProviderから現在の曲情報を取得
    final songProvider = Provider.of<CurrentSongProvider>(context);

    // 現在の曲情報をマップから直接取得
    final currentSong = songProvider.currentSong;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // 曲のイメージ表示
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: currentSong['imageUrl'] != null
                        ? Image.network(currentSong['imageUrl'])
                        : Container(height: 200, color: Colors.grey),
                  ),
                  // 曲のタイトル
                  Text(
                    currentSong['songTitle'] ?? 'タイトル不明',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  // アーティスト名
                  Text(
                    currentSong['artistName'] ?? 'アーティスト不明',
                    style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            // 再生時間とスライダーの追加
            Slider(
                value: songProvider.currentPosition.inSeconds.toDouble(),
                max: songProvider.songDuration.inSeconds.toDouble(),
                onChanged: songProvider.isPlayingFromSource('download')
                    ? (value) {
                        print("Slider is changed to $value"); // ログ追加
                        songProvider.seek(Duration(seconds: value.toInt()));
                      }
                    : null, // ダウンロード画面からの再生時のみ操作可能
                activeColor:
                    Color.fromARGB(255, 244, 135, 2), // スライダーのアクティブ部分をオレンジ色に設定
                inactiveColor: Colors.grey // スライダーの非アクティブ部分を灰色に設定
                ),
            Text(
              "${formatDuration(songProvider.currentPosition)} / ${formatDuration(songProvider.songDuration)}",
            ),
            // コントロールボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.skip_previous),
                  onPressed: () => songProvider.playPreviousDownload(),
                ),
                IconButton(
                  icon: Icon(
                    songProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () {
                    if (songProvider.isPlaying) {
                      songProvider.pauseDownloadMusic(); // 一時停止と再生位置の保存
                    } else {
                      songProvider.resumeDownloadMusic(); // 保存した位置からの再生
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.skip_next),
                  onPressed: () => songProvider.playNextDownload(),
                ),
                // 小さくするボタン
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_down),
                  color: Color.fromARGB(255, 3, 3, 3), // アイコンの色を白に設定
                  onPressed: () {
                    // 音楽詳細画面を閉じてコントロールバーに戻る
                    Navigator.of(context).pop();
                    songProvider
                        .setMusicStarted(true); // コントロールバーを再表示するために状態を更新
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
