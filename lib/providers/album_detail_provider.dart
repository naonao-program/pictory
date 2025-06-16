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

  final int _pageSize = 100; // 一度に読み込むアセットの数
  int? _currentPage;
  int? _lastPageIndex;
  bool _hasMore = true;

  List<AssetEntity> get assets => _assets;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  bool get isInitialized => _isInitialized;

  /// Providerを初期化し、アセットを古い順にソートして最新のページを読み込む
  Future<void> initialize() async {
    if (_isInitialized) return;
    _loading = true;
    notifyListeners();

    // 1. アルバム内の総アセット数を取得
    final totalCount = await album.assetCountAsync;
    if (totalCount == 0) {
      _hasMore = false;
      _isInitialized = true;
      _loading = false;
      notifyListeners();
      return;
    }

    // 2. ページネーション情報を計算
    final pageCount = (totalCount / _pageSize).ceil();
    _lastPageIndex = pageCount - 1;
    _currentPage = _lastPageIndex; // 最新のアセットが含まれる最後のページから読み込む

    // 3. 最初のページ（最新のアセット）を読み込む
    await _loadPage(reset: true);
    
    _isInitialized = true;
    _loading = false;
    notifyListeners();
  }

  /// さらに古いアセットを読み込む
  Future<void> loadMoreAssets() async {
    if (_loading || !_hasMore) return;
    await _loadPage();
  }

  /// ページ単位でアセットを読み込む内部メソッド
  Future<void> _loadPage({bool reset = false}) async {
  // 多重読み込みを防止
  if (_loading && !reset) return;

  if (_currentPage == null || _currentPage! < 0) {
    _hasMore = false;
    if (reset) notifyListeners();
    return;
  }

  _loading = true;
  if (!reset) notifyListeners();

  final int pageToLoad = _currentPage!;

  try {
    if (reset) {
      // ① アルバムにフィルタ／ソート条件を設定した新しい AssetPathEntity を取得
      final AssetPathEntity? sorted = await album.fetchPathProperties(
        filterOptionGroup: FilterOptionGroup(
          orders: [
            const OrderOption(
              type: OrderOptionType.createDate,
              asc: true,
            ),
          ],
        ),
      );
      if (sorted == null) {
        throw Exception('アルバム情報の取得に失敗しました');
      }
      _sortedAlbum = sorted;
    }

    // ② 条件を持った _sortedAlbum からページ読み込み
    final List<AssetEntity> newAssets = await _sortedAlbum.getAssetListPaged(
      page: pageToLoad,
      size: _pageSize, // ※ 引数名は size です
    );

    if (reset) {
      _assets
        ..clear()
        ..addAll(newAssets);
    } else {
      _assets.insertAll(0, newAssets);
    }

    if (pageToLoad == 0) {
      _hasMore = false;
    }
    _currentPage = pageToLoad - 1;
    } catch (e) {
      debugPrint('Failed to load assets page: $e');
      _hasMore = false;
    } finally {
      _loading = false;
      if (!reset) notifyListeners();
    }
  }
}