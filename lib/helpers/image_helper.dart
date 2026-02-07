class ImageHelper {
  static String buildImageUrl(
    String originalUrl, {
    int? width,
    int? height,
    String format = 'webp',
    int quality = 80,
  }) {
    final uri = Uri.parse(originalUrl);
    final path = uri.path;

    final params = [
      if (width != null) 'width=$width',
      if (height != null) 'height=$height',
      'format=$format',
      'quality=$quality',
    ].join(',');

    return '${uri.scheme}://${uri.host}/cdn-cgi/image/$params$path';
  }
}
