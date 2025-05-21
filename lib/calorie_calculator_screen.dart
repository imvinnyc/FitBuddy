// lib/calorie_calculator_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart' show SecondaryButton, homeBtn;

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
  void dispose() {
    _age.dispose();
    _h.dispose();
    _w.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  decoration:
                      const InputDecoration(labelText: 'Activity Level'),
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

  // ───────────────────────── helpers ─────────────────────────
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
