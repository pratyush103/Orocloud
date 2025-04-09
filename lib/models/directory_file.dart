class Directory {
  final String id;
  final String name;
  final String date;
  final bool isStarred;
  final int fileCount;

  Directory({
    required this.id,
    required this.name,
    required this.date,
    this.isStarred = false,
    this.fileCount = 0,
  });
}
