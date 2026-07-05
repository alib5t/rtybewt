import 'dart:io';
import 'package:flutter/material.dart';
import '../models/video_segment.dart';
import '../theme/app_theme.dart';

class SegmentCard extends StatelessWidget {
  final VideoSegment segment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final bool saving;

  const SegmentCard({
    super.key,
    required this.segment,
    required this.onSave,
    required this.onShare,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _Thumbnail(path: segment.thumbnailPath, index: segment.index),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDuration(segment.start)} – ${formatDuration(segment.end)}'
                  '  ·  ${formatDuration(segment.duration)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                if (segment.savedToGallery) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(Icons.check_circle_rounded,
                          size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Galeriye kaydedildi',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded,
                color: AppColors.textSecondary),
          ),
          IconButton(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    segment.savedToGallery
                        ? Icons.download_done_rounded
                        : Icons.download_rounded,
                    color: segment.savedToGallery
                        ? AppColors.success
                        : AppColors.primary,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? path;
  final int index;
  const _Thumbnail({required this.path, required this.index});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    if (path != null && File(path!).existsSync()) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(path!),
          width: 64,
          height: 64,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }
}