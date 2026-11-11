import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/calendar_screen.dart';
import 'screens/cycle_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/ring_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/track_screen.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';
import 'store.dart';
import 'ui/common.dart';
import 'ui/theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await store.load();
  try {
    await AlarmService.instance.init();
  } catch (e) {
    debugPrint('Alarm-Init fehlgeschlagen: $e');
  }
  await NotificationService.instance.init();
  runApp(const NarcoQuestApp());
  unawaited(NotificationService.instance.refreshAll());
}

class NarcoQuestApp extends StatefulWidget {
  const NarcoQuestApp({super.key});
  @override
  State<NarcoQuestApp> createState() => _NarcoQuestAppState();
}

class _NarcoQuestAppState extends State<NarcoQuestApp> {
  StreamSubscription<AlarmSet>? _ringSub;
  bool _ringOpen = false;

  @override
  void initState() {
    super.initState();
    _ringSub = Alarm.ringing.listen(_onRinging);
  }

  @override
  void dispose() {
    _ringSub?.cancel();
    super.dispose();
  }

  Future<void> _onRinging(AlarmSet set) async {
    if (set.alarms.isEmpty || _ringOpen) return;
    final alarm = set.alarms.first;
    // Warten, bis der Navigator bereit ist (z. B. beim Kaltstart durch den Wecker).
    for (int i = 0; i < 20 && navigatorKey.currentState == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    _ringOpen = true;
    await nav.push(MaterialPageRoute<void>(
      builder: (_) => RingScreen(alarm: alarm),
      fullscreenDialog: true,
    ));
    _ringOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NarcoQuest',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) => store.profile.onboarded ? const HomeShell() : const OnboardingScreen(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  String _tab = 'home';

  void go(String tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tabs = <(String, String, IconData, IconData)>[
          ('home', 'Start', Icons.home_outlined, Icons.home),
          ('track', 'Tracken', Icons.assignment_outlined, Icons.assignment),
          if (store.cycle.enabled) ('cycle', 'Zyklus', Icons.water_drop_outlined, Icons.water_drop),
          ('stats', 'Statistik', Icons.bar_chart_outlined, Icons.bar_chart),
          ('cal', 'Kalender', Icons.calendar_month_outlined, Icons.calendar_month),
          ('more', 'Mehr', Icons.more_horiz, Icons.more_horiz),
        ];
        if (!tabs.any((t) => t.$1 == _tab)) _tab = 'home';
        final idx = tabs.indexWhere((t) => t.$1 == _tab);
        final titles = {
          'home': 'Heute',
          'track': 'Tracken',
          'cycle': 'Zyklus',
          'stats': 'Statistik',
          'cal': 'Kalender',
          'more': 'Mehr',
        };
        Widget body;
        switch (_tab) {
          case 'track':
            body = const TrackScreen();
            break;
          case 'cycle':
            body = const CycleScreen();
            break;
          case 'stats':
            body = const StatsScreen();
            break;
          case 'cal':
            body = const CalendarScreen();
            break;
          case 'more':
            body = MoreScreen(onOpenCycle: () => go('cycle'));
            break;
          default:
            body = HomeScreen(onGo: go);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_tab] ?? ''),
            actions: const [XpBadge()],
          ),
          body: SafeArea(child: body),
          bottomNavigationBar: NavigationBar(
            selectedIndex: idx < 0 ? 0 : idx,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) => go(tabs[i].$1),
            destinations: [
              for (final t in tabs)
                NavigationDestination(icon: Icon(t.$3), selectedIcon: Icon(t.$4, color: C.navy), label: t.$2),
            ],
          ),
        );
      },
    );
  }
}
