import 'package:flutter/material.dart';
import '../models/material_item.dart';
import '../services/drive_service.dart';
import '../services/materials_service.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final MaterialsService _materialsService = MaterialsService();
  final DriveService _driveService = DriveService();

  bool _loading = true;
  List<MaterialItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _loading = true);

    try {
      final items = await _materialsService.fetchAllMaterials();
      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load materials: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download(MaterialItem item) async {
    try {
      final files = await _driveService.downloadMaterial(item);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded ${files.length} file(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<MaterialItem>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.courseName, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Materials'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: grouped.entries.map((entry) {
          return ExpansionTile(
            title: Text(entry.key),
            children: entry.value.map((item) {
              return ListTile(
                title: Text(item.title),
                subtitle: Text(item.type),
                trailing: (item.type == 'drive_file' ||
                    item.type == 'drive_folder')
                    ? IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _download(item),
                )
                    : const Icon(Icons.link),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}