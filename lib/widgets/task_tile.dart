import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';

class TaskTile extends StatelessWidget {
  final TaskModel task;

  const TaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final dueText = task.dueAtUtc == null
        ? 'No due date'
        : DateFormat('dd MMM yyyy, hh:mm a').format(task.dueAtUtc!.toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(task.title),
        subtitle: Text('${task.courseName}\nDue: $dueText'),
        isThreeLine: true,
        trailing: task.notified48h
            ? const Icon(Icons.notifications_active)
            : const Icon(Icons.notifications_none),
      ),
    );
  }
}