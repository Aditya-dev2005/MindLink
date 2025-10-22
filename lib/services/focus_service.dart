import 'package:flutter/material.dart';
import 'dart:async';

class FocusService with ChangeNotifier {
  bool _isFocusMode = false;
  int _focusMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  int _completedSessions = 0;
  DateTime? _currentSessionStart;
  Timer? _timer;

  bool get isFocusMode => _isFocusMode;
  int get focusMinutes => _focusMinutes;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  int get completedSessions => _completedSessions;

  void startFocusSession() {
    _isFocusMode = true;
    _isRunning = true;
    _remainingSeconds = _focusMinutes * 60;
    _currentSessionStart = DateTime.now();
    notifyListeners();

    _startTimer(); // Start the timer when session begins
  }

  void stopFocusSession() {
    _isFocusMode = false;
    _isRunning = false;
    _timer?.cancel(); // Stop the timer
    _timer = null;

    if (_currentSessionStart != null) {
      _completedSessions++;
    }
    notifyListeners();
  }

  void toggleTimer() {
    _isRunning = !_isRunning;
    if (_isRunning && _timer == null) {
      _startTimer(); // Restart timer if it was stopped
    }
    notifyListeners();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isRunning && _remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else if (_remainingSeconds == 0) {
        _completeSession();
        timer.cancel();
        _timer = null;
      }

      // Stop timer if focus mode is turned off
      if (!_isFocusMode) {
        timer.cancel();
        _timer = null;
      }
    });
  }

  void _completeSession() {
    _isRunning = false;
    _completedSessions++;
    _timer?.cancel();
    _timer = null;
    // Could trigger celebration or notification
    notifyListeners();
  }

  void setFocusDuration(int minutes) {
    _focusMinutes = minutes;
    _remainingSeconds = minutes * 60;
    notifyListeners();
  }

  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get progress {
    return 1 - (_remainingSeconds / (_focusMinutes * 60));
  }

  Map<String, dynamic> toJson() {
    return {
      'completed_sessions': _completedSessions,
      'total_focus_minutes': _completedSessions * _focusMinutes,
    };
  }

  // Clean up timer when service is disposed
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
