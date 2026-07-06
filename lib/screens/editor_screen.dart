import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/video_editor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'result_screen.dart';

enum _SplitMode { equal, manual }

class EditorScreen extends StatefulWidget {
  final String videoPath;
  const EditorScreen({super.key, required this.videoPath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late VideoPlayerController _controller;
  final _editorService = VideoEditorService();

  bool _ready = false;
  bool _splitting = false;
  double _splitProgress = 0;

  _SplitMode _mode = _SplitMode.equal;
  int _equalParts = 2;
  final List<int> _cutPointsMs = [];

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(_asFile(widget.videoPath))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _totalMs => _controller.value.duration.inMilliseconds;

  void _addCutPointAtCurrentPosition() {
    final pos = _controller.value.position.inMilliseconds;
    if (pos <= 0 || pos >= _totalMs) return;
    if (_cutPointsMs.contains(pos)) return;
    setState(() {
      _cutPointsMs.add(pos);
      _cutPointsMs.sort();
    });
  }

  Future<void> _split() async {
    if (_mode == _SplitMode.manual && _cutPointsMs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir kesme noktası ekle.')),
      );
      return;
    }

    setState(() {
      _splitting = true;
      _splitProgress = 0;
    });

    try {
      final segments = _mode == _SplitMode.equal
          ? await _editorService.splitIntoEqualParts(
              videoPath: widget.videoPath,
              partCount: _equalParts,
              totalDurationMs: _totalMs,
              onProgress: (p) => setState(() => _splitProgress = p),
            )
          : await _editorService.splitAtCutPoints(
              videoPath: widget.videoPath,
              cutPointsMs: _cutPointsMs,
              totalDurationMs: _totalMs,
              onProgress: (p) => setState(() => _splitProgress = p),
            );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(segments: segments)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bölme başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _splitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Videoyu Böl')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VideoPreview(controller: _controller),
                  const SizedBox(height: 10),
                  _Scrubber(controller: _controller, cutPoints: _cutPointsMs),
                  const SizedBox(height: 24),
                  _ModeSwitch(
                    mode: _mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                  const SizedBox(height: 20),
                  if (_mode == _SplitMode.equal)
                    _EqualPartsStepper(
                      value: _equalParts,
                      onChanged: (v) => setState(() => _equalParts = v),
                    )
                  else
                    _ManualCutPoints(
                      totalMs: _totalMs,
                      cutPoints: _cutPointsMs,
                      onAdd: _addCutPointAtCurrentPosition,
                      onRemove: (ms) =>
                          setState(() => _cutPointsMs.remove(ms)),
                    ),
                  const SizedBox(height: 28),
                  if (_splitting) ...[
                    LinearProgressIndicator(value: _splitProgress),
                    const SizedBox(height: 8),
                    Text(
                      'Bölünüyor… ${(_splitProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                  ],
                  GradientButton(
                    label: _splitting ? 'Bölünüyor…' : 'Böl ve Devam Et',
                    icon: Icons.content_cut_rounded,
                    loading: _splitting,
                    onPressed: _splitting ? null : _split,
                  ),
                ],
              ),
            ),
    );
  }
}

File _asFile(String path) => File(path);

class _VideoPreview extends StatelessWidget {
  final VideoPlayerController controller;
  const _VideoPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            _PlayPauseButton(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final VideoPlayerController controller;
  const _PlayPauseButton({required this.controller});

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final playing = widget.controller.value.isPlaying;
    return GestureDetector(
      onTap: () {
        setState(() {
          playing ? widget.controller.pause() : widget.controller.play();
        });
      },
      child: AnimatedOpacity(
        opacity: playing ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 36),
        ),
      ),
    );
  }
}

class _Scrubber extends StatefulWidget {
  final VideoPlayerController controller;
  final List<int> cutPoints;
  const _Scrubber({required this.controller, required this.cutPoints});

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final total = widget.controller.value.duration.inMilliseconds;
    final pos = widget.controller.value.position.inMilliseconds
        .clamp(0, total == 0 ? 1 : total);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SliderTheme(
              data: SliderTheme.of(context),
              child: Slider(
                min: 0,
                max: total == 0 ? 1 : total.toDouble(),
                value: pos.toDouble(),
                onChanged: (v) {
                  widget.controller.seekTo(Duration(milliseconds: v.toInt()));
                },
              ),
            ),
            // Kesme noktalarını çizgi olarak göster
            IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (total == 0) return const SizedBox.shrink();
                  return Stack(
                    children: widget.cutPoints.map((ms) {
                      final fraction = ms / total;
                      return Positioned(
                        left: fraction * constraints.maxWidth,
                        child: Container(
                          width: 2,
                          height: 24,
                          color: AppColors.secondary,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(Duration(milliseconds: pos)),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text(_fmt(widget.controller.value.duration),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ModeSwitch extends StatelessWidget {
  final _SplitMode mode;
  final ValueChanged<_SplitMode> onChanged;
  const _ModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tab(context, 'Eşit Parçalar', _SplitMode.equal),
          _tab(context, 'Manuel Kesim', _SplitMode.manual),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, _SplitMode value) {
    final selected = mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _EqualPartsStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _EqualPartsStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Parça sayısı',
            style: TextStyle(fontWeight: FontWeight.w600)),
        Row(
          children: [
            _roundIconBtn(Icons.remove, () {
              if (value > 2) onChanged(value - 1);
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$value',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            _roundIconBtn(Icons.add, () {
              if (value < 10) onChanged(value + 1);
            }),
          ],
        ),
      ],
    );
  }

  Widget _roundIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _ManualCutPoints extends StatelessWidget {
  final int totalMs;
  final List<int> cutPoints;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ManualCutPoints({
    required this.totalMs,
    required this.cutPoints,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Kesme noktaları',
                style: TextStyle(fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_rounded, size: 18),
              label: const Text('Buraya böl'),
            ),
          ],
        ),
        if (cutPoints.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Videoyu oynat, bölmek istediğin ana gel ve '
              '"Buraya böl" butonuna bas.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cutPoints.map((ms) {
              final d = Duration(milliseconds: ms);
              final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
              final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
              return Chip(
                backgroundColor: AppColors.surface,
                label: Text('$m:$s'),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                onDeleted: () => onRemove(ms),
              );
            }).toList(),
          ),
      ],
    );
  }
}
