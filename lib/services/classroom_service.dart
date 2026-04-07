import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/course_model.dart';

class ClassroomService {
  Future<List<CourseModel>> fetchCourses(Map<String, String> headers) async {
    final uri = Uri.parse(
      'https://classroom.googleapis.com/v1/courses?courseStates=ACTIVE',
    );

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch courses: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawCourses = (data['courses'] as List<dynamic>? ?? []);

    return rawCourses
        .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchCourseWork(
      Map<String, String> headers,
      String courseId,
      ) async {
    final uri = Uri.parse(
      'https://classroom.googleapis.com/v1/courses/$courseId/courseWork',
    );

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch coursework: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['courseWork'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }
}