import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class KurdishMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const KurdishMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // Fallback to English Material Localizations but apply it to the 'ku' locale context if possible,
    // or simply return the English instance. 
    // Since 'ku' (Kurmanji) is LTR, English (LTR) is a suitable fallback for layout purposes.
    final englishLocalizations = await GlobalMaterialLocalizations.delegate.load(const Locale('en'));
    
    return englishLocalizations;
  }

  @override
  bool shouldReload(KurdishMaterialLocalizationsDelegate old) => false;
}

class KurdishCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const KurdishCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    final englishLocalizations = await GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
    return englishLocalizations;
  }

  @override
  bool shouldReload(KurdishCupertinoLocalizationsDelegate old) => false;
}
