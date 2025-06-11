import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

class VideoViewerView extends StatefulWidget {
  final AssetEntity asset;
  const VideoViewerView({
    super.key,
    required this.asset
  });

  @override
  State<VideoViewerView> createState() => _VideoViewerViewState();
}

class _VideoViewerViewState extends State<VideoViewerView> {
  VideoPlayerController? _controller;
  bool _isScrubbing = false;
  double _scrubPosition = 0.0;  // スクラブ中の一時的な位置を保持

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final file = await widget.asset.file;
    if (file == null) return;
    _controller = VideoPlayerController.file(file)
      ..initialize().then((_) {
        setState(() {}); // UIを更新して再生ボタンなどを表示
        _controller?.play(); // 自動再生
        _controller?.setLooping(true); // ループ再生を有効
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // null チェック後に非 null を保証するローカル変数
    final controller = _controller!;

    return Stack(
      alignment: Alignment.center,
      children: [
        // ビデオ表示
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        // 再生/一時停止ボタン
        ValueListenableBuilder(
          valueListenable: _controller!,
          builder: (context, VideoPlayerValue value, child) {
            return IconButton(
              iconSize: 64,
              // スクラブ中もボタンを非表示にする
              color: Colors.white.withAlpha(value.isPlaying || _isScrubbing ? 0 : 179),
              icon: Icon(value.isPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: () {
                setState(() {
                  if (value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                });
              },
            );
          },
        ),
        // プログレスバーを画面下部に配置
        Positioned(
          bottom: 80.0, 
          left: 0,
          right: 0,
          child: SafeArea(
            child: ValueListenableBuilder(
              valueListenable: _controller!,
              builder: (context, VideoPlayerValue value, child) {
                // 再生時間が0の場合はスライダーを表示しない
                if (value.duration.inSeconds == 0) return const SizedBox.shrink();
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(value.position),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          // ドラッグ中はスクラブ位置を表示、通常時は再生位置を表示
                          value: _isScrubbing
                              ? _scrubPosition
                              : controller.value.position.inSeconds.toDouble(),
                          min: 0.0,
                          max: controller.value.duration.inSeconds.toDouble(),
                          onChangeStart: (v) {
                            // ドラッグ開始：再生停止＆初期位置キャッシュ
                            _controller?.pause();
                            setState(() {
                              _isScrubbing = true;
                              _scrubPosition = v;
                            });
                          },
                          onChanged: (v) {
                            // ドラッグ中は位置だけ更新
                            setState(() {
                              _scrubPosition = v;
                            });
                          },
                          onChangeEnd: (v) {
                            // ドラッグ終了：実際にシーク＆再生再開
                            setState(() {
                              _isScrubbing = false;
                            });
                            _controller
                                ?.seekTo(Duration(seconds: v.toInt()))
                                .then((_) => _controller?.play());
                          },
                          activeColor: Colors.white,
                          inactiveColor: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        _formatDuration(value.duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}