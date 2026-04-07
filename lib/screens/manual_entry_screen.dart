import 'package:flutter/material.dart';
import '../models/manual_download_result.dart';
import '../services/manual_drive_material_service.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _courseController = TextEditingController();
  final _linkController = TextEditingController();
  final _service = ManualDriveMaterialService();

  bool _loading = false;
  ManualDownloadResult? _result;

  @override
  void dispose() {
    _courseController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final courseName = _courseController.text.trim();
    final link = _linkController.text.trim();

    if (courseName.isEmpty || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both course name and Drive link')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final result = await _service.downloadFromDriveLink(
        courseName: courseName,
        driveLink: link,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded ${result.downloadedFiles} file(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Manual download failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Entry'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _courseController,
              decoration: const InputDecoration(
                labelText: 'Course name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Google Drive file/folder link',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _download,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Download Materials'),
              ),
            ),
            const SizedBox(height: 16),
            if (result != null)
              Expanded(
                child: ListView(
                  children: [
                    Text('Saved under: ${result.rootPath}'),
                    const SizedBox(height: 8),
                    Text('Downloaded files: ${result.downloadedFiles}'),
                    const SizedBox(height: 12),
                    const Text(
                      'Saved files',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...result.savedPaths.map((p) => ListTile(title: Text(p))),
                    if (result.skippedItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Skipped items',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...result.skippedItems.map((s) => ListTile(title: Text(s))),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}