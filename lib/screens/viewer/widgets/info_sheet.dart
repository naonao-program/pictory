import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:exif/exif.dart';
import 'package:video_player/video_player.dart';

/// 非同期で読み込むファイル情報をまとめるためのデータクラス
class AssetInfoData {
  final int? fileSize;
  final Map<String, dynamic>? exifData;
  final Duration? videoDuration;

  AssetInfoData({this.fileSize, this.exifData, this.videoDuration});
}

/// アセットの詳細情報を表示するためのボトムシートウィジェット。
class InfoSheet extends StatefulWidget {
  final AssetEntity asset;
  // 動画の場合に情報を取得するためにVideoPlayerControllerを受け取る
  final VideoPlayerController? videoController;

  const InfoSheet({
    super.key,
    required this.asset,
    this.videoController,
  });

  /// このボトムシートをモーダル表示するための静的メソッド。
  static void show(
    BuildContext context,
    AssetEntity asset, {
    VideoPlayerController? videoController,
  }) async {
    // 日本語の日付フォーマットを初期化
    await initializeDateFormatting('ja_JP');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF222222), // 背景色
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)), // 上部の角を丸める
            ),
            child: InfoSheet(
              asset: asset,
              videoController: videoController
            ),
          );
        },
      ),
    );
  }

  @override
  State<InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<InfoSheet> {
  // ファイルサイズとExifデータを非同期で取得するためのFuture
  late Future<AssetInfoData> _infoFuture;

  @override
  void initState() {
    super.initState();
    // Widgetの初期化時に非同期処理を開始
    _infoFuture = _loadAssetInfo();
  }

  /// アセットの各種情報を非同期で読み込む。
  Future<AssetInfoData> _loadAssetInfo() async {
    // ファイルサイズを取得
    final fileSize = await _getFileSize(widget.asset);
    
    Map<String, dynamic>? exifData;
    Duration? videoDuration;

    if (widget.asset.type == AssetType.image) {
      exifData = await _getExifData(widget.asset);
    } else if (widget.asset.type == AssetType.video) {
      final durationMs = widget.asset.duration;
      videoDuration = durationMs > 0 ? Duration(milliseconds: durationMs) : null;
    }
    
    return AssetInfoData(
      fileSize: fileSize,
      exifData: exifData,
      videoDuration: videoDuration,
    );
  }

  /// アセットからファイルサイズを非同期で取得する。
  Future<int?> _getFileSize(AssetEntity asset) async {
    final file = await asset.file;
    return file?.length();
  }
  
  /// アセットからExifデータを非同期で取得する。
  Future<Map<String, dynamic>?> _getExifData(AssetEntity asset) async {
    try {
      // オリジナルの画像バイトデータを取得
      final Uint8List? bytes = await asset.originBytes;
      if (bytes == null) return null;
      // exifパッケージを使ってExifを読み込む
      return await readExifFromBytes(bytes);
    } catch (e) {
      // Exifが読み取れない場合があるため、エラーはコンソールに出力するのみ
      debugPrint('Failed to read Exif data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetInfoData>(
      future: _infoFuture,
      builder: (context, snapshot) {
        // データ読み込み中はインジケーターを表示
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // エラーが発生した場合はメッセージを表示
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('情報を読み込めませんでした', style: TextStyle(color: Colors.white)));
        }

        final info = snapshot.data!;
        final exif = info.exifData ?? {};

        // --- UIの構築 ---
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 上部のドラッグハンドル
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            _buildHeader(widget.asset),
            const SizedBox(height: 24),
            _buildInfoSection(info, exif),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  /// ヘッダー部分（日時とファイル名）を生成
  Widget _buildHeader(AssetEntity asset) {
    final date = asset.createDateTime;
    final formattedDate = DateFormat('y年M月d日 E曜日', 'ja_JP').format(date);
    final formattedTime = DateFormat('H:mm').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$formattedDate $formattedTime', style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 4),
        Text(asset.title ?? 'No Title', style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  /// 情報表示セクション全体を生成
  Widget _buildInfoSection(AssetInfoData info, Map<String, dynamic> exif) {
    // --- 各種Exif情報を抽出・フォーマット ---
    final make = exif['Image Make']?.printable;
    final model = exif['Image Model']?.printable;
    final lensModel = exif['EXIF LensModel']?.printable;
    final hasCameraInfo = (make != null && make.isNotEmpty) || (model != null && model.isNotEmpty);

    final fNumberStr = exif['EXIF FNumber']?.printable;
    
    // F値を適切にフォーマット
    String? fNumber;
    if (fNumberStr != null && fNumberStr.isNotEmpty) {
      // 分数形式（例: "28/10"）を小数形式に変換
      if (fNumberStr.contains('/')) {
        final parts = fNumberStr.split('/');
        if (parts.length == 2) {
          final numerator = double.tryParse(parts[0]);
          final denominator = double.tryParse(parts[1]);
          if (numerator != null && denominator != null && denominator != 0) {
            fNumber = (numerator / denominator).toStringAsFixed(1);
          }
        }
      } else {
        // 既に小数形式の場合はそのまま使用
        fNumber = fNumberStr;
      }
    }
    
    final exposureTimeStr = exif['EXIF ExposureTime']?.printable;
    final exposureTime = exposureTimeStr != null && exposureTimeStr.isNotEmpty ? exposureTimeStr : null;

    final iso = exif['EXIF ISOSpeedRatings']?.printable;
    
    final focalLengthStr = exif['EXIF FocalLength']?.printable;
    final focalLength = focalLengthStr != null && focalLengthStr.isNotEmpty ? focalLengthStr : null;

    // --- ウィジェットの構築 ---
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // カメラ・レンズ情報
          _buildCameraInfoRow(make, model, hasCameraInfo),
          const Divider(color: Colors.white24, height: 24),
          if (!hasCameraInfo) _buildSimpleTextInfoRow('No lens information'),
          if (hasCameraInfo && lensModel != null) _buildSimpleTextInfoRow(lensModel),
          
          // ファイル基本情報 (解像度、サイズなど)
          _buildFileInfoRow(info),
          
          // 写真の詳細Exif情報 (ISO, F値など)
          if (widget.asset.type == AssetType.image && (iso != null || focalLength != null || fNumber != null || exposureTime != null))
            _buildPhotoExifDetailRow(iso, focalLength, fNumber, exposureTime),
        ],
      ),
    );
  }
  
  /// カメラ情報行
  Widget _buildCameraInfoRow(String? make, String? model, bool hasInfo) {
    String fileFormat = widget.asset.mimeType?.split('/').last.toUpperCase() ?? '';
    if (fileFormat == 'QUICKTIME') fileFormat = 'MOV';
    if (fileFormat == 'MPEG') fileFormat = 'MP4';


    return Row(
      children: [
        Expanded(
          child: Text(
            hasInfo ? (model ?? make ?? 'No camera information') : 'No camera information',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        if (fileFormat.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(fileFormat, style: const TextStyle(color: Colors.white, fontSize: 12)),
          )
      ],
    );
  }
  
  /// レンズ情報など、シンプルなテキスト行
  Widget _buildSimpleTextInfoRow(String text) {
    return Column(
      children: [
         Row(
          children: [
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
        ),
        const Divider(color: Colors.white24, height: 24),
      ],
    );
  }

  /// ファイル情報行 (解像度、サイズなど)
  Widget _buildFileInfoRow(AssetInfoData info) {
    final megaPixels = ((widget.asset.width * widget.asset.height) / 1000000).toStringAsFixed(1);
    final fileSizeMB = info.fileSize != null && info.fileSize! > 0
        ? (info.fileSize! / (1024 * 1024)).toStringAsFixed(1)
        : null;
    final frameRate = widget.videoController?.value.isInitialized ?? false
      ? 'N/A'
      : null;
    final duration = info.videoDuration != null 
      ? '${info.videoDuration!.inMinutes.toString().padLeft(2, '0')}:${(info.videoDuration!.inSeconds % 60).toString().padLeft(2, '0')}'
      : null;


    return Row(
      children: [
        if (widget.asset.type == AssetType.video && widget.asset.width >= 3840)
          const Text('4K', style: TextStyle(color: Colors.white)),
        if (widget.asset.type != AssetType.video)
          Text('$megaPixels MP', style: const TextStyle(color: Colors.white)),

        _buildDotSeparator(),
        Text('${widget.asset.width} x ${widget.asset.height}', style: const TextStyle(color: Colors.white)),
        
        if(fileSizeMB != null) ...[
          _buildDotSeparator(),
          Text('$fileSizeMB MB', style: const TextStyle(color: Colors.white)),
        ],

        if(widget.asset.isLivePhoto) ...[
          _buildDotSeparator(),
          const Icon(Icons.photo, color: Colors.white, size: 16),
        ],

        const Spacer(),
        
        if (frameRate != null) ...[
          Text('$frameRate FPS', style: const TextStyle(color: Colors.white)),
          const SizedBox(width: 8),
        ],

        if (duration != null)
          Text(duration, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  /// 写真のExif詳細情報行
  Widget _buildPhotoExifDetailRow(String? iso, String? focalLength, String? fNumber, String? exposureTime) {
    return Column(
      children: [
        const Divider(color: Colors.white24, height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (iso != null) _buildExifItem('ISO $iso'),
            if (focalLength != null) _buildExifItem('$focalLength mm'),
            // TODO: Add 'ev' when available
            if (fNumber != null) _buildExifItem('f/$fNumber'),
            if (exposureTime != null) _buildExifItem('$exposureTime s'),
          ],
        ),
      ],
    );
  }
  
  Widget _buildExifItem(String text) {
    return Text(text, style: const TextStyle(color: Colors.white, fontSize: 12));
  }

  Widget _buildDotSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.0),
      child: Icon(Icons.circle, size: 3, color: Colors.white54),
    );
  }
}
