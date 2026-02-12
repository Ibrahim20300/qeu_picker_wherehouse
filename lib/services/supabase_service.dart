import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Fetch all app settings as a key-value map.
  /// Expects a table `app_settings` with columns: `key` (text, PK), `value` (text).
  static Future<Map<String, String>> fetchAppSettings() async {
    final response = await client.from('app_settings').select('key, value');
    final Map<String, String> settings = {};
    for (final row in response as List) {
      settings[row['key'] as String] = row['value']?.toString() ?? '';
    }
    return settings;
  }

  /// Fetch a single setting by key.
  static Future<String?> fetchSetting(String key) async {
    final response = await client
        .from('app_settings')
        .select('value')
        .eq('key', key)
        .maybeSingle();
    return response?['value']?.toString();
  }

  /// Get a public URL for a file in Supabase Storage.
  static String getPublicUrl(String bucket, String path) {
    return client.storage.from(bucket).getPublicUrl(path);
  }
}
