import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/downloader_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/info_banner.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _downloader = DownloaderService();
  bool _busy = false;

  Future<void> _pickFromDevice() async {
    final xfile = await _picker.pickVideo(source: ImageSource.gallery);
    if (xfile == null || !mounted) return;
    _openEditor(xfile.path);
  }

  void _openEditor(String path) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorScreen(videoPath: path)),
    );
  }

  Future<void> _showUrlSheet() async {
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: _UrlSheet(
            controller: controller,
            onSubmit: (url) async {
              Navigator.of(sheetContext).pop();
              await _downloadFromUrl(url);
            },
          ),
        );
      },
    );
  }

  Future<void> _downloadFromUrl(String url) async {
    final unsupported = _downloader.checkUnsupported(url);
    if (unsupported != null) {
      if (!mounted) return;
      _showUnsupportedDialog(unsupported);
      return;
    }

    setState(() => _busy = true);
    final progressNotifier = ValueNotifier<double>(0);

    // Kasıtlı olarak await edilmiyor: dialog kapanana kadar arka planda kalsın.
    // ignore: unawaited_futures
    _showProgressDialog(progressNotifier);

    try {
      final path = await _downloader.downloadDirectVideo(
        url: url,
        onProgress: (p) => progressNotifier.value = p,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // progress dialog'u kapat
      _openEditor(path);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İndirme başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showProgressDialog(ValueNotifier<double> progress) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Video indiriliyor…',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: value == 0 ? null : value),
              const SizedBox(height: 8),
              Text('${(value * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnsupportedDialog(String platform) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$platform bağlantıları desteklenmiyor'),
        content: Text(
          '$platform\'un kullanım şartları, kendi platformları dışında '
          'video indirilmesine izin vermiyor ve bu tür özellikler App '
          'Store / Play Store tarafından reddediliyor.\n\n'
          'Bunun yerine: $platform uygulamasındaki "Kaydet / Paylaş" '
          'seçeneğiyle videoyu cihazına indir, sonra burada '
          '"Cihazdan Seç" ile içeri aktar.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anladım'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickFromDevice();
            },
            child: const Text('Cihazdan Seç'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(),
              const SizedBox(height: 28),
              GradientButton(
                label: 'Cihazdan Video Seç',
                icon: Icons.video_library_rounded,
                onPressed: _busy ? null : _pickFromDevice,
              ),
              const SizedBox(height: 14),
              GradientButton(
                label: 'Bağlantıdan İndir',
                icon: Icons.link_rounded,
                gradient: const LinearGradient(
                  colors: [AppColors.accentBlue, AppColors.primary],
                ),
                onPressed: _busy ? null : _showUrlSheet,
              ),
              const SizedBox(height: 24),
              const InfoBanner(
                title: 'YouTube / Instagram hakkında',
                message:
                    'Bu platformlardan doğrudan indirme desteklenmiyor '
                    '(kullanım şartları + mağaza politikaları). '
                    'Videoyu platformun kendi "kaydet" özelliğiyle '
                    'indirip "Cihazdan Seç" ile bölebilirsin. '
                    '"Bağlantıdan İndir" yalnızca doğrudan video '
                    'dosyası linkleri (.mp4 vb.) içindir.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.content_cut_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 14),
          Text(
            'Video Splitter',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Videolarını saniyeler içinde parçalara böl ve\n'
            'doğrudan galerine kaydet.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _UrlSheet extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  const _UrlSheet({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Video Bağlantısı',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'Doğrudan bir video dosyası linki yapıştır (.mp4, .mov …)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'https://…/video.mp4',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: 'İndir',
            icon: Icons.download_rounded,
            onPressed: () {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              onSubmit(url);
            },
          ),
        ],
      ),
    );
  }
}
