import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/manual_download_result.dart';
import 'auth_service.dart';

class ManualDriveMaterialService {
  final AuthService _authService = AuthService();

  Future<ManualDownloadResult> downloadFromDriveLink({
    required String courseName,
    required String driveLink,
  }) async {
    final headers = await _authService.getGoogleAuthHeaders();

    final baseDir = await getApplicationDocumentsDirectory();
    final safeCourseName = _sanitizeFileName(courseName);
    final courseDir = Directory('${baseDir.path}/classroom_materials/$safeCourseName');

    if (!await courseDir.exists()) {
      await courseDir.create(recursive: true);
    }

    final folderId = _extractFolderId(driveLink);
    final fileId = _extractFileId(driveLink);

    final savedPaths = <String>[];
    final skippedItems = <String>[];

    if (folderId != null) {
      await _downloadFolderRecursive(
        headers: headers,
        folderId: folderId,
        targetDir: courseDir,
        savedPaths: savedPaths,
        skippedItems: skippedItems,
      );
    } else if (fileId != null) {
      final file = await _downloadSingleDriveFile(
        headers: headers,
        fileId: fileId,
        targetDir: courseDir,
      );
      if (file != null) {
        savedPaths.add(file.path);
      }
    } else {
      throw Exception('Invalid Google Drive link. Please enter a valid file or folder link.');
    }

    return ManualDownloadResult(
      courseName: courseName,
      rootPath: courseDir.path,
      downloadedFiles: savedPaths.length,
      savedPaths: savedPaths,
      skippedItems: skippedItems,
    );
  }

  Future<void> _downloadFolderRecursive({
    required Map<String, String> headers,
    required String folderId,
    required Directory targetDir,
    required List<String> savedPaths,
    required List<String> skippedItems,
  }) async {
    String? pageToken;

    do {
      final query = "'$folderId' in parents and trashed = false";

      final uri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files'
            '?q=${Uri.encodeQueryComponent(query)}'
            '&fields=nextPageToken,files(id,name,mimeType,capabilities/canDownload)'
            '&supportsAllDrives=true'
            '&includeItemsFromAllDrives=true'
            '${pageToken != null ? '&pageToken=$pageToken' : ''}',
      );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode != 200) {
        throw Exception('Failed to list Drive folder contents: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final files = (data['files'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      for (final file in files) {
        final id = file['id'] as String?;
        final name = file['name'] as String? ?? 'Unnamed';
        final mimeType = file['mimeType'] as String? ?? '';

        if (id == null) continue;

        if (mimeType == 'application/vnd.google-apps.folder') {
          final subDir = Directory('${targetDir.path}/${_sanitizeFileName(name)}');
          if (!await subDir.exists()) {
            await subDir.create(recursive: true);
          }

          await _downloadFolderRecursive(
            headers: headers,
            folderId: id,
            targetDir: subDir,
            savedPaths: savedPaths,
            skippedItems: skippedItems,
          );
          continue;
        }

        final downloaded = await _downloadDriveFileByMetadata(
          headers: headers,
          fileId: id,
          fileName: name,
          mimeType: mimeType,
          targetDir: targetDir,
        );

        if (downloaded != null) {
          savedPaths.add(downloaded.path);
        } else {
          skippedItems.add(name);
        }
      }

      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);
  }

  Future<File?> _downloadSingleDriveFile({
    required Map<String, String> headers,
    required String fileId,
    required Directory targetDir,
  }) async {
    final metadataUri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId'
          '?fields=id,name,mimeType,capabilities/canDownload'
          '&supportsAllDrives=true',
    );

    final response = await http.get(metadataUri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to get Drive file metadata: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return _downloadDriveFileByMetadata(
      headers: headers,
      fileId: data['id'] as String,
      fileName: data['name'] as String? ?? 'file',
      mimeType: data['mimeType'] as String? ?? '',
      targetDir: targetDir,
    );
  }

  Future<File?> _downloadDriveFileByMetadata({
    required Map<String, String> headers,
    required String fileId,
    required String fileName,
    required String mimeType,
    required Directory targetDir,
  }) async {
    final safeName = _sanitizeFileName(fileName);

    if (mimeType == 'application/vnd.google-apps.document') {
      return _exportGoogleFile(
        headers: headers,
        fileId: fileId,
        exportMimeType: 'application/pdf',
        outputPath: '${targetDir.path}/$safeName.pdf',
      );
    }

    if (mimeType == 'application/vnd.google-apps.presentation') {
      return _exportGoogleFile(
        headers: headers,
        fileId: fileId,
        exportMimeType: 'application/pdf',
        outputPath: '${targetDir.path}/$safeName.pdf',
      );
    }

    if (mimeType == 'application/vnd.google-apps.spreadsheet') {
      return _exportGoogleFile(
        headers: headers,
        fileId: fileId,
        exportMimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        outputPath: '${targetDir.path}/$safeName.xlsx',
      );
    }

    if (mimeType == 'application/vnd.google-apps.folder') {
      return null;
    }

    final mediaUri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId'
          '?alt=media&supportsAllDrives=true',
    );

    final mediaResponse = await http.get(mediaUri, headers: headers);

    if (mediaResponse.statusCode != 200) {
      throw Exception('Failed to download file: ${mediaResponse.body}');
    }

    final file = File('${targetDir.path}/$safeName');
    await file.writeAsBytes(mediaResponse.bodyBytes);
    return file;
  }

  Future<File> _exportGoogleFile({
    required Map<String, String> headers,
    required String fileId,
    required String exportMimeType,
    required String outputPath,
  }) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId/export'
          '?mimeType=${Uri.encodeQueryComponent(exportMimeType)}',
    );

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to export Google file: ${response.body}');
    }

    final file = File(outputPath);
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  String? _extractFolderId(String url) {
    final folderRegex = RegExp(r'folders/([a-zA-Z0-9_-]+)');
    final match = folderRegex.firstMatch(url);
    return match?.group(1);
  }

  String? _extractFileId(String url) {
    final fileRegex1 = RegExp(r'/d/([a-zA-Z0-9_-]+)');
    final fileRegex2 = RegExp(r'id=([a-zA-Z0-9_-]+)');

    final match1 = fileRegex1.firstMatch(url);
    if (match1 != null) {
      final id = match1.group(1);
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    final match2 = fileRegex2.firstMatch(url);
    if (match2 != null) {
      final id = match2.group(1);
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    return null;
  }

  String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }
}