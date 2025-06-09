import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

class VideoViewerView extends StatefulWidget {
  final AssetEntity asset;
  const VideoViewerView({super.key, required this.asset});

  @override
  State<VideoViewerView> createState() => _VideoViewerViewState();
}

class _VideoViewerViewState extends State<VideoViewerView> {
  VideoPlayerController? _controller;

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
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // ビデオ表示
        Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
        // 再生/一時停止ボタン
        ValueListenableBuilder(
          valueListenable: _controller!,
          builder: (context, VideoPlayerValue value, child) {
            return IconButton(
              iconSize: 64,
              color: Colors.white.withOpacity(value.isPlaying ? 0 : 0.7),
              icon: Icon(value.isPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: () {
                setState(() {
                  value.isPlaying ? _controller?.pause() : _controller?.play();
                });
              },
            );
          },
        ),
        // プログレスバーをビデオプレーヤーの下部に配置
        Positioned(
          bottom: 70,
          left: 0,
          right: 0,
          child: VideoProgressIndicator(
            _controller!,
            allowScrubbing: true,
            padding: const EdgeInsets.all(8.0), // 余白を追加
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.grey,
              backgroundColor: Colors.black26,
            ),
          ),
        )
      ],
    );
  }
}