// lib/nutrition_tracker_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

import 'main.dart'
    show
        pickDateFromBox,
        showErrorToast,
        showSuccessToast,
        SecondaryButton,
        ResponsiveButtonGroup,
        listProv,
        homeBtn;

/// ────────────────────────────────────────────────────────────────────────────
/// NutritionTracker  – log foods and visualise macros
/// ────────────────────────────────────────────────────────────────────────────
class NutritionTracker extends ConsumerStatefulWidget {
  const NutritionTracker({super.key});
  @override
  ConsumerState<NutritionTracker> createState() => _NutritionTrackerState();
}

class _NutritionTrackerState extends ConsumerState<NutritionTracker> {
  final _formKey = GlobalKey<FormState>();
  final _food = TextEditingController();
  final _cal = TextEditingController();
  final _fat = TextEditingController();
  final _pro = TextEditingController();
  final _carb = TextEditingController();
  final _fib = TextEditingController();

  @override
  void dispose() {
    _food.dispose();
    _cal.dispose();
    _fat.dispose();
    _pro.dispose();
    _carb.dispose();
    _fib.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                        decoration:
                            const InputDecoration(labelText: 'Food / Dish'),
                      ),
                      suggestionsCallback: (pattern) async {
                        if (pattern.isEmpty) return <String>[];
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
                  SecondaryButton(text: 'View Logs', onPressed: _viewLogs),
                ],
              ),
            ],
          ),
        ),
      );

  // ───────────────────────── helpers ─────────────────────────
  TextFormField _num(TextEditingController c, String l) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: l),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
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

  Future<void> _viewLogs() async {
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
                    'Cal: ${e['Calories']}  •  Fat: ${e['Fat']}  •  Pro: ${e['Protein']}  •  Carb: ${e['Carbohydrates']}  •  Fib: ${e['Fiber']}',
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

  Future<List<String>> _fetchFoodSuggestions(String query) async {
    try {
      final r = await http.post(
        Uri.parse('https://fitbuddy-backend-ruby.vercel.app/nutritionix/'),
        body: {'query': query},
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        return List<String>.from(d['suggestions'] ?? []);
      }
    } catch (_) {}
    return <String>[];
  }

  Future<Map<String, dynamic>?> _fetchFoodNutrition(String food) async {
    try {
      final r = await http.post(
        Uri.parse('https://fitbuddy-backend-ruby.vercel.app/nutritionix/'),
        body: {'food': food},
      );
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return null;
  }
}

/// ────────────────────────────────────────────────────────────────────────────
/// NutritionChart
/// ────────────────────────────────────────────────────────────────────────────
class _NutritionChart extends StatelessWidget {
  const _NutritionChart({required this.entries});
  final List<Map> entries;

  @override
  Widget build(BuildContext context) {
    double cal = 0, fat = 0, pro = 0, carb = 0, fib = 0;
    for (final e in entries) {
      cal += (e['Calories'] as num).toDouble();
      fat += (e['Fat'] as num).toDouble();
      pro += (e['Protein'] as num).toDouble();
      carb += (e['Carbohydrates'] as num).toDouble();
      fib += (e['Fiber'] as num).toDouble();
    }
    final data = [cal, fat, pro, carb, fib];

    return BarChart(
      BarChartData(
        barGroups: [
          for (int i = 0; i < data.length; i++)
            BarChartGroupData(x: i, barRods: [BarChartRodData(toY: data[i])]),
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
