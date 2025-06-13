import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

// StatefulWidgetに変更し、ズーム状態を管理できるようにします
class PhotoViewerView extends StatefulWidget {
  final AssetEntity asset;
  // UIの表示/非表示を切り替えるためのコールバック関数を追加
  final VoidCallback onToggleUI;

  const PhotoViewerView({
    super.key, 
    required this.asset,
    required this.onToggleUI,
  });

  @override
  State<PhotoViewerView> createState() => _PhotoViewerViewState();
}

class _PhotoViewerViewState extends State<PhotoViewerView> with SingleTickerProviderStateMixin {
  // ズームや移動の状態を管理するコントローラー
  late final TransformationController _transformationController;
  // ズームアニメーションを管理するコントローラー
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  // ダブルタップされた画面上の位置を保持
  Offset? _doubleTapLocalPosition;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // アニメーション時間を調整
    )..addListener(() {
      // アニメーションの値が変更されるたびに、TransformationControllerを更新
      if (_animation != null) {
        _transformationController.value = _animation!.value;
      }
    });
  }

  @override
  void dispose() {
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

    // 現在ズームされていない場合（Matrixが初期状態の場合）
    if (currentMatrix.isIdentity()) {
      const double scale = 3.0; // ズーム倍率
      // タップした位置が中心になるようにMatrixを計算
      targetMatrix = Matrix4.identity()
        ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
        ..scale(scale);
    } else {
      // すでにズームされている場合は、元のサイズ（初期状態）に戻す
      targetMatrix = Matrix4.identity();
    }
    
    // 現在のMatrixからターゲットのMatrixへアニメーションを開始
    _animation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController));
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // GestureDetectorでラップし、タップ操作を検知
    return GestureDetector(
      onTap: widget.onToggleUI, // シングルタップでUI表示/非表示を切り替え
      onDoubleTapDown: (details) {
        // ダブルタップした位置を保存
        _doubleTapLocalPosition = details.localPosition;
      },
      onDoubleTap: _onDoubleTap, // ダブルタップでズーム処理を実行
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0, // 最大ズーム倍率
        child: Center(
          child: AssetEntityImage(
            widget.asset,
            isOriginal: true, // オリジナル画質で表示
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }
}
