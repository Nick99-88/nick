import 'package:starlight_flutter/core/storage.dart';
import 'en/a.dart';
import 'en/b.dart';
import 'en/c.dart';
import 'en/d.dart';
import 'en/e.dart';
import 'en/f.dart';
import 'en/g.dart';
import 'en/h.dart';
import 'en/i.dart';
import 'en/j.dart';
import 'en/k.dart';
import 'en/l.dart';
import 'en/m.dart';
import 'en/n.dart';
import 'en/o.dart';
import 'en/p.dart';
import 'en/q.dart';
import 'en/r.dart';
import 'en/s.dart';
import 'en/t.dart';
import 'en/u.dart';
import 'en/v.dart';
import 'en/w.dart';
import 'en/x.dart';
import 'en/y.dart';
import 'ur/a.dart';
import 'ur/b.dart';
import 'ur/c.dart';
import 'ur/d.dart';
import 'ur/e.dart';
import 'ur/f.dart';
import 'ur/g.dart';
import 'ur/h.dart';
import 'ur/i.dart';
import 'ur/j.dart';
import 'ur/k.dart';
import 'ur/l.dart';
import 'ur/m.dart';
import 'ur/n.dart';
import 'ur/o.dart';
import 'ur/p.dart';
import 'ur/q.dart';
import 'ur/r.dart';
import 'ur/s.dart';
import 'ur/t.dart';
import 'ur/u.dart';
import 'ur/v.dart';
import 'ur/w.dart';
import 'ur/x.dart';
import 'ur/y.dart';

/// Merged localized strings for ALL languages.
///
/// Each letter file exports two maps (enX, urX) which are spread here.
/// Screens ask for a key via [tr] and receive the string for the currently
/// selected language (read from storage at startup).
const Map<String, Map<String, String>> _localized = {
  'en': {
    ...enA,
    ...enB,
    ...enC,
    ...enD,
    ...enE,
    ...enF,
    ...enG,
    ...enH,
    ...enI,
    ...enJ,
    ...enK,
    ...enL,
    ...enM,
    ...enN,
    ...enO,
    ...enP,
    ...enQ,
    ...enR,
    ...enS,
    ...enT,
    ...enU,
    ...enV,
    ...enW,
    ...enX,
    ...enY,
  },
  'ur': {
    ...urA,
    ...urB,
    ...urC,
    ...urD,
    ...urE,
    ...urF,
    ...urG,
    ...urH,
    ...urI,
    ...urJ,
    ...urK,
    ...urL,
    ...urM,
    ...urN,
    ...urO,
    ...urP,
    ...urQ,
    ...urR,
    ...urS,
    ...urT,
    ...urU,
    ...urV,
    ...urW,
    ...urX,
    ...urY,
  },
};

/// The currently active language code.
String _activeLocale = 'en';

/// Reads the stored language selection and activates it.
Future<void> initL10n() async {
  final selected = await StarlightStorage.getSelectedLanguage();
  if (selected != null && _localized.containsKey(selected)) {
    _activeLocale = selected;
  }
}

/// Changes the active language.
Future<void> setLocale(String code) async {
  _activeLocale = _localized.containsKey(code) ? code : 'en';
  await StarlightStorage.setSelectedLanguage(code);
}

/// Returns the localized string for [key] in the active language.
String tr(String key, [Map<String, String>? params]) {
  var value = _localized[_activeLocale]?[key] ?? _localized['en']?[key] ?? key;
  if (params != null) {
    for (final entry in params.entries) {
      value = value.replaceAll('{' + entry.key + '}', entry.value);
    }
  }
  return value;
}
