import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:google_fonts/google_fonts.dart';

class TimetableAlarmRingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;

  const TimetableAlarmRingScreen({Key? key, required this.alarmSettings}) : super(key: key);

  @override
  State<TimetableAlarmRingScreen> createState() => _TimetableAlarmRingScreenState();
}

class _TimetableAlarmRingScreenState extends State<TimetableAlarmRingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    await Alarm.stop(widget.alarmSettings.id);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _snoozeAlarm() async {
    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
    final snoozeSettings = widget.alarmSettings.copyWith(
      dateTime: snoozeTime,
    );
    await Alarm.set(alarmSettings: snoozeSettings);
    await Alarm.stop(widget.alarmSettings.id);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_controller.value * 0.1),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withOpacity(0.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.5 * _controller.value),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.alarm,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            Text(
              widget.alarmSettings.notificationSettings.title,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.alarmSettings.notificationSettings.body,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildButton(
                  title: 'Snooze 5m',
                  icon: Icons.snooze,
                  color: Colors.orange,
                  onTap: _snoozeAlarm,
                ),
                _buildButton(
                  title: 'Stop',
                  icon: Icons.stop,
                  color: Colors.redAccent,
                  onTap: _stopAlarm,
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
