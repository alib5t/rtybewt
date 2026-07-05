import 'package:gal/gal.dart';

/// Galeriye kaydetme işlemlerini ve izin akışını yönetir.
class GalleryService {
  /// İzin var mı kontrol eder, yoksa kullanıcıya sorar.
  Future<bool> ensurePermission() async {
    final hasAccess = await Gal.hasAccess();
    if (hasAccess) return true;
    return Gal.requestAccess();
  }

  /// Videoyu "VideoSplitter" albümüne kaydeder.
  /// Başarılıysa true, kullanıcı izni reddettiyse false döner.
  /// Diğer hatalarda [GalException] fırlatır (çağıran taraf yakalamalı).
  Future<bool> saveVideo(String path) async {
    final granted = await ensurePermission();
    if (!granted) return false;

    await Gal.putVideo(path, album: 'VideoSplitter');
    return true;
  }

  String messageForError(GalException e) {
    switch (e.type) {
      case GalExceptionType.accessDenied:
        return 'Galeri izni verilmedi. Ayarlardan izin vermen gerekiyor.';
      case GalExceptionType.notEnoughSpace:
        return 'Cihazda yeterli depolama alanı yok.';
      case GalExceptionType.notSupportedFormat:
        return 'Bu dosya formatı desteklenmiyor.';
      case GalExceptionType.unexpected:
        return 'Beklenmeyen bir hata oluştu: ${e.platformException.message ?? ''}';
    }
  }
}