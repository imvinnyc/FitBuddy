// lib/workout_planner_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'main.dart'
    show showErrorToast, showSuccessToast, SecondaryButton, homeBtn;

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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Workout Planner'),
          actions: [homeBtn(context)],
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey),
          ),
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
            if (map.isEmpty) {
              return const Center(child: Text('No plans yet'));
            }
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

  // ───────────────────────── add-plan dialog ─────────────────────────
  Future<void> _addPlan() async {
    final name = TextEditingController();
    DateTime? date;
    TimeOfDay? time;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New Workout Plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
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
                    context: ctx,
                    initialTime: TimeOfDay.now(),
                  );
                  if (t != null) setS(() => time = t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
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
