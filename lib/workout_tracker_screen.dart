// lib/workout_tracker_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  void dispose() {
    _ex.dispose();
    _sets.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
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
                SecondaryButton(
                    text: 'View Visualizations', onPressed: _viewVis),
                SecondaryButton(text: 'View Logs', onPressed: _viewLogs),
              ]),
            ],
          ),
        ),
      );

  // ───────────────────────── helpers ─────────────────────────
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
      'reps': int.parse(_reps.text),
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
            child: const Text('Close'),
          ),
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

/// ---------------------------------------------------------------------------
/// WorkoutChart  – bar chart for sets vs reps
/// ---------------------------------------------------------------------------
class _WorkoutChart extends StatelessWidget {
  const _WorkoutChart({super.key, required this.entries});
  final List<Map> entries;

  @override
  Widget build(BuildContext context) {
    int sets = 0, reps = 0;
    for (final e in entries) {
      sets += e['sets'] as int;
      reps += e['reps'] as int;
    }
    final data = [sets.toDouble(), reps.toDouble()];

    return BarChart(
      BarChartData(
        barGroups: [
          for (int i = 0; i < 2; i++)
            BarChartGroupData(x: i, barRods: [BarChartRodData(toY: data[i])]),
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
