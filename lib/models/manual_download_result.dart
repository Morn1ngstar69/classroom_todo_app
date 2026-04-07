class ManualDownloadResult {
  final String courseName;
  final String rootPath;
  final int downloadedFiles;
  final List<String> savedPaths;
  final List<String> skippedItems;

  ManualDownloadResult({
    required this.courseName,
    required this.rootPath,
    required this.downloadedFiles,
    required this.savedPaths,
    required this.skippedItems,
  });
}