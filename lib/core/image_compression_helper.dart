import 'dart:typed_data';

class ImageCompressionHelper {
  static const int maxBytes = 800 * 1024; // 800 KB

  static bool isWithinLimit(Uint8List bytes) => bytes.lengthInBytes <= maxBytes;

  static String? validateImageSize(Uint8List bytes) {
    if (!isWithinLimit(bytes)) {
      final kb = (bytes.lengthInBytes / 1024).round();
      return 'حجم الصورة ($kb KB) يتجاوز الحد المسموح (800 KB). يرجى اختيار صورة مضغوطة.';
    }
    return null;
  }
}
