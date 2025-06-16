import 'package:flutter/material.dart';
import 'package:pictory/providers/albums_provider.dart';
import 'package:provider/provider.dart';
import 'widgets/album_item_card.dart';

/// アルバム一覧を表示する画面
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  @override
  void initState() {
    super.initState();
    // 画面のビルドが完了した直後にアルバムデータを読み込む
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // readを使い、Providerのメソッドを一度だけ呼び出す
      context.read<AlbumsProvider>().loadAlbums();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
      ),
      // Consumerを使ってProviderの状態変更を監視する
      body: Consumer<AlbumsProvider>(
        builder: (context, provider, child) {
          // 読み込み中で、かつアルバムがまだ一件もない場合
          if (provider.loading && provider.albums.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // アルバムが一件もない場合
          if (provider.albums.isEmpty) {
            return const Center(child: Text('No albums found.'));
          }

          final albums = provider.albums;

          // GridViewでアルバムをタイル表示
          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2列で表示
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              // 各アルバムの表示はAlbumItemCardウィジェットに任せる
              return AlbumItemCard(album: album);
            },
          );
        },
      ),
    );
  }
}
