import 'package:flutter/material.dart';
import 'package:mindlink/services/focus_service.dart';
import 'package:provider/provider.dart';

class FocusModeScreen extends StatefulWidget {
  static const String id = 'focus_mode_screen';

  @override
  _FocusModeScreenState createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusService>(
      builder: (context, focusService, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('🎯 Focus Mode'),
            backgroundColor: Colors.deepPurple,
            actions: [
              if (focusService.isFocusMode)
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    focusService.stopFocusSession();
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: focusService.isFocusMode
                    ? [Colors.deepPurple, Colors.purple]
                    : [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: Center(
              child: focusService.isFocusMode
                  ? _buildFocusSession(focusService)
                  : _buildFocusStarter(focusService),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFocusStarter(FocusService focusService) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _controller,
            child: Icon(
              Icons.timer,
              size: 80,
              color: Colors.deepPurple,
            ),
          ),
          SizedBox(height: 30),
          Text(
            'Pomodoro Focus Mode',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple),
          ),
          SizedBox(height: 10),
          Text(
            'Boost your productivity with focused study sessions',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          SizedBox(height: 40),
          _buildDurationSelector(focusService),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              focusService.startFocusSession();
              _showFocusStartedDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
            ),
            child: Text(
              'Start Focus Session',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Completed Sessions: ${focusService.completedSessions}',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector(FocusService focusService) {
    final durations = [25, 45, 60];
    return Column(
      children: [
        Text('Select Duration:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: durations.map((minutes) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: ChoiceChip(
                label: Text('$minutes min'),
                selected: focusService.focusMinutes == minutes,
                onSelected: (selected) {
                  if (selected) {
                    focusService.setFocusDuration(minutes);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFocusSession(FocusService focusService) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Circular Progress Timer
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CircularProgressIndicator(
                value: focusService.progress,
                strokeWidth: 8,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            Column(
              children: [
                Text(
                  focusService.formattedTime,
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                SizedBox(height: 8),
                Text(
                  'Remaining',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 40),
        // Control Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => focusService.toggleTimer(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
              ),
              child: Icon(
                focusService.isRunning ? Icons.pause : Icons.play_arrow,
                size: 30,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(width: 20),
            ElevatedButton(
              onPressed: () {
                focusService.stopFocusSession();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
              ),
              child: Icon(Icons.stop, size: 30, color: Colors.white),
            ),
          ],
        ),
        SizedBox(height: 30),
        Text(
          'Stay focused! Avoid distractions.',
          style: TextStyle(
              fontSize: 16, color: Colors.white70, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  void _showFocusStartedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🎯 Focus Mode Started'),
        content: Text(
            'Your ${context.read<FocusService>().focusMinutes}-minute focus session has begun. Stay focused and avoid distractions!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
