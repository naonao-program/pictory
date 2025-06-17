import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// アルバム詳細画面の状態を管理するProvider
class AlbumDetailProvider with ChangeNotifier {
  final AssetPathEntity album;
  // 並び替え済みのアルバム情報を保持する変数
  late AssetPathEntity _sortedAlbum;

  AlbumDetailProvider({required this.album}) {
    // 初期値として渡されたアルバムをセット
    _sortedAlbum = album;
  }

  List<AssetEntity> _assets = [];
  bool _loading = false;
  bool _isInitialized = false;

  final int _pageSize = 100;
  int _currentPage = 0; // 常に0ページ目から開始
  bool _hasMore = true;

  // Providerが破棄されたかどうかを追跡するフラグ
  bool _isDisposed = false;

  /// 安全にリスナーに通知するためのラッパーメソッド
  void _safeNotifyListeners() {
    // 破棄されていなければ通知する
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true; // 破棄されたことを記録
    super.dispose();
  }
  // --- End: Error fix ---


  List<AssetEntity> get assets => _assets;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  bool get isInitialized => _isInitialized;

  /// Providerを初期化し、アセットを「新しい順」にソートして最初のページを読み込む
  Future<void> initialize() async {
    if (_isInitialized) return;
    _loading = true;
    _safeNotifyListeners();

    final AssetPathEntity? sorted = await album.fetchPathProperties(
      filterOptionGroup: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false, // false (降順、新しい→古い) に設定します
          ),
        ],
      ),
    );

    if (sorted == null) {
      _hasMore = false;
      _isInitialized = true;
      _loading = false;
      _safeNotifyListeners();
      debugPrint('アルバム情報の取得に失敗しました');
      return;
    }
    _sortedAlbum = sorted;
    
    // 2. 最初のページ（最新のアセット）を読み込む
    await _loadPage(reset: true);

    _isInitialized = true;
    _loading = false;
    _safeNotifyListeners();
  }

  /// さらに古いアセットを読み込む
  Future<void> loadMoreAssets() async {
    if (_loading || !_hasMore) return;
    // UIに読み込み中を伝えるため、先にnotifyする
    _loading = true;
    _safeNotifyListeners();

    await _loadPage();

    _loading = false;
    _safeNotifyListeners();
  }

  /// ページ単位でアセットを読み込む内部メソッド
  Future<void> _loadPage({bool reset = false}) async {
    if (reset) {
      _assets.clear();
      _currentPage = 0;
      _hasMore = true;
    }

    if (!_hasMore) return;

    try {
      // 条件を持った _sortedAlbum からページ読み込み
      final List<AssetEntity> newAssets = await _sortedAlbum.getAssetListPaged(
        page: _currentPage, // 現在のページインデックスを使用
        size: _pageSize,
      );

      // 読み込んだアセットが0件、またはページサイズより少ない場合、もう次はない
      if (newAssets.isEmpty || newAssets.length < _pageSize) {
        _hasMore = false;
      }
      
      // 常にリストの末尾に追加する
      _assets.addAll(newAssets);

      // 次のページ番号をインクリメント
      _currentPage++;

    } catch (e) {
      debugPrint('Failed to load assets page: $e');
      _hasMore = false;
    }
  }
}
