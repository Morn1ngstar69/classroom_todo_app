class CourseModel {
  final String id;
  final String name;
  final String? section;

  CourseModel({
    required this.id,
    required this.name,
    this.section,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      section: json['section'],
    );
  }
}