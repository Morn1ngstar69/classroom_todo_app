import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/material_item.dart';
import 'auth_service.dart';

class DriveService {
  final AuthService _authService = AuthService();

  Future<Directory> _baseDownloadDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final target = Directory('${dir.path}/classroom_materials');

    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    return target;
  }

  Future<List<File>> downloadMaterial(MaterialItem item) async {
    final headers = await _authService.getGoogleAuthHeaders();

    if (item.type == 'drive_file' && item.fileId != null) {
      final file = await _downloadDriveFile(
        headers: headers,
        fileId: item.fileId!,
        preferredName: item.title,
      );
      return [file];
    }

    if (item.type == 'drive_folder' && item.folderId != null) {
      return await _downloadFolder(
        headers: headers,
        folderId: item.folderId!,
        folderName: item.title,
      );
    }

    return [];
  }

  Future<List<File>> _downloadFolder({
    required Map<String, String> headers,
    required String folderId,
    required String folderName,
  }) async {
    final baseDir = await _baseDownloadDir();
    final folderDir = Directory('${baseDir.path}/$folderName');

    if (!await folderDir.exists()) {
      await folderDir.create(recursive: true);
    }

    final query =
        "'$folderId' in parents and trashed = false";

    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files'
          '?q=${Uri.encodeQueryComponent(query)}'
          '&fields=files(id,name,mimeType)'
          '&supportsAllDrives=true'
          '&includeItemsFromAllDrives=true',
    );

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to list folder contents: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final files = (data['files'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final downloaded = <File>[];

    for (final file in files) {
      final mimeType = file['mimeType'] as String?;
      final fileId = file['id'] as String?;
      final name = file['name'] as String? ?? 'file';

      if (fileId == null) continue;

      // Skip subfolders for now; can be made recursive later.
      if (mimeType == 'application/vnd.google-apps.folder') {
        continue;
      }

      final downloadedFile = await _downloadDriveFile(
        headers: headers,
        fileId: fileId,
        preferredName: name,
        targetDir: folderDir,
      );

      downloaded.add(downloadedFile);
    }

    return downloaded;
  }

  Future<File> _downloadDriveFile({
    required Map<String, String> headers,
    required String fileId,
    required String preferredName,
    Directory? targetDir,
  }) async {
    final metadataUri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId'
          '?fields=id,name,mimeType,capabilities/canDownload'
          '&supportsAllDrives=true',
    );

    final metadataResponse = await http.get(metadataUri, headers: headers);

    if (metadataResponse.statusCode != 200) {
      throw Exception('Failed to get file metadata: ${metadataResponse.body}');
    }

    final metadata =
    jsonDecode(metadataResponse.body) as Map<String, dynamic>;

    final mimeType = metadata['mimeType'] as String? ?? '';
    final canDownload =
        (metadata['capabilities']?['canDownload'] as bool?) ?? false;

    if (!canDownload) {
      throw Exception('This file cannot be downloaded');
    }

    final dir = targetDir ?? await _baseDownloadDir();

    if (mimeType == 'application/vnd.google-apps.document') {
      return _exportGoogleFile(
        headers: headers,
        fileId: fileId,
        exportMimeType: 'application/pdf',
        filePath: '${dir.path}/$preferredName.pdf',
      );
    }

    if (mimeType == 'application/vnd.google-apps.presentation') {
      return _exportGoogleFile(
        headers: headers,
        fileId: fileId,
        exportMimeType: 'application/pdf',
        filePath: '${dir.path}/$preferredName.pdf',
      );
    }

    if (mimeType == 'application/vnd.google-apps.spreadsheet') {
      return _exportGoogleFile(
        headers: headers,
        fileId: fileId,
        exportMimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        filePath: '${dir.path}/$preferredName.xlsx',
      );
    }

    final mediaUri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId'
          '?alt=media&supportsAllDrives=true',
    );

    final mediaResponse = await http.get(mediaUri, headers: headers);

    if (mediaResponse.statusCode != 200) {
      throw Exception('Failed to download file: ${mediaResponse.body}');
    }

    final path = '${dir.path}/$preferredName';
    final file = File(path);
    await file.writeAsBytes(mediaResponse.bodyBytes);

    return file;
  }

  Future<File> _exportGoogleFile({
    required Map<String, String> headers,
    required String fileId,
    required String exportMimeType,
    required String filePath,
  }) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId/export'
          '?mimeType=${Uri.encodeQueryComponent(exportMimeType)}',
    );

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to export file: ${response.body}');
    }

    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    return file;
  }
}