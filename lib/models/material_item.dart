class MaterialItem {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String type; // classroom_file, drive_file, drive_folder, link
  final String? fileId;
  final String? folderId;
  final String? url;
  final String? mimeType;

  MaterialItem({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.type,
    this.fileId,
    this.folderId,
    this.url,
    this.mimeType,
  });
}