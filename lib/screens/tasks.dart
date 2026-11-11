import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../ui/theme.dart';

const List<String> kTaskTypes = [
  'Rechnen',
  'Schiebepuzzle',
  'Memory',
  'Zahlenfolge merken',
  'Farbwort',
  'Reihenfolge tippen',
  'Muster nachtippen',
  'Abtippen',
  'Zufall',
];

/// Konzentrationsaufgabe zum Ausschalten des Weckers.
class WakeTask extends StatefulWidget {
  final String type;
  final bool hard;
  final void Function(int errors) onSolved;
  const WakeTask({super.key, required this.type, required this.hard, required this.onSolved});

  static String resolve(String type) {
    if (type != 'Zufall') return type;
    final opts = kTaskTypes.where((t) => t != 'Zufall').toList();
    return opts[Random().nextInt(opts.length)];
  }

  @override
  State<WakeTask> createState() => _WakeTaskState();
}

class _WakeTaskState extends State<WakeTask> {
  int errors = 0;
  void err() => setState(() => errors++);
  void done() => widget.onSolved(errors);

  @override
  Widget build(BuildContext context) {
    final t = widget.type;
    Widget child;
    switch (t) {
      case 'Schiebepuzzle':
        child = _SlidePuzzle(onDone: done, onError: err);
        break;
      case 'Memory':
        child = _Memory(onDone: done, onError: err);
        break;
      case 'Zahlenfolge merken':
        child = _Recall(onDone: done, onError: err, hard: widget.hard);
        break;
      case 'Farbwort':
        child = _Stroop(onDone: done, onError: err);
        break;
      case 'Reihenfolge tippen':
        child = _Sequence(onDone: done, onError: err);
        break;
      case 'Muster nachtippen':
        child = _Simon(onDone: done, onError: err, hard: widget.hard);
        break;
      case 'Abtippen':
        child = _Typing(onDone: done, onError: err);
        break;
      default:
        child = _MathTask(onDone: done, onError: err, hard: widget.hard);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t, textAlign: TextAlign.center,
            style: const TextStyle(color: C.softBorder, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
        const SizedBox(height: 4),
        Text('Fehler: $errors', textAlign: TextAlign.center, style: const TextStyle(color: C.softBorder, fontSize: 13)),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------- Bausteine

class _BigButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? color;
  final Color? textColor;
  final double size;
  const _BigButton(this.text, this.onTap, {this.color, this.textColor, this.size = 22});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: textColor ?? C.navy)),
        ),
      ),
    );
  }
}

const _white = TextStyle(color: Colors.white, fontSize: 18);

// ---------------------------------------------------------------- Rechnen (3 Aufgaben)

class _MathTask extends StatefulWidget {
  final VoidCallback onDone, onError;
  final bool hard;
  const _MathTask({required this.onDone, required this.onError, required this.hard});
  @override
  State<_MathTask> createState() => _MathTaskState();
}

class _MathTaskState extends State<_MathTask> {
  final _r = Random();
  int solved = 0;
  late String q;
  late int a;
  String input = '';

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    final kind = _r.nextInt(3);
    final big = widget.hard ? 90 : 40;
    if (kind == 0) {
      final x = 5 + _r.nextInt(big), y = 5 + _r.nextInt(big);
      q = '$x + $y';
      a = x + y;
    } else if (kind == 1) {
      final x = 20 + _r.nextInt(big), y = 3 + _r.nextInt(19);
      q = '$x − $y';
      a = x - y;
    } else {
      final x = 2 + _r.nextInt(widget.hard ? 11 : 8), y = 2 + _r.nextInt(9);
      q = '$x × $y';
      a = x * y;
    }
    input = '';
  }

  void _key(String k) {
    setState(() {
      if (k == '⌫') {
        if (input.isNotEmpty) input = input.substring(0, input.length - 1);
      } else if (k == 'OK') {
        if (int.tryParse(input) == a) {
          solved++;
          if (solved >= 3) {
            widget.onDone();
            return;
          }
          _next();
        } else {
          widget.onError();
          input = '';
        }
      } else if (input.length < 4) {
        input += k;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Aufgabe ${solved + 1} von 3', textAlign: TextAlign.center, style: _white),
      const SizedBox(height: 8),
      Text('$q = ${input.isEmpty ? '?' : input}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.8,
        children: [
          for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', 'OK'])
            _BigButton(k, () => _key(k), color: k == 'OK' ? C.fertile : null),
        ],
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Reihenfolge tippen

class _Sequence extends StatefulWidget {
  final VoidCallback onDone, onError;
  const _Sequence({required this.onDone, required this.onError});
  @override
  State<_Sequence> createState() => _SequenceState();
}

class _SequenceState extends State<_Sequence> {
  late List<int> nums = (List<int>.generate(9, (i) => i + 1)..shuffle());
  int nextN = 1;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Tippe die Zahlen von 1 bis 9 der Reihe nach an.', textAlign: TextAlign.center, style: _white),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (final n in nums)
            _BigButton(
              n < nextN ? '✓' : '$n',
              n < nextN
                  ? null
                  : () {
                      if (n == nextN) {
                        setState(() => nextN++);
                        if (nextN > 9) widget.onDone();
                      } else {
                        widget.onError();
                        setState(() {
                          nextN = 1;
                          nums.shuffle();
                        });
                      }
                    },
              color: n < nextN ? C.blue : Colors.white,
              textColor: n < nextN ? Colors.white : C.navy,
              size: 28,
            ),
        ],
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Memory (6 Paare)

class _Memory extends StatefulWidget {
  final VoidCallback onDone, onError;
  const _Memory({required this.onDone, required this.onError});
  @override
  State<_Memory> createState() => _MemoryState();
}

class _MemoryState extends State<_Memory> {
  static const icons = [
    Icons.wb_sunny,
    Icons.nightlight_round,
    Icons.star,
    Icons.favorite,
    Icons.local_florist,
    Icons.pets,
  ];
  late List<int> cards = ([...List.generate(6, (i) => i), ...List.generate(6, (i) => i)]..shuffle());
  final Set<int> found = {};
  final List<int> open = [];
  bool busy = false;

  void _tap(int i) {
    if (busy || found.contains(i) || open.contains(i)) return;
    setState(() => open.add(i));
    if (open.length == 2) {
      if (cards[open[0]] == cards[open[1]]) {
        setState(() {
          found.addAll(open);
          open.clear();
        });
        if (found.length == cards.length) widget.onDone();
      } else {
        busy = true;
        widget.onError();
        Timer(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() {
            open.clear();
            busy = false;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Finde alle Paare.', textAlign: TextAlign.center, style: _white),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (int i = 0; i < cards.length; i++)
            Material(
              color: found.contains(i) ? C.fertile : (open.contains(i) ? Colors.white : C.blue),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _tap(i),
                child: Center(
                  child: (found.contains(i) || open.contains(i))
                      ? Icon(icons[cards[i]], color: C.navy, size: 32)
                      : const Icon(Icons.question_mark, color: Colors.white54),
                ),
              ),
            ),
        ],
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Zahlenfolge merken

class _Recall extends StatefulWidget {
  final VoidCallback onDone, onError;
  final bool hard;
  const _Recall({required this.onDone, required this.onError, required this.hard});
  @override
  State<_Recall> createState() => _RecallState();
}

class _RecallState extends State<_Recall> {
  final _r = Random();
  String digits = '';
  String input = '';
  bool showing = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _new();
  }

  void _new() {
    final n = widget.hard ? 6 : 5;
    digits = List.generate(n, (_) => _r.nextInt(10)).join();
    input = '';
    showing = true;
    _t?.cancel();
    _t = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => showing = false);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _key(String k) {
    if (showing) return;
    setState(() {
      if (k == '⌫') {
        if (input.isNotEmpty) input = input.substring(0, input.length - 1);
        return;
      }
      input += k;
      if (input.length == digits.length) {
        if (input == digits) {
          widget.onDone();
        } else {
          widget.onError();
          _new();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(showing ? 'Merke dir diese Zahlen:' : 'Gib die Zahlen ein:', textAlign: TextAlign.center, style: _white),
      const SizedBox(height: 8),
      Text(
        showing ? digits : (input.padRight(digits.length, '•')),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 6),
      ),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.8,
        children: [
          for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'])
            k.isEmpty ? const SizedBox() : _BigButton(k, showing ? null : () => _key(k)),
        ],
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Farbwort (Stroop)

class _Stroop extends StatefulWidget {
  final VoidCallback onDone, onError;
  const _Stroop({required this.onDone, required this.onError});
  @override
  State<_Stroop> createState() => _StroopState();
}

class _StroopState extends State<_Stroop> {
  static const names = ['ROT', 'BLAU', 'GRÜN', 'GELB'];
  static const colors = [Color(0xFFE5484D), Color(0xFF4C8DFF), Color(0xFF30A46C), Color(0xFFF5C518)];
  final _r = Random();
  int round = 0;
  late int word;
  late int ink;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    word = _r.nextInt(4);
    do {
      ink = _r.nextInt(4);
    } while (ink == word);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Welche FARBE hat das Wort? (${round + 1} von 5)', textAlign: TextAlign.center, style: _white),
      const SizedBox(height: 16),
      Text(names[word],
          textAlign: TextAlign.center,
          style: TextStyle(color: colors[ink], fontSize: 52, fontWeight: FontWeight.w900)),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.4,
        children: [
          for (int i = 0; i < 4; i++)
            _BigButton(names[i], () {
              if (i == ink) {
                round++;
                if (round >= 5) {
                  widget.onDone();
                  return;
                }
                setState(_next);
              } else {
                widget.onError();
                setState(_next);
              }
            }, size: 18),
        ],
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Muster nachtippen (Simon)

class _Simon extends StatefulWidget {
  final VoidCallback onDone, onError;
  final bool hard;
  const _Simon({required this.onDone, required this.onError, required this.hard});
  @override
  State<_Simon> createState() => _SimonState();
}

class _SimonState extends State<_Simon> {
  final _r = Random();
  late List<int> seq;
  int? lit;
  bool showing = true;
  int pos = 0;

  @override
  void initState() {
    super.initState();
    seq = _gen();
    _play();
  }

  List<int> _gen() => List.generate(widget.hard ? 5 : 4, (_) => _r.nextInt(9));

  Future<void> _play() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    for (final s in seq) {
      if (!mounted) return;
      setState(() => lit = s);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() => lit = null);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) setState(() => showing = false);
  }

  void _tap(int i) {
    if (showing) return;
    if (seq[pos] == i) {
      pos++;
      if (pos >= seq.length) {
        widget.onDone();
      }
      setState(() {});
    } else {
      widget.onError();
      setState(() {
        seq = _gen();
        pos = 0;
        showing = true;
      });
      _play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(showing ? 'Schau dir das Muster an …' : 'Tippe das Muster nach ($pos/${seq.length})',
          textAlign: TextAlign.center, style: _white),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (int i = 0; i < 9; i++)
            Material(
              color: lit == i ? C.fertile : C.blue,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _tap(i)),
            ),
        ],
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Abtippen

class _Typing extends StatefulWidget {
  final VoidCallback onDone, onError;
  const _Typing({required this.onDone, required this.onError});
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> {
  static const sentences = [
    'Heute wird ein guter Tag',
    'Ich bin wach und stehe auf',
    'Ein Glas Wasser hilft beim Aufwachen',
    'Guten Morgen liebe Sonne',
    'Erst aufstehen dann weiterdenken',
  ];
  late String target = sentences[Random().nextInt(sentences.length)];
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _check() {
    if (ctrl.text.trim().toLowerCase() == target.toLowerCase()) {
      widget.onDone();
    } else {
      widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Schreibe diesen Satz ab:', textAlign: TextAlign.center, style: _white),
      const SizedBox(height: 8),
      Text(target,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      TextField(
        controller: ctrl,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: (_) => _check(),
        decoration: const InputDecoration(hintText: 'Hier tippen'),
      ),
      const SizedBox(height: 12),
      _BigButton('Prüfen', _check, color: C.fertile, size: 18),
    ]);
  }
}

// ---------------------------------------------------------------- Schiebepuzzle 3×3

class _SlidePuzzle extends StatefulWidget {
  final VoidCallback onDone, onError;
  const _SlidePuzzle({required this.onDone, required this.onError});
  @override
  State<_SlidePuzzle> createState() => _SlidePuzzleState();
}

class _SlidePuzzleState extends State<_SlidePuzzle> {
  // 0 = Lücke. Gelöst: 1..8, 0
  late List<int> tiles;
  int moves = 0;

  @override
  void initState() {
    super.initState();
    tiles = [1, 2, 3, 4, 5, 6, 7, 8, 0];
    final r = Random();
    int last = -1;
    // Aus dem gelösten Zustand zufällig mischen – so ist das Puzzle immer lösbar.
    for (int i = 0; i < 18; i++) {
      final e = tiles.indexOf(0);
      final nb = _neighbors(e).where((n) => n != last).toList();
      final pick = nb[r.nextInt(nb.length)];
      tiles[e] = tiles[pick];
      tiles[pick] = 0;
      last = e;
    }
    if (_solved()) {
      final e = tiles.indexOf(0);
      final n = _neighbors(e).first;
      tiles[e] = tiles[n];
      tiles[n] = 0;
    }
  }

  List<int> _neighbors(int i) {
    final r = i ~/ 3, c = i % 3;
    return [
      if (r > 0) i - 3,
      if (r < 2) i + 3,
      if (c > 0) i - 1,
      if (c < 2) i + 1,
    ];
  }

  bool _solved() {
    for (int i = 0; i < 8; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return true;
  }

  void _tap(int i) {
    final e = tiles.indexOf(0);
    if (!_neighbors(e).contains(i)) {
      widget.onError();
      return;
    }
    setState(() {
      tiles[e] = tiles[i];
      tiles[i] = 0;
      moves++;
    });
    if (_solved()) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Ordne die Zahlen 1–8 (Züge: $moves).', textAlign: TextAlign.center, style: _white),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (int i = 0; i < 9; i++)
            tiles[i] == 0
                ? const SizedBox()
                : _BigButton('${tiles[i]}', () => _tap(i),
                    color: Color.lerp(C.fertile, Colors.white, tiles[i] / 9), size: 30),
        ],
      ),
    ]);
  }
}
