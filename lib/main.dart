import 'package:flutter/material.dart';
import 'caregiver.dart';
import 'store.dart';

const navy = Color(0xFF12305A), orange = Color(0xFFE67700);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final s = AppStore();
  await s.load();
  runApp(App(s));
}

class App extends StatelessWidget {
  final AppStore s;
  const App(this.s, {super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: s,
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: s.t('app.title'),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: navy),
            scaffoldBackgroundColor: Colors.white,
          ),
          // Whole UI flips to right-to-left when Arabic is active.
          builder: (ctx, child) => Directionality(
              textDirection: s.rtl ? TextDirection.rtl : TextDirection.ltr, child: child!),
          home: Home(s),
        ),
      );
}

class Home extends StatefulWidget {
  final AppStore s;
  const Home(this.s, {super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final Speaker sp = Speaker();
  String? selId;

  AppStore get s => widget.s;
  Item? get sel {
    for (final i in s.items) { if (i.id == selId) return i; }
    return null;
  }

  @override
  void dispose() { sp.dispose(); super.dispose(); }

  void pick(Item it) {
    setState(() => selId = it.id);
    sp.speak(s, it);
  }

  Widget langButton(String code) {
    final on = s.lang == code;
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: on ? navy : Colors.white,
          foregroundColor: on ? Colors.white : navy,
          side: const BorderSide(color: navy, width: 3),
        ),
        onPressed: () => s.setLang(code),
        child: Text(s.ui[code]!['lang.name']!,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget panel(double h) {
    final it = sel;
    return Container(
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        border: Border.all(color: orange, width: 4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: it == null
          ? const Center(child: Text('👆', style: TextStyle(fontSize: 72)))
          : Row(children: [
              Expanded(flex: 3, child: itemVisual(s, it)),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(it.label[s.lang] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: navy)),
                  const SizedBox(height: 10),
                  IconButton.filled(
                    iconSize: 44,
                    tooltip: s.t('replay'),
                    style: IconButton.styleFrom(
                        backgroundColor: navy, minimumSize: const Size(80, 80)),
                    onPressed: () => sp.speak(s, it),
                    icon: const Icon(Icons.volume_up),
                  ),
                ]),
              ),
            ]),
    );
  }

  Widget tile(Item it) {
    final on = it.id == selId;
    return Semantics(
      button: true,
      label: it.label[s.lang],
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => pick(it),
        child: AnimatedContainer(
          duration: s.anim ? const Duration(milliseconds: 150) : Duration.zero,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: on ? orange : navy, width: on ? 6 : 3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Expanded(child: itemVisual(s, it)),
            const SizedBox(height: 6),
            Text(it.label[s.lang] ?? '',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = (MediaQuery.of(context).size.height * 0.26).clamp(150.0, 260.0);
    return ListenableBuilder(
      listenable: s,
      builder: (_, __) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(children: [
                Expanded(child: langButton('ar')),
                const SizedBox(width: 8),
                Expanded(child: langButton('en')),
                const SizedBox(width: 4),
                IconButton(
                  iconSize: 34,
                  tooltip: s.t('settings'),
                  icon: const Icon(Icons.settings, color: navy),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => GateScreen(s, sp))),
                ),
              ]),
            ),
            panel(h),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: s.items.length,
                itemBuilder: (_, i) => tile(s.items[i]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
