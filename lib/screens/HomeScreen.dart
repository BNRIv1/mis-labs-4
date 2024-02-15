import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lab4_201177/screens/CalendarScreen.dart';
import 'package:lab4_201177/widgets/AuthGate.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:lab4_201177/domain/Exam.dart';
import 'package:lab4_201177/widgets/NewExam.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CollectionReference _itemsCollection =
      FirebaseFirestore.instance.collection('exams');
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static void initialize() {
    const InitializationSettings initializationSettingsAndroid =
        InitializationSettings(
      android: AndroidInitializationSettings('image'),
    );
    _notificationsPlugin.initialize(
      initializationSettingsAndroid,
      onDidReceiveNotificationResponse: (details) {
        if (details.input != null) {}
      },
    );
  }

  Future<void> _requestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initialize();
    _requestNotificationPermission();

    OneSignal.shared.setAppId("657ac24e-e486-475b-85ab-925e4654ddfc");

    OneSignal.shared
        .setNotificationOpenedHandler((OSNotificationOpenedResult result) {});

    FirebaseMessaging.instance.getToken().then((token) {});
    FirebaseMessaging.instance.getInitialMessage().then((_) {});

    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) {
        display(message);
      }
    });
  }

  Future<void> requestPermission() async {
    await OneSignal.shared.promptUserForPushNotificationPermission();
  }

  static Future<void> display(RemoteMessage message) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
            message.notification!.android!.sound ?? "Channel Id",
            message.notification!.android!.sound ?? "Main Channel",
            groupKey: "gfg",
            color: Colors.green,
            importance: Importance.max,
            sound: RawResourceAndroidNotificationSound(
                message.notification!.android!.sound ?? "gfg"),
            playSound: true,
            priority: Priority.high),
      );
      await _notificationsPlugin.show(id, message.notification?.title,
          message.notification?.body, notificationDetails,
          payload: message.data['route']);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _addExam() {
    showModalBottomSheet(
        context: context,
        builder: (_) {
          return GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: NewExam(
              addExam: _addNewExamToDatabase,
            ),
          );
        });
  }

  void _addNewExamToDatabase(
      String subject, DateTime date, TimeOfDay time) async {
    String topic = 'exams';

    FirebaseMessaging.instance.subscribeToTopic(topic);

    try {
      var deviceState = await OneSignal.shared.getDeviceState();
      String? playerId = deviceState?.userId;

      if (playerId != null && playerId.isNotEmpty) {
        List<String> playerIds = [playerId];

        try {
          await OneSignal.shared.postNotification(OSCreateNotification(
            playerIds: playerIds,
            content: "You have a new exam: $subject",
            heading: "New Exam Added",
          ));
        } catch (e) {}
      } else {}
    } catch (e) {}

    addExam(subject, date, time);
  }

  Future<void> addExam(String subject, DateTime date, TimeOfDay time) {
    User? user = FirebaseAuth.instance.currentUser;
    DateTime newDate = DateTime(
        date.year, date.month, date.day, time.hour, time.minute, 0, 0, 0);
    if (user != null) {
      return FirebaseFirestore.instance
          .collection('exams')
          .add({'subjectName': subject, 'examDate': newDate, 'userId': user.uid});
    }

    return FirebaseFirestore.instance
        .collection('exams')
        .add({'subjectName': subject, 'examDate': newDate, 'userId': 'invalid'});
  }

  Future<void> _signOutAndNavigateToLogin(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => AuthGate()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {}
  }

  void _goToCalendar() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => CalendarScreen()));
  }

  Future<void> _deleteExam(String subject, DateTime date) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      var query = _itemsCollection
          .where('subjectName', isEqualTo: subject)
          .where('examDate', isEqualTo: date)
          .where('userId', isEqualTo: user.uid);

      query.get().then((querySnapshot) {
        for (var doc in querySnapshot.docs) {
          _itemsCollection.doc(doc.id).delete();
        }
      });
    }

    String topic = 'exams';

    FirebaseMessaging.instance.subscribeToTopic(topic);

    try {
      var deviceState = await OneSignal.shared.getDeviceState();
      String? playerId = deviceState?.userId;

      if (playerId != null && playerId.isNotEmpty) {
        List<String> playerIds = [playerId];

        try {
          await OneSignal.shared.postNotification(OSCreateNotification(
            playerIds: playerIds,
            content: "You deleted an exam: $subject",
            heading: "Exam deleted",
          ));
        } catch (e) {}
      } else {}
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Exam Scheduler - 201177"),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            ElevatedButton(
              onPressed: () => _addExam(),
              style: const ButtonStyle(
                  backgroundColor:
                      MaterialStatePropertyAll<Color>(Colors.blue)),
              child: const Text(
                "Add exam",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () => _signOutAndNavigateToLogin(context),
              style: const ButtonStyle(
                  backgroundColor:
                      MaterialStatePropertyAll<Color>(Colors.greenAccent)),
              child: const Text(
                "Sign out",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
            stream: _itemsCollection
                .where('userId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              List<Exam> items =
                  snapshot.data!.docs.map((DocumentSnapshot doc) {
                return Exam.fromMap(doc.data() as Map<String, dynamic>);
              }).toList();

              return GridView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  items[index].subjectName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 30,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('yyyy-MM-dd HH:mm')
                                      .format(items[index].examDate),
                                  style: const TextStyle(
                                      fontSize: 20, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          top: 5.0,
                          right: 5.0,
                          child: IconButton(
                            icon: const Icon(Icons.delete_forever_rounded),
                            onPressed: () {
                              _deleteExam(items[index].subjectName,
                                  items[index].examDate);
                            },
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                ),
              );
            }),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
                onPressed: _goToCalendar,
                style: const ButtonStyle(
                  backgroundColor:
                      MaterialStatePropertyAll<Color>(Colors.blue),
                ),
                child: const Row(
                  children: [
                    Text(
                      "View calendar",
                      style: TextStyle(color: Colors.white),
                    ),
                    Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                    )
                  ],
                ))
          ],
        ));
  }
}
