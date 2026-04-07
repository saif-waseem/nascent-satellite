import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'tenant_provider.dart';

enum UIStyle {
  standard,
  modern,
}

class UIStyleNotifier extends Notifier<UIStyle> {
  static const _key = 'ui_style_preference';

  @override
  UIStyle build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_key);
    return saved == 'modern' ? UIStyle.modern : UIStyle.standard;
  }

  Future<void> setStyle(UIStyle style) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, style == UIStyle.modern ? 'modern' : 'standard');
    state = style;
  }

  void toggle() {
    setStyle(state == UIStyle.modern ? UIStyle.standard : UIStyle.modern);
  }
}

final uiStyleProvider = NotifierProvider<UIStyleNotifier, UIStyle>(UIStyleNotifier.new);
