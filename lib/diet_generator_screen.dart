// lib/diet_generator_screen.dart

import 'package:flutter/material.dart';
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

  // ───────────────────────── network / save / view ─────────────────────────
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
                onPressed: () => Navigator.pop(context),
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

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
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
                    onChanged:
                        _loading ? null : (v) => setState(() => _diet = v!),
                  ),
                ),
                Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  message: 'Choose the base eating style:\n'
                      '• General Balanced Diet – Variety across all food groups.\n'
                      '• Keto – Very low-carb, high-fat approach.\n'
                      '• Vegan – Excludes all animal products entirely.\n'
                      '• Vegetarian – Excludes meat; dairy & eggs are usually allowed.\n'
                      '• Paleo – Focuses on foods presumed available to Paleolithic humans.',
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
                ]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: _loading ? null : (v) => setState(() => _goal = v!),
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
                  message: 'Body Type definitions:\n'
                      '• Ectomorph – Naturally lean, finds weight-gain tough.\n'
                      '• Mesomorph – Muscular / athletic frame, gains muscle easily.\n'
                      '• Endomorph – Rounded build, stores fat more readily.',
                  child: const Icon(Icons.info_outline),
                ),
              ]),
              const SizedBox(height: 16),
              ResponsiveButtonGroup(buttons: [
                SecondaryButton(
                  text: 'Generate Diet Plan',
                  onPressed: _loading ? null : _gen,
                ),
                SecondaryButton(
                  text: 'View Diets',
                  onPressed: _viewSaved,
                ),
              ]),
            ],
          ),
        ),
      );
}
