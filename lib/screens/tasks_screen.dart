import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';
import '../widgets/task_tile.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return StreamBuilder<List<TaskModel>>(
      stream: firestoreService.watchTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];

        if (tasks.isEmpty) {
          return const Center(
            child: Text('No tasks found. Tap sync to pull from Classroom.'),
          );
        }

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return TaskTile(task: tasks[index]);
          },
        );
      },
    );
  }
}