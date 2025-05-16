// lib/main.dart – FitBuddy

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
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
/// Shared date picker helper
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
/// SecondaryButton
/// ---------------------------------------------------------------------------
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const SecondaryButton({
    Key? key,
    required this.text,
    this.onPressed,
  }) : super(key: key);

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

/// ---------------------------------------------------------------------------
/// ResponsiveButtonGroup
/// ---------------------------------------------------------------------------
class ResponsiveButtonGroup extends StatelessWidget {
  final List<Widget> buttons;
  final double spacing;
  const ResponsiveButtonGroup({
    Key? key,
    required this.buttons,
    this.spacing = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing,
      runSpacing: spacing,
      children: buttons,
    );
  }
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
/// Hive providers
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
/// FitBuddyApp
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
        builder: (_, __) => const ExerciseTutorialScreen(),
      ),
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
/// Home Screen
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
          int cross = constraints.maxWidth >= 1200
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(item.route),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(item.icon, size: 48, color: Colors.white),
          const SizedBox(height: 12),
          Text(item.title, style: const TextStyle(color: Colors.white)),
        ]),
      ),
    );
  }
}

Widget homeBtn(BuildContext c) => IconButton(
      icon: const Icon(Icons.home),
      onPressed: () => c.go('/'),
    );

/// ---------------------------------------------------------------------------
/// NearbyGymsScreen
/// ---------------------------------------------------------------------------
class NearbyGymsScreen extends StatefulWidget {
  const NearbyGymsScreen({Key? key}) : super(key: key);

  @override
  State<NearbyGymsScreen> createState() => _NearbyGymsScreenState();
}

class _NearbyGymsScreenState extends State<NearbyGymsScreen> {
  bool _loading = true;
  Position? _position;
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _initLocationAndMap();
  }

  Future<void> _initLocationAndMap() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() => _loading = false);
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _position = pos;
      _loading = false;
    });

    if (!kIsWeb) {
      final url = _mapsEmbedUrl(pos.latitude, pos.longitude);
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(url));
    }
  }

  String _mapsEmbedUrl(double lat, double lng) {
    return 'https://www.google.com/maps/search/gyms/@$lat,$lng,14z';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Nearby Gyms'), actions: [homeBtn(context)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _position == null
              ? const Center(child: Text('Location permission denied'))
              : kIsWeb
                  ? HtmlWidget(
                      '<iframe '
                      'src="${_mapsEmbedUrl(_position!.latitude, _position!.longitude)}" '
                      'width="100%" height="100%" '
                      'style="border:none;" '
                      '></iframe>',
                    )
                  : (_controller == null
                      ? const Center(child: CircularProgressIndicator())
                      : WebViewWidget(controller: _controller!)),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Nutrition Tracker
/// ---------------------------------------------------------------------------
class NutritionTracker extends ConsumerStatefulWidget {
  const NutritionTracker({super.key});
  @override
  ConsumerState<NutritionTracker> createState() => _NutritionTrackerState();
}

class _NutritionTrackerState extends ConsumerState<NutritionTracker> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _food = TextEditingController();
  final _cal = TextEditingController();
  final _fat = TextEditingController();
  final _pro = TextEditingController();
  final _carb = TextEditingController();
  final _fib = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Tracker'),
        actions: [homeBtn(context)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TypeAheadFormField<String>(
                    textFieldConfiguration: TextFieldConfiguration(
                      controller: _food,
                      decoration: const InputDecoration(labelText: 'Food'),
                    ),
                    suggestionsCallback: (pattern) async {
                      if (pattern.isEmpty) return [];
                      return await _fetchFoodSuggestions(pattern);
                    },
                    itemBuilder: (_, s) => ListTile(title: Text(s)),
                    onSuggestionSelected: (s) async {
                      _food.text = s;
                      final d = await _fetchFoodNutrition(s);
                      if (d != null) {
                        _cal.text = d['Calories'].toString();
                        _fat.text = d['Fat'].toString();
                        _pro.text = d['Protein'].toString();
                        _carb.text = d['Carbohydrates'].toString();
                        _fib.text = d['Fiber'].toString();
                      }
                    },
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  _num(_cal, 'Calories'),
                  const SizedBox(height: 8),
                  _num(_fat, 'Fat (g)'),
                  const SizedBox(height: 8),
                  _num(_pro, 'Protein (g)'),
                  const SizedBox(height: 8),
                  _num(_carb, 'Carbohydrates (g)'),
                  const SizedBox(height: 8),
                  _num(_fib, 'Fiber (g)'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ResponsiveButtonGroup(
              buttons: [
                SecondaryButton(text: 'Save Entry', onPressed: _save),
                SecondaryButton(
                    text: 'View Visualizations',
                    onPressed: _viewNutritionVisualizations),
                SecondaryButton(
                    text: 'View Logs', onPressed: _viewNutritionLogs),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextFormField _num(TextEditingController c, String label) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          if (double.tryParse(v) == null) return 'Enter a valid number';
          return null;
        },
      );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final today = DateTime.now().toIso8601String().split('T').first;
    ref.read(listProv('nutrition', today).notifier).add({
      'Food': _food.text,
      'Calories': double.parse(_cal.text),
      'Fat': double.parse(_fat.text),
      'Protein': double.parse(_pro.text),
      'Carbohydrates': double.parse(_carb.text),
      'Fiber': double.parse(_fib.text),
    });
    _formKey.currentState!.reset();
  }

  Future<void> _viewNutritionVisualizations() async {
    final date = await pickDateFromBox(
      context: context,
      box: Hive.box('nutrition'),
    );
    if (date == null || date == 'NO_DATA') return;
    final entries = Hive.box('nutrition').get(date, defaultValue: []);
    if ((entries as List).isEmpty) {
      showErrorToast('No entries for $date');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nutrition Chart for $date'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: _NutritionChart(entries: List<Map>.from(entries)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              Hive.box('nutrition').delete(date);
              Navigator.pop(context);
              showSuccessToast('Deleted');
            },
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _viewNutritionLogs() async {
    final date = await pickDateFromBox(
      context: context,
      box: Hive.box('nutrition'),
    );
    if (date == null || date == 'NO_DATA') return;
    final entries = Hive.box('nutrition').get(date, defaultValue: []) as List;
    if (entries.isEmpty) {
      showErrorToast('No entries for $date');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Nutrition Log for $date'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in entries)
                ListTile(
                  title: Text(e['Food'] ?? ''),
                  subtitle: Text(
                    'Cal: ${e['Calories']} | Fat: ${e['Fat']} | Pro: ${e['Protein']} | Carb: ${e['Carbohydrates']} | Fib: ${e['Fiber']}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              Hive.box('nutrition').delete(date);
              Navigator.of(dialogContext).pop();
              showSuccessToast('Deleted');
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _fetchFoodSuggestions(String p) async {
    try {
      final r = await http.post(
        Uri.parse('https://fitbuddy-backend-ruby.vercel.app/nutritionix/'),
        body: {'query': p},
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        return List<String>.from(d['suggestions']);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> _fetchFoodNutrition(String f) async {
    try {
      final r = await http.post(
        Uri.parse('https://fitbuddy-backend-ruby.vercel.app/nutritionix/'),
        body: {'food': f},
      );
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return null;
  }
}

class _NutritionChart extends StatelessWidget {
  const _NutritionChart({super.key, required this.entries});
  final List<Map> entries;
  @override
  Widget build(BuildContext context) {
    double cal = 0, fat = 0, pro = 0, carb = 0, fib = 0;
    for (var e in entries) {
      cal += (e['Calories'] as num).toDouble();
      fat += (e['Fat'] as num).toDouble();
      pro += (e['Protein'] as num).toDouble();
      carb += (e['Carbohydrates'] as num).toDouble();
      fib += (e['Fiber'] as num).toDouble();
    }
    final d = [cal, fat, pro, carb, fib];
    return BarChart(
      BarChartData(
        barGroups: [
          for (int i = 0; i < d.length; i++)
            BarChartGroupData(x: i, barRods: [BarChartRodData(toY: d[i])]),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) =>
                  Text(['Cal', 'Fat', 'Pro', 'Carb', 'Fib'][v.toInt()]),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Calorie Calculator
/// ---------------------------------------------------------------------------
class CalorieCalculator extends StatefulWidget {
  const CalorieCalculator({super.key});
  @override
  State<CalorieCalculator> createState() => _CalorieCalculatorState();
}

class _CalorieCalculatorState extends State<CalorieCalculator> {
  final _formKey = GlobalKey<FormState>();
  final _age = TextEditingController();
  final _h = TextEditingController();
  final _w = TextEditingController();
  String _gender = 'Male';
  String _activity = 'Sedentary';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calorie Calculator'),
        actions: [homeBtn(context)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _num(_age, 'Age (years)'),
              const SizedBox(height: 8),
              DropdownButtonFormField(
                decoration: const InputDecoration(labelText: 'Gender'),
                value: _gender,
                items: ['Male', 'Female']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 8),
              _num(_h, 'Height (cm)'),
              const SizedBox(height: 8),
              _num(_w, 'Weight (kg)'),
              const SizedBox(height: 8),
              DropdownButtonFormField(
                decoration: const InputDecoration(labelText: 'Activity Level'),
                value: _activity,
                items: [
                  'Sedentary',
                  'Lightly active',
                  'Moderately active',
                  'Very active',
                  'Super active'
                ]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _activity = v!),
              ),
              const SizedBox(height: 16),
              SecondaryButton(text: 'Calculate', onPressed: _calc),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _num(TextEditingController c, String l) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: l),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          if (double.tryParse(v) == null) return 'Enter a valid number';
          return null;
        },
      );

  void _calc() {
    if (!_formKey.currentState!.validate()) return;
    final age = int.parse(_age.text);
    final h = double.parse(_h.text);
    final w = double.parse(_w.text);
    final bmr = _gender == 'Male'
        ? 10 * w + 6.25 * h - 5 * age + 5
        : 10 * w + 6.25 * h - 5 * age - 161;
    final mult = {
      'Sedentary': 1.2,
      'Lightly active': 1.375,
      'Moderately active': 1.55,
      'Very active': 1.725,
      'Super active': 1.9
    }[_activity]!;
    final cals = (bmr * mult).round();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Daily Calorie Needs'),
        content: Text('$cals calories'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Workout Tracker
/// ---------------------------------------------------------------------------
class WorkoutTracker extends ConsumerStatefulWidget {
  const WorkoutTracker({super.key});
  @override
  ConsumerState<WorkoutTracker> createState() => _WorkoutTrackerState();
}

class _WorkoutTrackerState extends ConsumerState<WorkoutTracker> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'Legs';
  final _ex = TextEditingController();
  final _sets = TextEditingController();
  final _reps = TextEditingController();
  String get _today => DateTime.now().toIso8601String().split('T').first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Tracker'),
        actions: [homeBtn(context)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField(
                    decoration:
                        const InputDecoration(labelText: 'Workout Type'),
                    value: _type,
                    items: ['Legs', 'Arms', 'Abs', 'Back', 'Shoulders']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 8),
                  _tf(_ex, 'Exercises'),
                  const SizedBox(height: 8),
                  _num(_sets, 'Sets'),
                  const SizedBox(height: 8),
                  _num(_reps, 'Reps'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ResponsiveButtonGroup(buttons: [
              SecondaryButton(text: 'Save Workout', onPressed: _save),
              SecondaryButton(text: 'View Visualizations', onPressed: _viewVis),
              SecondaryButton(text: 'View Logs', onPressed: _viewLogs),
            ]),
          ],
        ),
      ),
    );
  }

  TextFormField _tf(TextEditingController c, String l) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: l),
        validator: (v) => v!.isEmpty ? 'Required' : null,
      );

  TextFormField _num(TextEditingController c, String l) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: l),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          if (int.tryParse(v) == null) return 'Enter a valid number';
          return null;
        },
      );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(listProv('workouts', _today).notifier).add({
      'workout_type': _type,
      'exercises': _ex.text,
      'sets': int.parse(_sets.text),
      'reps': int.parse(_reps.text)
    });
    _formKey.currentState!.reset();
    setState(() => _type = 'Legs');
  }

  Future<void> _viewVis() async {
    final date =
        await pickDateFromBox(context: context, box: Hive.box('workouts'));
    if (date == null || date == 'NO_DATA') return;
    final entries = Hive.box('workouts').get(date, defaultValue: []);
    if ((entries as List).isEmpty) {
      showErrorToast('No entries for $date');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Workout Chart for $date'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: _WorkoutChart(entries: List<Map>.from(entries)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              Hive.box('workouts').delete(date);
              Navigator.pop(context);
              showSuccessToast('Deleted');
            },
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _viewLogs() async {
    final date = await pickDateFromBox(
      context: context,
      box: Hive.box('workouts'),
    );
    if (date == null || date == 'NO_DATA') return;
    final entries = Hive.box('workouts').get(date, defaultValue: []) as List;
    if (entries.isEmpty) {
      showErrorToast('No entries for $date');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Workout Log for $date'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in entries)
                ListTile(
                  title: Text(e['workout_type']),
                  subtitle:
                      Text('${e['exercises']} – ${e['sets']}×${e['reps']}'),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              Hive.box('workouts').delete(date);
              Navigator.of(dialogContext).pop();
              showSuccessToast('Deleted');
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _WorkoutChart extends StatelessWidget {
  const _WorkoutChart({super.key, required this.entries});
  final List<Map> entries;
  @override
  Widget build(BuildContext context) {
    int sets = 0, reps = 0;
    for (var e in entries) {
      sets += e['sets'] as int;
      reps += e['reps'] as int;
    }
    final d = [sets.toDouble(), reps.toDouble()];
    return BarChart(
      BarChartData(
        barGroups: [
          for (int i = 0; i < 2; i++)
            BarChartGroupData(x: i, barRods: [BarChartRodData(toY: d[i])]),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(['Sets', 'Reps'][v.toInt()]),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Workout Builder
/// ---------------------------------------------------------------------------
class WorkoutBuilder extends StatefulWidget {
  const WorkoutBuilder({super.key});
  @override
  State<WorkoutBuilder> createState() => _WorkoutBuilderState();
}

class _WorkoutBuilderState extends State<WorkoutBuilder> {
  final _dur = TextEditingController();
  String _goal = 'Build Muscle';
  String _intensity = 'Moderate';
  String _body = 'Mesomorph';
  String _diet = 'General Balanced Diet';
  String _level = 'Beginner';
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _dur.dispose();
    super.dispose();
  }

  Future<void> _gen() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final res = await postRequest(
        'https://fitbuddy-backend-ruby.vercel.app/generate_workout/',
        {
          'goal': _goal,
          'intensity': _intensity,
          'duration': _dur.text,
          'body_type': _body,
        },
      );
      Navigator.of(context).pop();
      setState(() => _loading = false);
      if (res != null && res['workout'] != null) {
        final plan = res['workout'] as String;
        // save to Hive
        final today = DateTime.now().toIso8601String().split('T').first;
        final box = Hive.box('savedWorkouts');
        final list = List<String>.from(box.get(today, defaultValue: []));
        list.add(plan);
        box.put(today, list);
        // show in popup
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Workout Plan'),
            content: SingleChildScrollView(child: Text(plan)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              )
            ],
          ),
        );
        showSuccessToast('Saved');
      } else {
        showErrorToast('No plan returned');
      }
    } catch (e) {
      Navigator.of(context).pop();
      setState(() => _loading = false);
      showErrorToast('Error: $e');
    }
  }

  Future<void> _viewSaved() async {
    final date = await pickDateFromBox(
      context: context,
      box: Hive.box('savedWorkouts'),
    );
    if (date == null || date == 'NO_DATA') return;
    final list = Hive.box('savedWorkouts').get(date, defaultValue: []) as List;
    if (list.isEmpty) {
      showErrorToast('No workouts for $date');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Workouts for $date'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < list.length; i++)
                ListTile(
                  title: Text('Workout ${i + 1}'),
                  subtitle: Text(list[i]),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              Hive.box('savedWorkouts').delete(date);
              Navigator.of(dialogContext).pop();
              showSuccessToast('Deleted');
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Builder'),
        actions: [homeBtn(context)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Goal'),
                value: _goal,
                items: [
                  'Build Muscle',
                  'Lose Weight',
                  'Improve Endurance',
                  'Increase Flexibility'
                ]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: _loading ? null : (v) => setState(() => _goal = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Intensity'),
                value: _intensity,
                items: ['Low', 'Moderate', 'High']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged:
                    _loading ? null : (v) => setState(() => _intensity = v!),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dur,
                decoration: const InputDecoration(labelText: 'Duration (mins)'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter duration';
                  if (int.tryParse(v) == null) return 'Enter a valid number';
                  return null;
                },
                enabled: !_loading,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Body Type'),
                    value: _body,
                    items: ['Ectomorph', 'Mesomorph', 'Endomorph']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged:
                        _loading ? null : (v) => setState(() => _body = v!),
                  ),
                ),
                Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  message: 'Body Type refers to your physique classification:\n'
                      '• Ectomorph – Lean frame, typically finds it difficult to gain weight.\n'
                      '• Mesomorph – Naturally muscular, gains muscle with relative ease.\n'
                      '• Endomorph – Softer, rounder physique, tends to store fat more readily.',
                  child: const Icon(Icons.info_outline),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Dietary Preference'),
                    value: _diet,
                    items: [
                      'General Balanced Diet',
                      'Keto',
                      'Vegan',
                      'Vegetarian',
                      'Paleo'
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged:
                        _loading ? null : (v) => setState(() => _diet = v!),
                  ),
                ),
                Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  message:
                      'Dietary Preference lets you pick the nutritional style that best fits your needs:\n'
                      '• General Balanced Diet – Variety from all food groups.\n'
                      '• Keto – Low‑carb, high‑fat plan aiming for ketosis.\n'
                      '• Vegan – Plant‑only; excludes every animal‑derived product.\n'
                      '• Vegetarian – No meat or fish; dairy & eggs optional.\n'
                      '• Paleo – Emphasises meat, fish, vegetables, fruit & nuts; avoids grains & dairy.',
                  child: const Icon(Icons.info_outline),
                ),
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Fitness Level'),
                value: _level,
                items: ['Beginner', 'Intermediate', 'Advanced']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: _loading ? null : (v) => setState(() => _level = v!),
              ),
              const SizedBox(height: 16),
              ResponsiveButtonGroup(buttons: [
                SecondaryButton(
                  text: 'Generate Workout',
                  onPressed: _loading ? null : _gen,
                ),
                SecondaryButton(
                  text: 'View Workouts',
                  onPressed: _viewSaved,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Diet Generator
/// ---------------------------------------------------------------------------
class DietGenerator extends StatefulWidget {
  const DietGenerator({super.key});
  @override
  State<DietGenerator> createState() => _DietGeneratorState();
}

class _DietGeneratorState extends State<DietGenerator> {
  String _diet = 'General Balanced Diet';
  String _goal = 'Lose Weight';
  String _body = 'Mesomorph';
  bool _loading = false;

  Future<void> _gen() async {
    setState(() => _loading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final res = await postRequest(
        'https://fitbuddy-backend-ruby.vercel.app/generate_diet/',
        {
          'diet_preference': _diet,
          'goal': _goal,
          'body_type': _body,
        },
      );
      Navigator.of(context).pop();
      setState(() => _loading = false);
      if (res?['diet'] != null) {
        final plan = res!['diet'] as String;
        final today = DateTime.now().toIso8601String().split('T').first;
        final box = Hive.box('savedDiets');
        final list = List<String>.from(box.get(today, defaultValue: []));
        list.add(plan);
        box.put(today, list);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Diet Plan'),
            content: SingleChildScrollView(child: Text(plan)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
        showSuccessToast('Saved');
      } else {
        showErrorToast('No plan returned');
      }
    } catch (e) {
      Navigator.of(context).pop();
      setState(() => _loading = false);
      showErrorToast('Error: $e');
    }
  }

  Future<void> _viewSaved() async {
    final date = await pickDateFromBox(
      context: context,
      box: Hive.box('savedDiets'),
    );
    if (date == null || date == 'NO_DATA') return;
    final list = Hive.box('savedDiets').get(date, defaultValue: []) as List;
    if (list.isEmpty) {
      showErrorToast('No diets for $date');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Diets for $date'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < list.length; i++)
                ListTile(
                  title: Text('Diet ${i + 1}'),
                  subtitle: Text(list[i]),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              Hive.box('savedDiets').delete(date);
              Navigator.of(dialogContext).pop();
              showSuccessToast('Deleted');
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diet Generator'),
        actions: [homeBtn(context)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Dietary Preference'),
                  value: _diet,
                  items: [
                    'General Balanced Diet',
                    'Keto',
                    'Vegan',
                    'Vegetarian',
                    'Paleo'
                  ]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (v) {
                          setState(() => _diet = v!);
                        },
                ),
              ),
              Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                message: 'Choose the base eating style:\n'
                    '• General Balanced Diet – Variety across all food groups.\n'
                    '• Keto – Very low‑carb, high‑fat approach.\n'
                    '• Vegan – Excludes all animal products entirely.\n'
                    '• Vegetarian – Excludes meat; dairy & eggs are usually allowed.\n'
                    '• Paleo – Focuses on foods presumed available to Paleolithic humans.',
                child: const Icon(Icons.info_outline),
              ),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Goal'),
              value: _goal,
              items: [
                'Lose Weight',
                'Build Muscle',
                'Maintain Weight',
                'Improve Health'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: _loading
                  ? null
                  : (v) {
                      setState(() => _goal = v!);
                    },
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Body Type'),
                  value: _body,
                  items: ['Ectomorph', 'Mesomorph', 'Endomorph']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (v) {
                          setState(() => _body = v!);
                        },
                ),
              ),
              Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                message: 'Body Type definitions:\n'
                    '• Ectomorph – Naturally lean, finds weight‑gain tough.\n'
                    '• Mesomorph – Muscular / athletic frame, gains muscle easily.\n'
                    '• Endomorph – Rounded build, stores fat more readily.',
                child: const Icon(Icons.info_outline),
              ),
            ]),
            const SizedBox(height: 16),
            ResponsiveButtonGroup(buttons: [
              SecondaryButton(
                text: 'Generate Diet Plan',
                onPressed: _loading
                    ? null
                    : () {
                        _gen();
                      },
              ),
              SecondaryButton(
                text: 'View Diets',
                onPressed: () {
                  _viewSaved();
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Workout Planner
/// ---------------------------------------------------------------------------
class WorkoutPlanner extends StatefulWidget {
  const WorkoutPlanner({super.key});
  @override
  State<WorkoutPlanner> createState() => _WorkoutPlannerState();
}

class _WorkoutPlannerState extends State<WorkoutPlanner> {
  late final Box _box;
  @override
  void initState() {
    super.initState();
    _box = Hive.box('planner');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Planner'),
        actions: [homeBtn(context)],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
            shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
        child: FloatingActionButton(
          onPressed: _addPlan,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: _box.listenable(),
        builder: (_, __, ___) {
          final map = Map<String, List>.from(_box.toMap());
          if (map.isEmpty) return const Center(child: Text('No plans yet'));
          return ListView(
            children: map.entries
                .expand((e) => e.value.map((plan) => ListTile(
                      title: Text(plan['workout']),
                      subtitle: Text('${e.key} • ${plan['time']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          final l = List<Map>.from(e.value)..remove(plan);
                          l.isEmpty ? _box.delete(e.key) : _box.put(e.key, l);
                          showSuccessToast('Deleted');
                        },
                      ),
                    )))
                .toList(),
          );
        },
      ),
    );
  }

  Future<void> _addPlan() async {
    final name = TextEditingController();
    DateTime? date;
    TimeOfDay? time;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New Workout Plan'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Workout Name'),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              text: date == null
                  ? 'Select Date'
                  : '${date!.year}-${date!.month}-${date!.day}',
              onPressed: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setS(() => date = d);
              },
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              text: time == null ? 'Select Time' : time!.format(ctx),
              onPressed: () async {
                final t = await showTimePicker(
                    context: ctx, initialTime: TimeOfDay.now());
                if (t != null) setS(() => time = t);
              },
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (name.text.isEmpty || date == null || time == null) {
                  showErrorToast('Complete all fields');
                  return;
                }
                final key = date!.toIso8601String().split('T').first;
                final list = List<Map>.from(_box.get(key, defaultValue: []));
                list.add({'workout': name.text, 'time': time!.format(ctx)});
                _box.put(key, list);
                Navigator.pop(ctx);
                showSuccessToast('Planned');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}