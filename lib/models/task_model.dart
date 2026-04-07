class TaskModel {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String? description;
  final String? alternateLink;
  final DateTime? dueAtUtc;
  final DateTime? remindAtUtc;
  final bool notified48h;

  TaskModel({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    this.description,
    this.alternateLink,
    this.dueAtUtc,
    this.remindAtUtc,
    this.notified48h = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'title': title,
      'description': description,
      'alternateLink': alternateLink,
      'dueAtUtc': dueAtUtc?.toIso8601String(),
      'remindAtUtc': remindAtUtc?.toIso8601String(),
      'notified48h': notified48h,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory TaskModel.fromMap(String id, Map<String, dynamic> map) {
    return TaskModel(
      id: id,
      courseId: map['courseId'] ?? '',
      courseName: map['courseName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      alternateLink: map['alternateLink'],
      dueAtUtc: map['dueAtUtc'] != null
          ? DateTime.parse(map['dueAtUtc'])
          : null,
      remindAtUtc: map['remindAtUtc'] != null
          ? DateTime.parse(map['remindAtUtc'])
          : null,
      notified48h: map['notified48h'] ?? false,
    );
  }
}