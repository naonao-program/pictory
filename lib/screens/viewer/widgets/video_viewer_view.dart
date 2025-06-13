import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

class VideoViewerView extends StatefulWidget {
  final AssetEntity asset;
  // UIの表示/非表示を切り替えるためのコールバック関数を追加
  final VoidCallback onToggleUI;

  const VideoViewerView({
    super.key,
    required this.asset,
    required this.onToggleUI,
  });

  @override
  State<VideoViewerView> createState() => _VideoViewerViewState();
}

// SingleTickerProviderStateMixin を追加してアニメーションを有効に
class _VideoViewerViewState extends State<VideoViewerView> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isScrubbing = false;
  double _scrubPosition = 0.0;

  // ズームと移動の状態を管理するコントローラー
  late final TransformationController _transformationController;
  // ズームアニメーションを管理するコントローラー
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  // ダブルタップされた画面上の位置を保持
  Offset? _doubleTapLocalPosition;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
      if (_animation != null) {
        _transformationController.value = _animation!.value;
      }
    });
  }

  Future<void> _initializePlayer() async {
    final file = await widget.asset.file;
    if (file == null) return;
    _controller = VideoPlayerController.file(file)
      ..initialize().then((_) {
        setState(() {});
        _controller?.play();
        _controller?.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  /// ダブルタップ時に呼び出されるズーム処理
  void _onDoubleTap() {
    final position = _doubleTapLocalPosition;
    if (position == null) return;

    final currentMatrix = _transformationController.value;
    Matrix4 targetMatrix;

    if (currentMatrix.isIdentity()) {
      const double scale = 3.0;
      targetMatrix = Matrix4.identity()
        ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
        ..scale(scale);
    } else {
      targetMatrix = Matrix4.identity();
    }
    
    _animation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController));
    _animationController.forward(from: 0);
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

    final controller = _controller!;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 背景の動画プレーヤー部分
        GestureDetector(
          onTap: widget.onToggleUI,
          onDoubleTapDown: (details) {
            _doubleTapLocalPosition = details.localPosition;
          },
          onDoubleTap: _onDoubleTap,
          // 透明なコンテナを配置して、タップ領域を全体に広げる
          child: Container(
            color: Colors.transparent,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 4.0,
              // InteractiveViewerの子要素として動画を配置
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
        ),
        
        // 再生/一時停止ボタン (ズームの影響を受けない)
        ValueListenableBuilder(
          valueListenable: _controller!,
          builder: (context, VideoPlayerValue value, child) {
            return IconButton(
              iconSize: 64,
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
        // プログレスバー (ズームの影響を受けない)
        Positioned(
          bottom: 80.0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: ValueListenableBuilder(
              valueListenable: _controller!,
              builder: (context, VideoPlayerValue value, child) {
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
                          value: _isScrubbing
                              ? _scrubPosition
                              : controller.value.position.inSeconds.toDouble(),
                          min: 0.0,
                          max: controller.value.duration.inSeconds.toDouble(),
                          onChangeStart: (v) {
                            _controller?.pause();
                            setState(() {
                              _isScrubbing = true;
                              _scrubPosition = v;
                            });
                          },
                          onChanged: (v) {
                            setState(() {
                              _scrubPosition = v;
                            });
                          },
                          onChangeEnd: (v) {
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
