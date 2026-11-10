import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One tappable picture. [image] is an asset path ("assets/...") or a file name
/// inside the app's media folder. [audio] maps language code -> recording file name.
class Item {
  String id;
  String emoji;
  String? image;
  Map<String, String> label;
  Map<String, String> phrase;
  Map<String, String> audio;

  Item({required this.id, this.emoji = '', this.image, required this.label,
      required this.phrase, Map<String, String>? audio})
      : audio = audio ?? {};

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'],
        emoji: j['emoji'] ?? '',
        image: j['image'],
        label: Map<String, String>.from(j['label']),
        phrase: Map<String, String>.from(j['phrase']),
        audio: Map<String, String>.from(j['audio'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'emoji': emoji, 'image': image,
        'label': label, 'phrase': phrase, 'audio': audio,
      };
}

class AppStore extends ChangeNotifier {
  String lang = 'ar';
  double rate = 0.45;
  bool sound = true, anim = true;
  List<Item> items = [];
  final Map<String, Map<String, String>> ui = {};
  late SharedPreferences _p;
  late Directory mediaDir;

  bool get rtl => lang == 'ar';
  String t(String k) => ui[lang]?[k] ?? ui['en']?[k] ?? k;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final docs = await getApplicationDocumentsDirectory();
    mediaDir = Directory('${docs.path}/media')..createSync(recursive: true);
    for (final l in ['en', 'ar']) {
      ui[l] = Map<String, String>.from(
          jsonDecode(await rootBundle.loadString('assets/i18n/$l.json')));
    }
    lang = _p.getString('lang') ?? 'ar';
    rate = _p.getDouble('rate') ?? 0.45;
    sound = _p.getBool('sound') ?? true;
    anim = _p.getBool('anim') ?? true;
    final saved = _p.getString('items');
    if (saved != null) {
      items = (jsonDecode(saved) as List).map((e) => Item.fromJson(e)).toList();
    } else {
      items = await _defaults();
      await save();
    }
  }

  Future<List<Item>> _defaults() async {
    final raw = jsonDecode(await rootBundle.loadString('assets/items.json')) as List;
    return raw.map((e) {
      final id = e['id'] as String;
      Map<String, String> pick(String part) => {
            for (final l in ['en', 'ar']) l: ui[l]!['item.$id.$part'] ?? id
          };
      return Item(id: id, emoji: e['emoji'] ?? '', image: e['image'],
          label: pick('label'), phrase: pick('phrase'));
    }).toList();
  }

  Future<void> save() async {
    await _p.setString('lang', lang);
    await _p.setDouble('rate', rate);
    await _p.setBool('sound', sound);
    await _p.setBool('anim', anim);
    await _p.setString('items', jsonEncode(items.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  void setLang(String l) { lang = l; save(); }
  void setRate(double r) { rate = r; save(); }
  void setSound(bool v) { sound = v; save(); }
  void setAnim(bool v) { anim = v; save(); }

  void upsert(Item it) {
    final i = items.indexWhere((e) => e.id == it.id);
    i >= 0 ? items[i] = it : items.add(it);
    save();
  }

  void remove(String id) { items.removeWhere((e) => e.id == id); save(); }

  void reorder(int from, int to) {
    if (to > from) to--;
    items.insert(to, items.removeAt(from));
    save();
  }

  Future<void> resetDefaults() async { items = await _defaults(); await save(); }

  /// Turns a stored name into a usable path (assets stay as-is).
  String? resolve(String? p) {
    if (p == null || p.isEmpty) return null;
    return p.startsWith('assets/') ? p : '${mediaDir.path}/$p';
  }

  Future<String> importFile(String src, String ext) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(src).copy('${mediaDir.path}/$name');
    return name;
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'settings': {'lang': lang, 'rate': rate, 'sound': sound, 'anim': anim},
        'items': items.map((e) => e.toJson()).toList(),
      });
}

/// Speaks an item: caregiver recording if present, otherwise the native TTS engine.
class Speaker {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  Future<void> speakText(AppStore s, String text) async {
    await _player.stop();
    await _tts.stop();
    await _tts.setLanguage(s.lang == 'ar' ? 'ar-SA' : 'en-US');
    await _tts.setSpeechRate(s.rate);
    await _tts.speak(text);
  }

  Future<void> speak(AppStore s, Item it) async {
    if (!s.sound) return;
    final rec = s.resolve(it.audio[s.lang]);
    if (rec != null && File(rec).existsSync()) {
      await _tts.stop();
      await _player.stop();
      await _player.play(DeviceFileSource(rec));
      return;
    }
    await speakText(s, it.phrase[s.lang] ?? '');
  }

  void dispose() { _tts.stop(); _player.dispose(); }
}

/// Picture (photo or emoji) scaled to fit its parent.
Widget itemVisual(AppStore s, Item it) {
  final p = s.resolve(it.image);
  if (p != null) {
    return p.startsWith('assets/')
        ? Image.asset(p, fit: BoxFit.contain)
        : Image.file(File(p), fit: BoxFit.contain);
  }
  return FittedBox(
      child: Text(it.emoji.isEmpty ? '❓' : it.emoji, style: const TextStyle(fontSize: 100)));
}
