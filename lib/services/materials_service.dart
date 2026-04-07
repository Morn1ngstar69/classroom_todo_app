import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/course_model.dart';
import '../models/material_item.dart';
import 'auth_service.dart';
import 'classroom_service.dart';

class MaterialsService {
  final AuthService _authService = AuthService();
  final ClassroomService _classroomService = ClassroomService();

  static const String targetSection = 'B';

  bool _matchesTargetSection(String? section) {
    if (section == null) return false;

    final normalized = section.trim().toUpperCase();

    return normalized == targetSection ||
        normalized.contains('SECTION $targetSection') ||
        normalized.contains('SEC $targetSection') ||
        normalized.contains(targetSection);
  }

  Future<List<MaterialItem>> fetchAllMaterials() async {
    final headers = await _authService.getGoogleAuthHeaders();
    final allCourses = await _classroomService.fetchCourses(headers);

    final filteredCourses = allCourses.where((course) {
      return _matchesTargetSection(course.section);
    }).toList();

    final items = <MaterialItem>[];

    for (final course in filteredCourses) {
      final courseWorkMaterials =
      await _fetchCourseWorkMaterials(headers, course);

      final announcements = await _fetchAnnouncements(headers, course);

      items.addAll(courseWorkMaterials);
      items.addAll(announcements);
    }

    return items;
  }

  Future<List<MaterialItem>> _fetchCourseWorkMaterials(
      Map<String, String> headers,
      CourseModel course,
      ) async {
    final uri = Uri.parse(
      'https://classroom.googleapis.com/v1/courses/${course.id}/courseWorkMaterials',
    );

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch courseWorkMaterials for ${course.name}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (data['courseWorkMaterial'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final materials = <MaterialItem>[];

    for (final post in list) {
      final title = post['title'] ?? 'Untitled Material';
      final postId = post['id'] ?? '';

      final rawMaterials = (post['materials'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      for (final m in rawMaterials) {
        final parsed = _parseMaterial(
          course: course,
          postId: postId,
          title: title,
          material: m,
        );
        if (parsed != null) {
          materials.add(parsed);
        }
      }
    }

    return materials;
  }

  Future<List<MaterialItem>> _fetchAnnouncements(
      Map<String, String> headers,
      CourseModel course,
      ) async {
    final uri = Uri.parse(
      'https://classroom.googleapis.com/v1/courses/${course.id}/announcements',
    );

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch announcements for ${course.name}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list =
    (data['announcements'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final materials = <MaterialItem>[];

    for (final post in list) {
      final title = post['text'] ?? 'Announcement';
      final postId = post['id'] ?? '';

      final rawMaterials = (post['materials'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      for (final m in rawMaterials) {
        final parsed = _parseMaterial(
          course: course,
          postId: postId,
          title: title,
          material: m,
        );
        if (parsed != null) {
          materials.add(parsed);
        }
      }
    }

    return materials;
  }

  MaterialItem? _parseMaterial({
    required CourseModel course,
    required String postId,
    required String title,
    required Map<String, dynamic> material,
  }) {
    if (material['driveFile'] != null) {
      final driveFile = material['driveFile']['driveFile'];
      final fileId = driveFile?['id'];
      final fileTitle = driveFile?['title'] ?? title;
      final alternateLink = driveFile?['alternateLink'];

      return MaterialItem(
        id: '${course.id}_${postId}_drive_$fileId',
        courseId: course.id,
        courseName: course.name,
        title: fileTitle,
        type: 'drive_file',
        fileId: fileId,
        url: alternateLink,
      );
    }

    if (material['sharedDriveFile'] != null) {
      final driveFile = material['sharedDriveFile']['driveFile'];
      final fileId = driveFile?['id'];
      final fileTitle = driveFile?['title'] ?? title;
      final alternateLink = driveFile?['alternateLink'];

      return MaterialItem(
        id: '${course.id}_${postId}_shared_drive_$fileId',
        courseId: course.id,
        courseName: course.name,
        title: fileTitle,
        type: 'drive_file',
        fileId: fileId,
        url: alternateLink,
      );
    }

    if (material['link'] != null) {
      final link = material['link'];
      final url = link['url'] as String?;
      final linkTitle = link['title'] ?? title;

      final folderId = _extractDriveFolderId(url);
      if (folderId != null) {
        return MaterialItem(
          id: '${course.id}_${postId}_folder_$folderId',
          courseId: course.id,
          courseName: course.name,
          title: linkTitle,
          type: 'drive_folder',
          folderId: folderId,
          url: url,
        );
      }

      return MaterialItem(
        id: '${course.id}_${postId}_link',
        courseId: course.id,
        courseName: course.name,
        title: linkTitle,
        type: 'link',
        url: url,
      );
    }

    return null;
  }

  String? _extractDriveFolderId(String? url) {
    if (url == null) return null;

    final regex = RegExp(r'folders\/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
}