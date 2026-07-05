import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Kullanıcı YouTube/Instagram gibi platformların linkini yapıştırdığında
/// fırlatılır. Bu servis KASITLI olarak bu platformları desteklemez -
/// nedeni README.md'de açıklanmıştır (ToS + mağaza politikaları).
class UnsupportedPlatformException implements Exception {
  final String platform;
  UnsupportedPlatformException(this.platform);

  @override
  String toString() =>
      '$platform bağlantıları desteklenmiyor. Lütfen doğrudan video '
      'dosyası bağlantısı kullanın veya videoyu önce cihazına indirip '
      '"Cihazdan Seç" seçeneğini kullanın.';
}

class DownloadCancelledException implements Exception {}

/// Yalnızca DOĞRUDAN video dosyası URL'lerini indirir
/// (örn. https://.../video.mp4, kendi sunucun, CDN, vb).
/// YouTube / Instagram gibi platformlardan indirme; onların Kullanım
/// Şartları'nı ihlal ettiği ve App Store / Play Store politikalarıyla
/// çeliştiği için buraya BİLİNÇLİ olarak eklenmemiştir.
class DownloaderService {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  static const _blockedHosts = [
    'youtube.com',
    'youtu.be',
    'm.youtube.com',
    'instagram.com',
    'instagr.am',
    'tiktok.com',
    'facebook.com',
    'fb.watch',
  ];

  /// URL'nin desteklenmeyen bir platforma ait olup olmadığını kontrol eder.
  /// Desteklenmiyorsa platform adını, destekleniyorsa null döner.
  String? checkUnsupported(String url) {
    Uri? uri;
    try {
      uri = Uri.parse(url.trim());
    } catch (_) {
      return null;
    }
    final host = uri.host.toLowerCase();
    for (final blocked in _blockedHosts) {
      if (host == blocked || host.endsWith('.$blocked')) {
        return _prettyName(blocked);
      }
    }
    return null;
  }

  String _prettyName(String host) {
    if (host.contains('youtu')) return 'YouTube';
    if (host.contains('instagr')) return 'Instagram';
    if (host.contains('tiktok')) return 'TikTok';
    if (host.contains('facebook') || host.contains('fb.watch')) return 'Facebook';
    return host;
  }

  /// Doğrudan video dosyasını indirir. [onProgress] 0.0-1.0 arası ilerleme verir.
  Future<String> downloadDirectVideo({
    required String url,
    required void Function(double progress) onProgress,
  }) async {
    final unsupported = checkUnsupported(url);
    if (unsupported != null) {
      throw UnsupportedPlatformException(unsupported);
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = '${const Uuid().v4()}.mp4';
    final savePath = '${tempDir.path}/$fileName';

    _cancelToken = CancelToken();

    await _dio.download(
      url,
      savePath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress(received / total);
        }
      },
      options: Options(
        followRedirects: true,
        headers: {
          // Bazı CDN'ler User-Agent olmadan isteği reddediyor.
          'User-Agent':
              'Mozilla/5.0 (compatible; VideoSplitterApp/1.0; +flutter)',
        },
      ),
    );

    final file = File(savePath);
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('Dosya indirilemedi. Bağlantıyı kontrol et.');
    }
    return savePath;
  }

  void cancel() {
    _cancelToken?.cancel();
  }
}