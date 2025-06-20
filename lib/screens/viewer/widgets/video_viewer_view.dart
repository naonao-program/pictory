import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoViewerView extends StatefulWidget {
  final VoidCallback onToggleUI;
  final VideoPlayerController controller;
  final Future<void> initializeFuture;
  // 垂直ドラッグ開始時に呼び出されるコールバック
  final GestureDragStartCallback? onVerticalDragStart;
  // 垂直ドラッグ終了時に呼び出されるコールバック
  final GestureDragEndCallback? onVerticalDragEnd;

  const VideoViewerView({
    super.key,
    required this.onToggleUI,
    required this.controller,
    required this.initializeFuture,
    this.onVerticalDragStart,
    this.onVerticalDragEnd,
  });

  @override
  State<VideoViewerView> createState() => _VideoViewerViewState();
}

class _VideoViewerViewState extends State<VideoViewerView> with SingleTickerProviderStateMixin {
  bool _isScrubbing = false;
  double _scrubPosition = 0.0;

  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  Offset? _doubleTapLocalPosition;

  @override
  void initState() {
    super.initState();
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
  
  /// --- 追加: ウィジェットが更新された際の処理 ---
  /// 新しいビデオコントローラーが渡されたときに、前のビデオのズーム状態をリセットします。
  @override
  void didUpdateWidget(VideoViewerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _transformationController.value = Matrix4.identity();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

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
    return FutureBuilder<void>(
      future: widget.initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final controller = widget.controller;

        return Stack(
          alignment: Alignment.center,
          children: [
            // GestureDetectorでラップし、タップ操作と垂直スワイプを検知できるようにする
            GestureDetector(
              onTap: widget.onToggleUI,
              onDoubleTapDown: (details) {
                _doubleTapLocalPosition = details.localPosition;
              },
              onDoubleTap: _onDoubleTap,
              onVerticalDragStart: (details) {
                widget.onVerticalDragStart?.call(details); // 親にイベントを渡す
              },
              onVerticalDragEnd: (details) {
                widget.onVerticalDragEnd?.call(details); // 親にイベントを渡す
              },
              child: Container(
                color: Colors.transparent,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              ),
            ),
            
            ValueListenableBuilder(
              valueListenable: controller,
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
            
            Positioned(
              bottom: 80.0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: ValueListenableBuilder(
                  valueListenable: controller,
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
                                  : value.position.inSeconds.toDouble(),
                              min: 0.0,
                              max: value.duration.inSeconds.toDouble(),
                              onChangeStart: (v) {
                                controller.pause();
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
                                controller
                                    .seekTo(Duration(seconds: v.toInt()))
                                    .then((_) => controller.play());
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
      },
    );
  }
}
