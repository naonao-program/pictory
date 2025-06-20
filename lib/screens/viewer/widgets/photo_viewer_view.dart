import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

/// 1枚の画像を表示し、ズームや移動の操作を提供するウィジェット。
class PhotoViewerView extends StatefulWidget {
  final AssetEntity asset;
  // UIの表示/非表示を切り替えるためのコールバック関数
  final VoidCallback onToggleUI;
  // 垂直ドラッグ開始時に呼び出されるコールバック
  final GestureDragStartCallback? onVerticalDragStart;
  // 垂直ドラッグ終了時に呼び出されるコールバック
  final GestureDragEndCallback? onVerticalDragEnd;

  const PhotoViewerView({
    super.key, 
    required this.asset,
    required this.onToggleUI,
    this.onVerticalDragStart,
    this.onVerticalDragEnd,
  });

  @override
  State<PhotoViewerView> createState() => _PhotoViewerViewState();
}

class _PhotoViewerViewState extends State<PhotoViewerView> with SingleTickerProviderStateMixin {
  /// InteractiveViewerのズームや移動の状態をプログラムから制御するためのコントローラー。
  late final TransformationController _transformationController;
  
  /// ダブルタップ時のズームアニメーションを管理するコントローラー。
  late final AnimationController _animationController;
  
  /// ズームアニメーションのMatrix4（変換行列）の値を保持するオブジェクト。
  Animation<Matrix4>? _animation;
  
  /// ダブルタップされた画面上のローカル座標を保持する。
  Offset? _doubleTapLocalPosition;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this, // アニメーションのタイミングを同期させる
      duration: const Duration(milliseconds: 300), // アニメーションの時間
    )..addListener(() {
      // アニメーションの値が変更されるたびに、TransformationControllerの値を更新してUIに反映させる
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

  /// ダブルタップ時に呼び出されるズーム処理。
  void _onDoubleTap() {
    final position = _doubleTapLocalPosition;
    if (position == null) return;

    final currentMatrix = _transformationController.value;
    Matrix4 targetMatrix;

    // isIdentityは、Matrix4が初期状態（移動・拡大縮小・回転なし）かどうかを判定する。
    if (currentMatrix.isIdentity()) {
      // --- ズームイン処理 ---
      const double scale = 3.0; // ズーム倍率
      // タップした位置がズームの中心になるように、Matrixを計算する。
      targetMatrix = Matrix4.identity()
        // 1. ズームの中心がタップ位置になるように平行移動
        ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
        // 2. 拡大
        ..scale(scale);
    } else {
      // --- ズームアウト処理 ---
      // すでにズームされている場合は、元のサイズ（初期状態）に戻す
      targetMatrix = Matrix4.identity();
    }
    
    // 現在の状態(begin)から目標の状態(end)までを滑らかに変化させるアニメーションを作成
    _animation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController));
    
    // アニメーションを開始
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // GestureDetectorでラップし、タップ操作と垂直スワイプを検知できるようにする
    return GestureDetector(
      onTap: widget.onToggleUI, // シングルタップでUIの表示/非表示を切り替え
      onDoubleTapDown: (details) {
        // ダブルタップされた瞬間のローカル座標を保存
        _doubleTapLocalPosition = details.localPosition;
      },
      onDoubleTap: _onDoubleTap, // ダブルタップでズーム処理を実行
      onVerticalDragStart: (details) {
        widget.onVerticalDragStart?.call(details); // 親にイベントを渡す
      },
      onVerticalDragEnd: (details) {
        widget.onVerticalDragEnd?.call(details); // 親にイベントを渡す
      },
      child: InteractiveViewer(
        transformationController: _transformationController, // ズーム状態をコントローラーで管理
        minScale: 1.0,      // 最小スケール
        maxScale: 4.0,      // 最大スケール
        child: Center(
          child: AssetEntityImage(
            widget.asset,
            isOriginal: true, // オリジナル画質の画像を表示
            fit: BoxFit.contain, // アスペクト比を保ちながらウィジェットに収める
            loadingBuilder: (context, child, loadingProgress) {
              // 読み込み中はインジケーターを表示
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }
}
