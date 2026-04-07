import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/tenant_provider.dart';

class ProductSettingsNotifier extends Notifier<bool> {
  static const _key = 'product_archival_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? true; // Default to true as per user request (Archive idea was "excellent")
  }

  Future<void> setArchivalEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
    state = enabled;
  }

  void toggle() {
    setArchivalEnabled(!state);
  }
}

final productArchivalEnabledProvider = NotifierProvider<ProductSettingsNotifier, bool>(ProductSettingsNotifier.new);
