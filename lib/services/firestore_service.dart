import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> saveFcmToken(String token) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('devices')
        .doc('primary')
        .set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveTasks(List<TaskModel> tasks) async {
    final batch = _db.batch();

    for (final task in tasks) {
      final ref = _db
          .collection('users')
          .doc(_uid)
          .collection('tasks')
          .doc(task.id);

      batch.set(ref, task.toMap(), SetOptions(merge: true));
    }

    batch.set(
      _db.collection('users').doc(_uid),
      {
        'email': FirebaseAuth.instance.currentUser?.email,
        'lastSyncAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Stream<List<TaskModel>> watchTasks() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('tasks')
        .orderBy('dueAtUtc')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }
}