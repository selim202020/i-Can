import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'store.dart';

/// Simple parent-only gate: a multiplication question.
class GateScreen extends StatefulWidget {
  final AppStore s;
  final Speaker sp;
  const GateScreen(this.s, this.sp, {super.key});
  @override
  State<GateScreen> createState() => _GateState();
}

class _GateState extends State<GateScreen> {
  final r = Random();
  late int a = 6 + r.nextInt(4), b = 6 + r.nextInt(4);
  final c = TextEditingController();
  bool wrong = false;

  void check() {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var txt = c.text.trim();
    for (var i = 0; i < 10; i++) { txt = txt.replaceAll(ar[i], '$i'); }
    if (int.tryParse(txt) == a * b) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => SettingsScreen(widget.s, widget.sp)));
    } else {
      setState(() { wrong = true; a = 6 + r.nextInt(4); b = 6 + r.nextInt(4); c.clear(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('gate.title'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(s.t('gate.ask'), style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 16),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text('$a × $b = ?',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: c,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28),
            onSubmitted: (_) => check(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: check, child: Text(s.t('gate.open'))),
          if (wrong) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(s.t('gate.wrong'), style: const TextStyle(color: Colors.red))),
        ]),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final AppStore s;
  final Speaker sp;
  const SettingsScreen(this.s, this.sp, {super.key});

  void edit(BuildContext c, Item? it) => Navigator.push(
      c, MaterialPageRoute(builder: (_) => ItemEditScreen(s, sp, it)));

  Future<bool> confirm(BuildContext c, String q) async =>
      await showDialog<bool>(
        context: c,
        builder: (_) => AlertDialog(
          content: Text(q),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('cancel'))),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('delete'))),
          ],
        ),
      ) ?? false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: s,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: Text(s.t('settings'))),
          floatingActionButton: FloatingActionButton.extended(
              onPressed: () => edit(context, null),
              icon: const Icon(Icons.add),
              label: Text(s.t('set.add'))),
          body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
            ListTile(
              title: Text(s.t('set.lang')),
              trailing: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'ar', label: Text(s.ui['ar']!['lang.name']!)),
                  ButtonSegment(value: 'en', label: Text(s.ui['en']!['lang.name']!)),
                ],
                selected: {s.lang},
                onSelectionChanged: (v) => s.setLang(v.first),
              ),
            ),
            ListTile(
              title: Text(s.t('set.rate')),
              subtitle: Slider(
                  min: 0.2, max: 0.8, divisions: 12, value: s.rate, onChanged: s.setRate),
              trailing: TextButton(
                  onPressed: () => sp.speakText(s, s.t('set.sample')),
                  child: Text(s.t('set.test'))),
            ),
            SwitchListTile(title: Text(s.t('set.sound')), value: s.sound, onChanged: s.setSound),
            SwitchListTile(title: Text(s.t('set.anim')), value: s.anim, onChanged: s.setAnim),
            const Divider(),
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.t('set.items'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: s.reorder,
              children: [
                for (final it in s.items)
                  ListTile(
                    key: ValueKey(it.id),
                    leading: SizedBox(width: 48, height: 48, child: itemVisual(s, it)),
                    title: Text(it.label[s.lang] ?? ''),
                    subtitle: Text(it.phrase[s.lang] ?? ''),
                    onTap: () => edit(context, it),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirm(context, s.t('delete.q'))) s.remove(it.id);
                      },
                    ),
                  ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(s.t('set.export')),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: s.exportJson()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(s.t('set.exported'))));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: Text(s.t('set.reset')),
              onTap: () async {
                if (await confirm(context, s.t('set.reset.q'))) await s.resetDefaults();
              },
            ),
          ]),
        ),
      );
}

class ItemEditScreen extends StatefulWidget {
  final AppStore s;
  final Speaker sp;
  final Item? item;
  const ItemEditScreen(this.s, this.sp, this.item, {super.key});
  @override
  State<ItemEditScreen> createState() => _ItemEditState();
}

class _ItemEditState extends State<ItemEditScreen> {
  late final Item d = widget.item == null
      ? Item(id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          label: {'en': '', 'ar': ''}, phrase: {'en': '', 'ar': ''})
      : Item.fromJson(widget.item!.toJson());
  late final Map<String, TextEditingController> ctl = {
    'label_en': TextEditingController(text: d.label['en']),
    'label_ar': TextEditingController(text: d.label['ar']),
    'phrase_en': TextEditingController(text: d.phrase['en']),
    'phrase_ar': TextEditingController(text: d.phrase['ar']),
    'emoji': TextEditingController(text: d.emoji),
  };
  final rec = AudioRecorder();
  final player = AudioPlayer();
  String? recording;
  AppStore get s => widget.s;

  @override
  void dispose() { rec.dispose(); player.dispose(); super.dispose(); }

  Future<void> pickPhoto(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 800, imageQuality: 85);
    if (x == null) return;
    final name = await s.importFile(x.path, '.jpg');
    setState(() => d.image = name);
  }

  Future<void> toggleRec(String l) async {
    if (recording == l) {
      await rec.stop();
      setState(() => recording = null);
      return;
    }
    if (!await rec.hasPermission()) return;
    final name = 'rec_${DateTime.now().millisecondsSinceEpoch}_$l.m4a';
    await rec.start(const RecordConfig(), path: '${s.mediaDir.path}/$name');
    setState(() { d.audio[l] = name; recording = l; });
  }

  void save() {
    final labelEn = ctl['label_en']!.text.trim(), labelAr = ctl['label_ar']!.text.trim();
    final phraseEn = ctl['phrase_en']!.text.trim(), phraseAr = ctl['phrase_ar']!.text.trim();
    if ([labelEn, labelAr, phraseEn, phraseAr].any((e) => e.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('required'))));
      return;
    }
    d.label = {'en': labelEn, 'ar': labelAr};
    d.phrase = {'en': phraseEn, 'ar': phraseAr};
    d.emoji = ctl['emoji']!.text.trim();
    s.upsert(d);
    Navigator.pop(context);
  }

  Widget field(String key, {TextDirection? dir}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctl[key],
          textDirection: dir,
          decoration: InputDecoration(
              labelText: s.t('field.$key'), border: const OutlineInputBorder()),
        ),
      );

  Widget recRow(String l) {
    final has = d.audio[l] != null;
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          icon: Icon(recording == l ? Icons.stop : Icons.mic),
          label: Text(recording == l ? s.t('rec.stop') : s.t('rec.$l')),
          onPressed: () => toggleRec(l),
        ),
      ),
      if (has && recording != l) ...[
        IconButton(
            tooltip: s.t('rec.play'),
            icon: const Icon(Icons.play_arrow),
            onPressed: () => player.play(DeviceFileSource(s.resolve(d.audio[l])!))),
        IconButton(
            tooltip: s.t('rec.clear'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => d.audio.remove(l))),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(d.label[s.lang]?.isNotEmpty == true ? d.label[s.lang]! : s.t('set.add')),
          actions: [TextButton(onPressed: save, child: Text(s.t('save')))],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SizedBox(height: 140, child: itemVisual(s, d)),
          Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
            OutlinedButton(
                onPressed: () => pickPhoto(ImageSource.gallery), child: Text(s.t('field.gallery'))),
            OutlinedButton(
                onPressed: () => pickPhoto(ImageSource.camera), child: Text(s.t('field.camera'))),
            if (d.image != null)
              TextButton(
                  onPressed: () => setState(() => d.image = null),
                  child: Text(s.t('field.photo_clear'))),
          ]),
          const SizedBox(height: 16),
          field('emoji'),
          field('label_en', dir: TextDirection.ltr),
          field('label_ar', dir: TextDirection.rtl),
          field('phrase_en', dir: TextDirection.ltr),
          field('phrase_ar', dir: TextDirection.rtl),
          recRow('en'),
          recRow('ar'),
        ]),
      );
}
