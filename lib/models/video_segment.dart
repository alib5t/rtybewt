/// Bölünmüş bir video parçasını temsil eder.
class VideoSegment {
  final int index;
  final String filePath;
  final String? thumbnailPath;
  final Duration start;
  final Duration end;
  bool savedToGallery;

  VideoSegment({
    required this.index,
    required this.filePath,
    required this.start,
    required this.end,
    this.thumbnailPath,
    this.savedToGallery = false,
  });

  Duration get duration => end - start;

  String get label => 'Parça ${index + 1}';
}

/// mm:ss formatlı süre metni üretir (1 saatten uzun videolarda saat de ekler).
String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$mm:$ss';
  }
  return '$mm:$ss';
}
