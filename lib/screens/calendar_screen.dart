import 'dart:async';
import 'package:exam_schedule_app/screens/location_screen.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/exam_model.dart';
import '../widgets/location_picker_widget.dart';


class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  LatLng? _selectedLocation;
  Map<DateTime, List<Exam>> _events = {};
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;


  Set<String> notifiedExams = Set();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startLocationMonitoring();
  }

  Future<void> _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'reminder_channel',
      'Location Reminders',
      description: 'Notifications for location-based reminders',
      importance: Importance.high,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  void _startLocationMonitoring() async {
    bool locationPermissionGranted = await _checkLocationPermission();
    if (!locationPermissionGranted) return;

    Timer.periodic(Duration(minutes: 1), (timer) {
      _checkLocationReminders();
    });
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }
    return true;
  }

  Future<void> _checkLocationReminders() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    LatLng userLocation = LatLng(position.latitude, position.longitude);

    _events.forEach((date, exams) {
      for (var exam in exams) {
        print('Checking exam: ${exam.name}');
        if (exam.isLocationReminderEnabled) {
          final distance = Geolocator.distanceBetween(
            userLocation.latitude,
            userLocation.longitude,
            exam.latitude,
            exam.longitude,
          );
          print('Distance to ${exam.name}: $distance meters');


          if (distance <= 500 && !notifiedExams.contains(exam.name)) {
            _showNotification(exam.name, exam.location);
            notifiedExams.add(exam.name);
          }
        }
      }
    });
  }

  void _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Location Reminders',
      channelDescription: 'Notifications for location-based reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }


  void _addExam() {
    if (_selectedDay == null) return;

    TextEditingController nameController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isLocationReminderEnabled = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                "Add a new exam",
                style: TextStyle(color: Colors.indigo.shade700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Subject Name",
                      labelStyle: TextStyle(color: Colors.indigo.shade700),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.indigo.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.indigo.shade700),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Colors.indigo.shade700, // Highlight color
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedTime != null) {
                        setState(() {
                          selectedTime = pickedTime;
                        });
                      }
                    },
                    icon: Icon(Icons.access_time),
                    label: Text("Pick a time"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo.shade700,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // Smaller border radius
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final selectedLocation = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocationPickerWidget(),
                        ),
                      );
                      if (selectedLocation != null) {
                        setState(() {
                          _selectedLocation = selectedLocation;
                        });
                      }
                    },
                    icon: Icon(Icons.location_on),
                    label: Text("Pick Location"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo.shade700,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // Smaller border radius
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      'Activate notification reminder',
                      style: TextStyle(color: Colors.indigo.shade700),
                    ),
                    value: isLocationReminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        isLocationReminderEnabled = value;
                      });
                    },
                    activeColor: Colors.indigo.shade700,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.indigo.shade700),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty && _selectedLocation != null) {
                      setState(() {
                        final eventDate = DateTime(
                          _selectedDay!.year,
                          _selectedDay!.month,
                          _selectedDay!.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        final exam = Exam(
                          name: nameController.text,
                          location: "${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}",
                          dateTime: eventDate,
                          latitude: _selectedLocation!.latitude,
                          longitude: _selectedLocation!.longitude,
                          isLocationReminderEnabled: isLocationReminderEnabled,
                        );
                        _events[_selectedDay!] = (_events[_selectedDay!] ?? [])..add(exam);
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    "Add",
                    style: TextStyle(color: Colors.indigo.shade700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Schedule'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(12),
              child: TableCalendar(
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Colors.indigo,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: (day) {
                  return _events[day] ?? [];
                },
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _selectedDay != null
                ? (_events[_selectedDay]?.isNotEmpty ?? false
                ? ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _events[_selectedDay]!.length,
              itemBuilder: (context, index) {
                final exam = _events[_selectedDay]![index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(
                      exam.name,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                        '${exam.location} | ${exam.dateTime.hour}:${exam.dateTime.minute}'),
                    trailing: IconButton(
                      icon: Icon(Icons.map, color: Colors.indigo),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                LocationScreen(exam: exam),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            )
                : Center(child: Text('No scheduled exams for today')))
                : Center(
              child: Text(
                'Choose a date to view exams',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExam,
        child: Icon(Icons.add),
      ),
    );
  }
}