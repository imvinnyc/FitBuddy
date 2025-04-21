// lib/exercise_tutorial_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:fitbuddy/main.dart'
    show
        pickDateFromBox,
        showErrorToast,
        showSuccessToast,
        SecondaryButton,
        ResponsiveButtonGroup;

class ExerciseTutorialScreen extends StatefulWidget {
  const ExerciseTutorialScreen({super.key});
  @override
  State<ExerciseTutorialScreen> createState() => _ExerciseTutorialScreenState();
}

class _ExerciseTutorialScreenState extends State<ExerciseTutorialScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // rebuild when text changes so button enabling works
    _ctrl.addListener(() => setState(() {}));
  }

  Future<List<String>> _getSuggestions(String pattern) async {
    try {
      final res = await http.post(
        Uri.parse('https://fitbuddy-backend-ruby.vercel.app/exercise_suggest/'),
        body: {'query': pattern},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return List<String>.from(data['suggestions'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<void> _getTutorial(String exercise) async {
    setState(() => _loading = true);

    // show spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final res = await http.post(
        Uri.parse(
            'https://fitbuddy-backend-ruby.vercel.app/exercise_tutorial/'),
        body: {'exercise': exercise},
      );
      Navigator.of(context).pop(); // pop spinner
      setState(() => _loading = false);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final tut = data['tutorial'] as String? ?? 'No tutorial found.';

        // save to Hive
        final box = Hive.box('exerciseTutorials');
        final today = DateTime.now().toIso8601String().split('T').first;
        final list = List<Map<String, String>>.from(
          box.get(today, defaultValue: []),
        );
        list.add({'exercise': exercise, 'tutorial': tut});
        box.put(today, list);

        // show tutorial dialog, dynamic size
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(exercise),
            content: SingleChildScrollView(
              child: Text(tut),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );

        showSuccessToast('Saved tutorial');
      } else {
        showErrorToast('Server error: ${res.statusCode}');
      }
    } catch (e) {
      Navigator.of(context).pop(); // pop spinner
      setState(() => _loading = false);
      showErrorToast('Network error: $e');
    }
  }

  Future<void> _viewSaved() async {
    final date = await pickDateFromBox(
      context: context,
      box: Hive.box('exerciseTutorials'),
    );
    if (date == null || date == 'NO_DATA') return;

    final entries =
        Hive.box('exerciseTutorials').get(date, defaultValue: []) as List;
    if (entries.isEmpty) {
      showErrorToast('No tutorials for $date');
      return;
    }

    // viewSaved dialog, dynamic size like above
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Tutorials for $date'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in entries)
                ListTile(
                  title: Text(e['exercise'] ?? ''),
                  subtitle: Text(e['tutorial'] ?? ''),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              Hive.box('exerciseTutorials').delete(date);
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Exercise Tutorial'),
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () => context.go('/'),
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TypeAheadFormField<String>(
                  textFieldConfiguration: TextFieldConfiguration(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Enter exercise here...',
                      filled: true,
                      fillColor: Color(0xFF2D2D2D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  suggestionsCallback: _getSuggestions,
                  itemBuilder: (_, s) => ListTile(title: Text(s)),
                  onSuggestionSelected: (s) => _ctrl.text = s,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                  noItemsFoundBuilder: (_) => const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No exercises found'),
                  ),
                ),
                const SizedBox(height: 12),
                ResponsiveButtonGroup(
                  buttons: [
                    SecondaryButton(
                      text: 'Get Tutorial',
                      onPressed: _loading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                _getTutorial(_ctrl.text.trim());
                              }
                            },
                    ),
                    SecondaryButton(
                      text: 'View Exercises',
                      onPressed: _viewSaved,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
