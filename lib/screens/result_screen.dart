import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../models/video_segment.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/segment_card.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final List<VideoSegment> segments;
  const ResultScreen({super.key, required this.segments});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _gallery = GalleryService();
  final Set<int> _savingIndexes = {};
  bool _savingAll = false;

  Future<void> _saveOne(VideoSegment segment) async {
    setState(() => _savingIndexes.add(segment.index));
    try {
      final saved = await _gallery.saveVideo(segment.filePath);
      if (!mounted) return;
      setState(() => segment.savedToGallery = saved);
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Galeri izni verilmedi.')),
        );
      }
    } on GalException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_gallery.messageForError(e))),
      );
    } finally {
      if (mounted) setState(() => _savingIndexes.remove(segment.index));
    }
  }

  Future<void> _saveAll() async {
    setState(() => _savingAll = true);
    for (final segment in widget.segments) {
      if (segment.savedToGallery) continue;
      await _saveOne(segment);
    }
    if (!mounted) return;
    setState(() => _savingAll = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tüm parçalar galeriye kaydedildi 🎉')),
    );
  }

  Future<void> _shareOne(VideoSegment segment) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(segment.filePath)], text: segment.label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSaved = widget.segments.every((s) => s.savedToGallery);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.segments.length} Parça Hazır'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.segments.length,
                itemBuilder: (context, i) {
                  final segment = widget.segments[i];
                  return SegmentCard(
                    segment: segment,
                    saving: _savingIndexes.contains(segment.index),
                    onSave: () => _saveOne(segment),
                    onShare: () => _shareOne(segment),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            GradientButton(
              label: allSaved ? 'Hepsi Kaydedildi ✓' : 'Tümünü Galeriye Kaydet',
              icon: Icons.save_alt_rounded,
              loading: _savingAll,
              onPressed: allSaved ? null : _saveAll,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'Yeni video ile başla',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
