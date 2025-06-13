import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// デバイスのギャラリーの状態を管理し、UIにデータを提供するクラス。
/// ChangeNotifierを継承しており、状態の変更をUIに通知することができます。
class GalleryProvider extends ChangeNotifier {
  /// アセットの読み込み中かどうかを示すフラグ。
  bool _loading = false;

  /// ギャラリーへのアクセスが許可されていないかどうかを示すフラグ。
  bool _noAccess = false;

  /// 取得済みのAssetEntityのリスト。常に作成日時の昇順（古い→新しい）で保持されます。
  final List<AssetEntity> _assets = [];

  /// ページネーションで一度に読み込むアセットの数。
  final int _pageSize = 100;

  /// 次に読み込むべきページのインデックス。0から始まります。
  /// 過去のデータを遡って読み込むため、デクリメント（-1）されていきます。
  int? _currentPage;

  /// 全ページの中で、最も新しいアセットが含まれる「最後のページ」のインデックス。
  int? _lastPageIndex;

  /// まだ読み込んでいない古いアセット（ページ）が存在するかどうかを示すフラグ。
  bool _hasMore = true;

  /// "すべての写真"アルバム（AssetPathEntity）への参照。
  AssetPathEntity? _allPhotosPath;

  // --- 外部公開用のゲッター ---

  /// 外部から参照するための、読み込み済みアセットのリスト。
  /// List.unmodifiableでラップすることで、外部からリストが変更されるのを防ぎます。
  List<AssetEntity> get assets => List.unmodifiable(_assets);

  /// `_loading`フラグのゲッター。
  bool get loading => _loading;

  /// `_noAccess`フラグのゲッター。
  bool get noAccess => _noAccess;

  /// `_hasMore`フラグのゲッター。
  bool get hasMore => _hasMore;

  /// デバイスの設定アプリを開き、写真へのアクセス許可を変更するよう促すメソッド。
  void openSetting() {
    PhotoManager.openSetting();
  }

  /// プロバイダーの初期化処理。
  /// 権限の確認と、最新のアセットが含まれる最初のページの読み込みを行います。
  Future<void> init() async {
    // 1. 写真ライブラリへのアクセス権限をリクエストします。
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      // 権限が拒否された場合、フラグを立ててリスナーに通知します。
      _noAccess = true;
      notifyListeners();
      return;
    }

    // 2. "すべての写真"アルバムのパス情報を取得します。
    //    アセットは作成日時(createDate)の昇順(asc: true)でソートしておきます。
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common, // 画像と動画の両方
      onlyAll: true, // "すべての写真"アルバムのみを対象
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: true, // 昇順（古い→新しい）
          ),
        ],
      ),
    );

    if (paths.isEmpty) {
      // "すべての写真"アルバムが見つからない場合は、処理を終了します。
      _noAccess = false;
      _hasMore = false;
      notifyListeners();
      return;
    }

    _allPhotosPath = paths.first;

    // 3. 総アセット数を取得し、ページネーションのための情報を計算します。
    final int totalCount = await _allPhotosPath!.assetCountAsync;
    if (totalCount == 0) {
      // アセットが1つも無い場合は、処理を終了します。
      _hasMore = false;
      notifyListeners();
      return;
    }
    // 総ページ数を計算 (例: 250件でpageSizeが100なら、3ページ)
    final int pageCount = (totalCount / _pageSize).ceil();
    _lastPageIndex = pageCount - 1; // 最後のページのインデックス
    _currentPage = _lastPageIndex; // 最初に読み込むのは最新のアセットが含まれる最後のページ

    // 4. 最初のページ（最新のアセット）を読み込みます。
    await _loadPage(reset: true);
    notifyListeners();
  }

  /// 必要に応じて、さらに古いページのアセットを読み込むメソッド。
  /// UI側（例: スクロールがリストの先頭に近づいた時）から呼び出されます。
  Future<void> loadMoreIfNeeded() async {
    if (_loading || !_hasMore) return; // 読み込み中、またはこれ以上データがない場合は何もしない
    await _loadPage();
    notifyListeners(); // 読み込み完了後にUIを更新
  }

  /// 実際にページ単位でアセットを読み込む内部メソッド。
  /// [reset]がtrueの場合、既存のアセットをクリアして最新ページから読み込み直します（リフレッシュ処理）。
  Future<void> _loadPage({bool reset = false}) async {
    if (_loading) return; // 二重読み込みを防止
    if (_allPhotosPath == null || _currentPage == null || _currentPage! < 0) {
      // 読み込むべきページがない場合
      _hasMore = false;
      return;
    }

    _loading = true;
    if (!reset) {
      // 追加読み込みの場合、UIにインジケーターを表示させるために通知
      notifyListeners();
    }

    if (reset) {
      _assets.clear(); // 既存のリストをクリア
      _hasMore = true;   // 読み込みフラグをリセット
      _currentPage = _lastPageIndex; // 最新ページから読み直す
    }

    final int pageToLoad = _currentPage!;
    // 指定したページのAssetEntityのリストを取得
    final List<AssetEntity> pageList = await _allPhotosPath!.getAssetListPaged(
      page: pageToLoad,
      size: _pageSize,
    );
    
    _loading = false;

    if (reset) {
      // リフレッシュの場合は、取得したリストをそのままセット
      _assets.addAll(pageList);
    } else {
      // 追加読み込みの場合は、既存のリストの「先頭」に挿入（古い写真を追加するため）
      _assets.insertAll(0, pageList);
    }

    // 読み込んだページが最初のページ(index 0)だった場合、これ以上古いデータはない
    if (pageToLoad == 0) {
      _hasMore = false;
    }

    // 次に読み込むべきページのインデックスを更新
    _currentPage = pageToLoad - 1;
  }

  /// アセットリストを強制的にリフレッシュするメソッド。
  /// （例: アセットの削除後など）
  Future<void> refresh() async {
    if (_allPhotosPath == null || _lastPageIndex == null) return;
    await _loadPage(reset: true);
    notifyListeners();
  }
}
