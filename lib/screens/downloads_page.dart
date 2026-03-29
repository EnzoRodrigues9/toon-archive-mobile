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
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: DownloadManager.downloads.length,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.download_done),
            title: Text(DownloadManager.downloads[index]),
            subtitle: const Text('Disponível offline'),

            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => removerDownload(index),
            ),
          ),
        );
      },
    );
  }
}
