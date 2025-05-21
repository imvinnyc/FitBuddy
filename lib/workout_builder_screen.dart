// lib/workout_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'main.dart'
    show
        postRequest,
        pickDateFromBox,
        showErrorToast,
        showSuccessToast,
        SecondaryButton,
        ResponsiveButtonGroup,
        homeBtn;

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

  // ───────────────────────── network / save / view ─────────────────────────
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

        // save
        final today = DateTime.now().toIso8601String().split('T').first;
        final box = Hive.box('savedWorkouts');
        final list = List<String>.from(box.get(today, defaultValue: []));
        list.add(plan);
        box.put(today, list);

        // show
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

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
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
                  onChanged:
                      _loading ? null : (v) => setState(() => _goal = v!),
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
                  decoration:
                      const InputDecoration(labelText: 'Duration (mins)'),
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
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged:
                          _loading ? null : (v) => setState(() => _body = v!),
                    ),
                  ),
                  Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    message:
                        'Body Type refers to your physique classification:\n'
                        '• Ectomorph – Lean frame, typically finds it difficult to gain weight.\n'
                        '• Mesomorph – Naturally muscular, gains muscle with relative ease.\n'
                        '• Endomorph – Softer, rounder physique, tends to store fat more readily.',
                    child: const Icon(Icons.info_outline),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'Dietary Preference'),
                      value: _diet,
                      items: [
                        'General Balanced Diet',
                        'Keto',
                        'Vegan',
                        'Vegetarian',
                        'Paleo'
                      ]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged:
                          _loading ? null : (v) => setState(() => _diet = v!),
                    ),
                  ),
                  Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    message:
                        'Dietary Preference lets you pick the nutritional style that best fits your needs:\n'
                        '• General Balanced Diet – Variety from all food groups.\n'
                        '• Keto – Low-carb, high-fat plan aiming for ketosis.\n'
                        '• Vegan – Plant-only; excludes every animal-derived product.\n'
                        '• Vegetarian – No meat or fish; dairy & eggs optional.\n'
                        '• Paleo – Emphasises meat, fish, vegetables, fruit & nuts; avoids grains & dairy.',
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
                  onChanged:
                      _loading ? null : (v) => setState(() => _level = v!),
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
