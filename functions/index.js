const admin = require("firebase-admin");
const {onSchedule} = require("firebase-functions/v2/scheduler");

admin.initializeApp();
const db = admin.firestore();

exports.send48HourReminders = onSchedule("every 60 minutes", async () => {
  const usersSnapshot = await db.collection("users").get();
  const nowIso = new Date().toISOString();

  for (const userDoc of usersSnapshot.docs) {
    const uid = userDoc.id;

    const deviceDoc = await db
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc("primary")
        .get();

    const token = deviceDoc.data()?.fcmToken;
    if (!token) continue;

    const tasksSnapshot = await db
        .collection("users")
        .doc(uid)
        .collection("tasks")
        .where("notified48h", "==", false)
        .where("remindAtUtc", "<=", nowIso)
        .get();

    for (const taskDoc of tasksSnapshot.docs) {
      const task = taskDoc.data();

      await admin.messaging().send({
        token: token,
        notification: {
          title: `Deadline soon: ${task.title}`,
          body: `${task.courseName} is due in less than 48 hours.`,
        },
        data: {
          taskId: taskDoc.id,
        },
      });

      await taskDoc.ref.update({
        notified48h: true,
      });
    }
  }
});