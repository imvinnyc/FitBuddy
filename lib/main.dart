// lib/main.dart – FitBuddy

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'nearby_gyms_screen.dart';
import 'nutrition_tracker_screen.dart';
import 'calorie_calculator_screen.dart';
import 'workout_tracker_screen.dart';
import 'workout_builder_screen.dart';
import 'diet_generator_screen.dart';
import 'workout_planner_screen.dart';
import 'exercise_tutorial_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  for (final name in [
    'nutrition',
    'workouts',
    'savedWorkouts',
    'savedDiets',
    'planner',
    'exerciseTutorials'
  ]) {
    await Hive.openBox(name);
  }
  runApp(const ProviderScope(child: FitBuddyApp()));
}

/// ---------------------------------------------------------------------------
/// Date-picker helper
/// ---------------------------------------------------------------------------
Future<String?> pickDateFromBox({
  required BuildContext context,
  required Box box,
}) async {
  if (box.isEmpty) {
    showErrorToast('No data available.');
    return 'NO_DATA';
  }
  final dates = box.keys.map((e) => e.toString()).toList()
    ..sort((a, b) => b.compareTo(a));
  String dropdownValue = dates.first;
  return showDialog<String>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Select Date'),
        content: DropdownButton<String>(
          isExpanded: true,
          value: dropdownValue,
          items: [
            for (final d in dates) DropdownMenuItem(value: d, child: Text(d))
          ],
          onChanged: (v) {
            if (v != null) setState(() => dropdownValue = v);
          },
        ),
        actions: [
          TextButton(
            child: const Text('Confirm'),
            onPressed: () => Navigator.pop(ctx, dropdownValue),
          ),
        ],
      ),
    ),
  );
}

/// ---------------------------------------------------------------------------
/// Toast helpers
/// ---------------------------------------------------------------------------
void showErrorToast(String msg) => Fluttertoast.showToast(
      msg: msg,
      backgroundColor: kIsWeb ? null : Colors.red.shade700,
      webBgColor: "linear-gradient(to right, #FF0000, #FF0000)",
      textColor: Colors.white,
      fontSize: 18,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
    );

void showSuccessToast(String msg) => Fluttertoast.showToast(
      msg: msg,
      backgroundColor: kIsWeb ? null : Colors.green.shade600,
      webBgColor: "linear-gradient(to right, #00FF00, #00FF00)",
      textColor: Colors.white,
      fontSize: 16,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
    );

/// ---------------------------------------------------------------------------
/// Simple HTTP helper
/// ---------------------------------------------------------------------------
Future<Map<String, dynamic>?> postRequest(
    String url, Map<String, dynamic> data) async {
  final formBody = data.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
      .join('&');
  try {
    if (kIsWeb) {
      final res = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: formBody,
      );
      if (res.statusCode == 200)
        return jsonDecode(res.body) as Map<String, dynamic>;
      showErrorToast('Server error: ${res.statusCode}');
    } else {
      final dio = Dio();
      final formData =
          FormData.fromMap(data.map((k, v) => MapEntry(k, v.toString())));
      final res = await dio.post(url, data: formData);
      if (res.statusCode == 200) return res.data as Map<String, dynamic>;
      showErrorToast('Server error: ${res.statusCode}');
    }
  } catch (e) {
    showErrorToast('Network error: $e');
  }
  return null;
}

/// ---------------------------------------------------------------------------
/// Hive providers (Riverpod)
/// ---------------------------------------------------------------------------
final hiveProvider = Provider.family<Box, String>((_, name) => Hive.box(name));

StateNotifierProvider<HiveListNotifier, List<Map>> listProv(
        String box, String key) =>
    StateNotifierProvider<HiveListNotifier, List<Map>>(
        (ref) => HiveListNotifier(Hive.box(box), key));

class HiveListNotifier extends StateNotifier<List<Map>> {
  HiveListNotifier(this._box, this.key)
      : super(List<Map>.from(_box.get(key, defaultValue: [])));
  final Box _box;
  final String key;
  void add(Map m, {int max = 50}) {
    final list = [...state, m];
    if (list.length > max) list.removeAt(0);
    _box.put(key, list);
    state = list;
    showSuccessToast('Saved');
  }

  void clear() {
    _box.delete(key);
    state = [];
  }
}

/// ---------------------------------------------------------------------------
/// Shared UI widgets
/// ---------------------------------------------------------------------------
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  const SecondaryButton({super.key, required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, minHeight: 40),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF333333),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

class ResponsiveButtonGroup extends StatelessWidget {
  final List<Widget> buttons;
  final double spacing;
  const ResponsiveButtonGroup(
      {super.key, required this.buttons, this.spacing = 8});

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: spacing,
        runSpacing: spacing,
        children: buttons,
      );
}

/// ---------------------------------------------------------------------------
/// FitBuddyApp  +  GoRouter
/// ---------------------------------------------------------------------------
class FitBuddyApp extends ConsumerWidget {
  const FitBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/nutrition', builder: (_, __) => const NutritionTracker()),
      GoRoute(path: '/calorie', builder: (_, __) => const CalorieCalculator()),
      GoRoute(
          path: '/workout-tracker', builder: (_, __) => const WorkoutTracker()),
      GoRoute(
          path: '/workout-builder', builder: (_, __) => const WorkoutBuilder()),
      GoRoute(
          path: '/diet-generator', builder: (_, __) => const DietGenerator()),
      GoRoute(
          path: '/workout-planner', builder: (_, __) => const WorkoutPlanner()),
      GoRoute(path: '/gyms', builder: (_, __) => const NearbyGymsScreen()),
      GoRoute(
          path: '/exercise-tutorial',
          builder: (_, __) => const ExerciseTutorialScreen()),
    ]);

    return MaterialApp.router(
      title: 'FitBuddy',
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Color(0xFF0066FF)),
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF2D2D2D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}

/// ---------------------------------------------------------------------------
/// HomeScreen (dashboard tiles)
/// ---------------------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      _NavItem('Nutrition Tracker', Icons.fastfood, '/nutrition'),
      _NavItem('Calorie Calculator', Icons.local_fire_department, '/calorie'),
      _NavItem('Workout Tracker', Icons.fitness_center, '/workout-tracker'),
      _NavItem('Workout Builder', Icons.construction, '/workout-builder'),
      _NavItem('Create Diet', Icons.restaurant, '/diet-generator'),
      _NavItem('Workout Planner', Icons.calendar_month, '/workout-planner'),
      _NavItem('Nearby Gyms', Icons.map, '/gyms'),
      _NavItem('Exercise Tutorial', Icons.school, '/exercise-tutorial'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('FitBuddy')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cross = constraints.maxWidth >= 1200
              ? 4
              : constraints.maxWidth >= 800
                  ? 3
                  : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _HomeCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final String route;
  const _NavItem(this.title, this.icon, this.route);
}

class _HomeCard extends StatelessWidget {
  final _NavItem item;
  const _HomeCard({required this.item, super.key});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 48, color: Colors.white),
              const SizedBox(height: 12),
              Text(item.title, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
}

// Helper to jump home from any page
Widget homeBtn(BuildContext c) =>
    IconButton(icon: const Icon(Icons.home), onPressed: () => c.go('/'));
