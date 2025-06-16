import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// アルバム詳細画面の状態を管理するProvider
class AlbumDetailProvider with ChangeNotifier {
  final AssetPathEntity album;

  AlbumDetailProvider({required this.album});

  List<AssetEntity> _assets = [];
  List<AssetEntity> get assets => _assets;

  bool _loading = false;
  bool get loading => _loading;

  int _currentPage = 0;
  final int _pageSize = 100; // 一度に読み込むアセットの数
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  /// 指定されたアルバムからアセットを非同期で読み込みます。
  /// 無限スクロールのためにページングを利用しています。
  Future<void> loadAssets() async {
    // 既に読み込み中、またはこれ以上読み込むデータがない場合は何もしない
    if (_loading || !_hasMore) return;

    _loading = true;
    notifyListeners();

    try {
      // photo_managerのページング機能を使ってアセットを取得
      final newAssets = await album.getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );

      // 読み込んだアセットが空の場合、これ以上データはないと判断
      if (newAssets.isEmpty) {
        _hasMore = false;
      } else {
        _assets.addAll(newAssets);
        _currentPage++; // 次のページに進める
      }
    } catch (e) {
      debugPrint('Failed to load assets: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 無限スクロールで次のアセットを読み込むためのエイリアスメソッド
  Future<void> loadMoreAssets() async {
    await loadAssets();
  }
}