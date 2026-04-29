import 'package:hive/hive.dart';

void registerHiveAdapters() {
  // Adapters registered here when generated
  // For now using raw box with JSON strings
}

class LocalStorage {
  static final _box = Hive.box('wellness_box');

  static String? getUserId() => _box.get('user_id');
  static Future<void> setUserId(String id) => _box.put('user_id', id);

  static bool isOnboarded() => _box.get('onboarded', defaultValue: false);
  static Future<void> setOnboarded() => _box.put('onboarded', true);

  static String? getCachedRoutine() => _box.get('cached_routine');
  static Future<void> cacheRoutine(String json) => _box.put('cached_routine', json);

  static String? getCachedProfile() => _box.get('cached_profile');
  static Future<void> cacheProfile(String json) => _box.put('cached_profile', json);

  static String? getPendingRoute() => _box.get('pending_route');
  static Future<void> setPendingRoute(String route) => _box.put('pending_route', route);
  static Future<void> clearPendingRoute() => _box.delete('pending_route');
}
