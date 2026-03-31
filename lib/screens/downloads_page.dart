import 'package:flutter/material.dart';
import 'download_manager.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  void removerDownload(int index) {
    setState(() {
      DownloadManager.downloads.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roxo = Theme.of(context).colorScheme.primary;

    if (DownloadManager.downloads.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: roxo.withOpacity(0.15)),
          ),
          child: const Text(
            'Nenhum download ainda',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: DownloadManager.downloads.length,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: roxo.withOpacity(0.12),
              child: Icon(Icons.download_done_rounded, color: roxo),
            ),
            title: Text(
              DownloadManager.downloads[index],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Disponível offline'),
            trailing: IconButton(
              icon: Icon(Icons.delete_rounded, color: roxo),
              onPressed: () => removerDownload(index),
            ),
          ),
        );
      },
    );
  }
}
