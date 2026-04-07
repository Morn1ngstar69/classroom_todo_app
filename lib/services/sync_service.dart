import '../models/task_model.dart';
import 'auth_service.dart';
import 'classroom_service.dart';
import 'firestore_service.dart';

class SyncService {
  final AuthService _authService = AuthService();
  final ClassroomService _classroomService = ClassroomService();
  final FirestoreService _firestoreService = FirestoreService();

  static const String targetSection = 'B';

  DateTime? _buildDueAtUtc(Map<String, dynamic> item) {
    final dueDate = item['dueDate'];
    final dueTime = item['dueTime'];

    if (dueDate == null) return null;

    final year = dueDate['year'];
    final month = dueDate['month'];
    final day = dueDate['day'];

    final hour = dueTime?['hours'] ?? 23;
    final minute = dueTime?['minutes'] ?? 59;
    final second = dueTime?['seconds'] ?? 0;

    return DateTime.utc(year, month, day, hour, minute, second);
  }

  DateTime? _buildReminderAtUtc(DateTime? dueAtUtc) {
    if (dueAtUtc == null) return null;
    return dueAtUtc.subtract(const Duration(hours: 48));
  }

  bool _matchesTargetSection(String? section) {
    if (section == null) return false;

    final normalized = section.trim().toUpperCase();

    return normalized == targetSection ||
        normalized.contains('SECTION $targetSection') ||
        normalized.contains('SEC $targetSection') ||
        normalized.endsWith(targetSection);
  }

  Future<void> syncAll() async {
    final headers = await _authService.getGoogleAuthHeaders();
    final allCourses = await _classroomService.fetchCourses(headers);

    final filteredCourses = allCourses.where((course) {
      return _matchesTargetSection(course.section);
    }).toList();

    final allTasks = <TaskModel>[];

    for (final course in filteredCourses) {
      final coursework =
      await _classroomService.fetchCourseWork(headers, course.id);

      for (final item in coursework) {
        final dueAtUtc = _buildDueAtUtc(item);
        final remindAtUtc = _buildReminderAtUtc(dueAtUtc);

        allTasks.add(
          TaskModel(
            id: '${course.id}_${item['id'] ?? ''}',
            courseId: course.id,
            courseName: course.name,
            title: item['title'] ?? 'Untitled',
            description: item['description'],
            alternateLink: item['alternateLink'],
            dueAtUtc: dueAtUtc,
            remindAtUtc: remindAtUtc,
          ),
        );
      }
    }

    await _firestoreService.saveTasks(allTasks);
  }
}