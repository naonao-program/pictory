import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryProvider extends ChangeNotifier {
  /// 読み込み中フラグ
  bool _loading = false;

  /// アクセス拒否フラグ
  bool _noAccess = false;

  /// 取得済みの AssetEntity（常に昇順：古い→新しい）
  final List<AssetEntity> _assets = [];

  /// 1ページあたりの読み込み件数
  final int _pageSize = 100;

  /// 次に読み込むべき「ページ番号」。initial で lastPageIndex をセットする
  int? _currentPage;

  /// 全ページのうち「最後（最新側）のページ番号」を保持
  int? _lastPageIndex;

  /// まだ「古い方のページ」が残っているか
  bool _hasMore = true;

  /// “すべての写真” パスへの参照
  AssetPathEntity? _allPhotosPath;

  /// 外部から参照用：読み込まれた AssetEntity のリストを返す
  List<AssetEntity> get assets => List.unmodifiable(_assets);

  /// 読み込み中フラグ
  bool get loading => _loading;

  /// 権限がない状態か
  bool get noAccess => _noAccess;

  /// 権限設定画面を開く
  void openSetting() {
    PhotoManager.openSetting();
  }

  /// 初期化：権限を取って「最後（最新）」のページだけ読み込み
  Future<void> init() async {
    // 1) 権限リクエスト
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      _noAccess = true;
      notifyListeners();
      return;
    }

    // 2) "すべての写真" のパスを取得（作成日を昇順でソート）
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: true, // 昇順：先頭が古い→末尾が新しい
          ),
        ],
      ),
    );

    if (paths.isEmpty) {
      // そもそも画像がひとつもない
      _noAccess = false;
      _hasMore = false;
      notifyListeners();
      return;
    }

    _allPhotosPath = paths.first;

    // 総画像数を取得して「最後のページ番号」を計算
    final int totalCount = await _allPhotosPath!.assetCountAsync;
    final int pageCount = (totalCount / _pageSize).ceil();
    _lastPageIndex = pageCount - 1;           // ex: total=250, pageCount=3, lastPageIndex=2
    _currentPage = _lastPageIndex;            // まずは最新ページ＝lastPageIndex を読み込む

    // 最新のページだけを読み込み（reset:true）
    await _loadPage(reset: true);

    // ここで遅延ではなく「今すぐ Consumer に伝える」
    notifyListeners();
  }

  /// スクロール位置に応じて、さらに古いページを読み込むかチェック
  void loadMoreIfNeeded(int index) {
    if (!_hasMore || _loading) return;
    
    if (index <= 20) {
      if (!_loading) {
        // _loadPageの完了後に、ここで明示的にUI更新を通知する
        _loadPage().then((_) {
          notifyListeners();
        });
      }
    }
  }

  /// ページ単位での読み込み処理
  Future<void> _loadPage({bool reset = false}) async {
    if (_loading || _allPhotosPath == null || _currentPage == null) return;
    _loading = true;
    // reset時にはnotifyListenersを呼ぶので、ここでは呼ばない
    if (!reset) {
      notifyListeners();
    }

    if (reset) {
      _assets.clear();
      _hasMore = true;
    }

    final int pageToLoad = _currentPage!;
    final List<AssetEntity> pageList = await _allPhotosPath!.getAssetListPaged(
      page: pageToLoad,
      size: _pageSize,
    );

    if (pageToLoad == 0) {
      _hasMore = false;
    } else {
      _hasMore = true;
    }

    if (reset) {
      _assets.addAll(pageList);
    } else {
      _assets.insertAll(0, pageList);
    }

    _currentPage = pageToLoad - 1;
    _loading = false;
    
    // addPostFrameCallbackを削除し、呼び出し元でnotifyListenersを呼ぶようにする
    // これによりUI更新のタイミングが明確になる
  }

  /// 全件リフレッシュ（例：削除後などに呼ぶ）
  Future<void> refresh() async {
    if (_allPhotosPath == null || _lastPageIndex == null) return;
    _currentPage = _lastPageIndex;
    _assets.clear();
    _hasMore = true;
    await _loadPage(reset: true);
    // すぐに Consumer へ更新を伝える
    notifyListeners();
  }
  /// まだ読み込んでいないアセットを全て読み込む
  Future<void> loadAllRemainingAssets() async {
    // すでに全件読み込み済み、または読み込み中は何もしない
    if (!_hasMore || _loading) return;

    _loading = true;
    notifyListeners();

    // 現在のページから最古(0)のページまでループで取得
    while (_hasMore && _currentPage != null && _currentPage! >= 0) {
      final int pageToLoad = _currentPage!;
      final List<AssetEntity> pageList = await _allPhotosPath!.getAssetListPaged(
        page: pageToLoad,
        size: _pageSize,
      );
      
      _assets.insertAll(0, pageList);

      if (pageToLoad == 0) {
        _hasMore = false;
      }
      _currentPage = pageToLoad - 1;
    }

    _loading = false;
    notifyListeners();
  }
}
