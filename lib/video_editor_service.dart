import 'dart:io';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/video_segment.dart';

/// Videoyu FFmpeg olmadan, cihazın native video API'lerini kullanarak
/// (Android: Media3, iOS: AVFoundation) parçalara böler.
///
/// Mantık: her parça için orijinal dosyadan YENİ bir VideoEditorBuilder
/// oluşturup sadece o aralığı `trim` ediyoruz. Böylece parçalar birbirinden
/// bağımsız ve kalite kaybı zincirlenmiyor.
class VideoEditorService {
  static const _uuid = Uuid();

  /// Videonun toplam süresini ve temel bilgilerini döner.
  Future<VideoMetadata> getMetadata(String videoPath) {
    final editor = VideoEditorBuilder(videoPath: videoPath);
    return editor.getVideoMetadata();
  }

  /// Videoyu belirtilen kesme noktalarına (ms cinsinden, sıralı, video
  /// süresinin İÇİNDE) göre N parçaya böler.
  ///
  /// Örnek: total=100000ms, cutPoints=[30000, 60000] -> 3 parça:
  /// [0-30000], [30000-60000], [60000-100000]
  Future<List<VideoSegment>> splitAtCutPoints({
    required String videoPath,
    required List<int> cutPointsMs,
    required int totalDurationMs,
    void Function(double overallProgress)? onProgress,
  }) async {
    final boundaries = <int>[0, ...cutPointsMs, totalDurationMs]..sort();
    final outputDir = await _outputDir();
    final segments = <VideoSegment>[];

    for (var i = 0; i < boundaries.length - 1; i++) {
      final start = boundaries[i];
      final end = boundaries[i + 1];
      if (end - start < 300) continue; // 300ms altı anlamsız mikro parçaları atla

      final outputPath = '${outputDir.path}/split_${_uuid.v4()}.mp4';

      final editor = VideoEditorBuilder(videoPath: videoPath)
          .trim(startTimeMs: start, endTimeMs: end);

      await editor.export(
        outputPath: outputPath,
        onProgress: (segmentProgress) {
          if (onProgress == null) return;
          final combined = (i + segmentProgress) / (boundaries.length - 1);
          onProgress(combined.clamp(0.0, 1.0));
        },
      );

      String? thumbPath;
      try {
        thumbPath = await VideoEditorBuilder(videoPath: outputPath)
            .generateThumbnail(positionMs: 0, quality: 70);
      } catch (_) {
        thumbPath = null; // Küçük resim üretilemezse sorun değil, UI ikonla devam eder
      }

      segments.add(
        VideoSegment(
          index: segments.length,
          filePath: outputPath,
          thumbnailPath: thumbPath,
          start: Duration(milliseconds: start),
          end: Duration(milliseconds: end),
        ),
      );
    }

    onProgress?.call(1.0);
    return segments;
  }

  /// Videoyu eşit uzunlukta [partCount] parçaya böler. Bu, en sık kullanılan
  /// senaryodur (örn. uzun bir videoyu 4 eşit parçaya bölmek).
  Future<List<VideoSegment>> splitIntoEqualParts({
    required String videoPath,
    required int partCount,
    required int totalDurationMs,
    void Function(double overallProgress)? onProgress,
  }) async {
    if (partCount < 2) {
      throw ArgumentError('En az 2 parça gerekir');
    }
    final step = totalDurationMs / partCount;
    final cutPoints = <int>[
      for (var i = 1; i < partCount; i++) (step * i).round(),
    ];
    return splitAtCutPoints(
      videoPath: videoPath,
      cutPointsMs: cutPoints,
      totalDurationMs: totalDurationMs,
      onProgress: onProgress,
    );
  }

  Future<Directory> _outputDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/splits');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}