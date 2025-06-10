import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

void main() {
  runApp(BlinkReminderApp());
}

class BlinkReminderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blink Reminder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BlinkReminderHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BlinkReminderHome extends StatefulWidget {
  @override
  _BlinkReminderHomeState createState() => _BlinkReminderHomeState();
}

class _BlinkReminderHomeState extends State<BlinkReminderHome>
    with WidgetsBindingObserver {
  Timer? _blinkTimer;
  bool _isActive = false;
  bool _showOverlay = false;
  bool _hasOverlayPermission = false;
  int _intervalSeconds = 600; // Default 10 minutes in seconds
  int _overlayDurationSeconds = 3;
  TextEditingController _customIntervalController = TextEditingController();
  bool _useCustomInterval = false;

  // Platform channel for native functionality
  static const platform = MethodChannel('blink_reminder/overlay');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOverlayPermission();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _customIntervalController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep timer running even when app is in background
    if (state == AppLifecycleState.paused && _isActive) {
      // App moved to background, timer continues
    }
  }

  void _startBlinkReminder() {
    setState(() {
      _isActive = true;
    });

    _blinkTimer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (timer) => _showBlinkReminder(),
    );
  }

  void _stopBlinkReminder() {
    setState(() {
      _isActive = false;
    });
    _blinkTimer?.cancel();
  }

  void _showBlinkReminder() async {
    try {
      // Try to show system overlay if permissions are available
      await platform.invokeMethod('showOverlay', {
        'duration': _overlayDurationSeconds * 1000, // Convert to milliseconds
      });
    } catch (e) {
      print('System overlay failed: $e');
      // Fallback to in-app overlay
      _showInAppOverlay();
    }
  }

  void _checkOverlayPermission() async {
    try {
      final hasPermission = await platform.invokeMethod('checkPermission');
      setState(() {
        _hasOverlayPermission = hasPermission ?? false;
      });
    } catch (e) {
      setState(() {
        _hasOverlayPermission = false;
      });
    }
  }

  void _requestOverlayPermission() async {
    try {
      await platform.invokeMethod('requestPermission');
      // Check permission after a delay
      Future.delayed(Duration(seconds: 1), () {
        _checkOverlayPermission();
      });
    } catch (e) {
      print('Failed to request permission: $e');
    }
  }

  void _showInAppOverlay() {
    setState(() {
      _showOverlay = true;
    });

    // Auto-hide overlay after specified duration
    Timer(Duration(seconds: _overlayDurationSeconds), () {
      if (mounted) {
        setState(() {
          _showOverlay = false;
        });
      }
    });

    // Vibrate to get attention
    HapticFeedback.heavyImpact();
  }

  String _formatInterval(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      int minutes = seconds ~/ 60;
      int remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '${minutes}m';
      } else {
        return '${minutes}m ${remainingSeconds}s';
      }
    } else {
      int hours = seconds ~/ 3600;
      int remainingMinutes = (seconds % 3600) ~/ 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  void _setCustomInterval() {
    String input = _customIntervalController.text.trim();
    if (input.isEmpty) return;

    int? seconds = int.tryParse(input);
    if (seconds != null && seconds >= 5 && seconds <= 3600) {
      setState(() {
        _intervalSeconds = seconds;
        _useCustomInterval = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a value between 5 and 3600 seconds'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main app content
          Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.remove_red_eye,
                  size: 80,
                  color: _isActive ? Colors.green : Colors.grey,
                ),
                SizedBox(height: 20),
                Text(
                  'Blink Reminder',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Protect your eyes with regular blink reminders',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                SizedBox(height: 40),

                // Permission status and request
                if (!_hasOverlayPermission)
                  Card(
                    color: Colors.orange.withOpacity(0.1),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Overlay Permission Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'To show reminders over other apps, please grant overlay permission.',
                            style: TextStyle(color: Colors.orange[700]),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _requestOverlayPermission,
                            child: Text('Grant Permission'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_hasOverlayPermission)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Overlay permission granted',
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 20),

                // Settings
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reminder Interval',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),

                        // Quick preset buttons
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _IntervalChip(
                              label: '10s',
                              seconds: 10,
                              isSelected:
                                  _intervalSeconds == 10 && !_useCustomInterval,
                              onTap: () {
                                setState(() {
                                  _intervalSeconds = 10;
                                  _useCustomInterval = false;
                                });
                              },
                              isEnabled: !_isActive,
                            ),
                            _IntervalChip(
                              label: '20s',
                              seconds: 20,
                              isSelected:
                                  _intervalSeconds == 20 && !_useCustomInterval,
                              onTap: () {
                                setState(() {
                                  _intervalSeconds = 20;
                                  _useCustomInterval = false;
                                });
                              },
                              isEnabled: !_isActive,
                            ),
                            _IntervalChip(
                              label: '30s',
                              seconds: 30,
                              isSelected:
                                  _intervalSeconds == 30 && !_useCustomInterval,
                              onTap: () {
                                setState(() {
                                  _intervalSeconds = 30;
                                  _useCustomInterval = false;
                                });
                              },
                              isEnabled: !_isActive,
                            ),
                            _IntervalChip(
                              label: '1m',
                              seconds: 60,
                              isSelected:
                                  _intervalSeconds == 60 && !_useCustomInterval,
                              onTap: () {
                                setState(() {
                                  _intervalSeconds = 60;
                                  _useCustomInterval = false;
                                });
                              },
                              isEnabled: !_isActive,
                            ),
                            _IntervalChip(
                              label: '5m',
                              seconds: 300,
                              isSelected: _intervalSeconds == 300 &&
                                  !_useCustomInterval,
                              onTap: () {
                                setState(() {
                                  _intervalSeconds = 300;
                                  _useCustomInterval = false;
                                });
                              },
                              isEnabled: !_isActive,
                            ),
                            _IntervalChip(
                              label: '10m',
                              seconds: 600,
                              isSelected: _intervalSeconds == 600 &&
                                  !_useCustomInterval,
                              onTap: () {
                                setState(() {
                                  _intervalSeconds = 600;
                                  _useCustomInterval = false;
                                });
                              },
                              isEnabled: !_isActive,
                            ),
                            _IntervalChip(
                              label: '20m',
                              seconds: 1200,
                              isSelected: _intervalSeconds == 1200 &&
                                  !_useCustomInterval,
                              onTap: () {
                                setState(() {
                                  _intervalSeconds = 1200;
                                  _useCustomInterval = false;
                                });
                              },
                              isEnabled: !_isActive,
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Custom interval input
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customIntervalController,
                                keyboardType: TextInputType.number,
                                enabled: !_isActive,
                                decoration: InputDecoration(
                                  labelText: 'Custom interval (seconds)',
                                  hintText: 'e.g., 15 for 15 seconds',
                                  border: OutlineInputBorder(),
                                  suffixText: 's',
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isActive ? null : _setCustomInterval,
                              child: Text('Set'),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),
                        Text(
                          'Current: ${_formatInterval(_intervalSeconds)}${_useCustomInterval ? ' (custom)' : ''}',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 16),

                        // Overlay duration setting
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Overlay Duration'),
                            Row(
                              children: [
                                Text('$_overlayDurationSeconds sec'),
                                SizedBox(width: 10),
                                DropdownButton<int>(
                                  value: _overlayDurationSeconds,
                                  items: [1, 2, 3, 5, 10]
                                      .map(
                                        (seconds) => DropdownMenuItem(
                                          value: seconds,
                                          child: Text('$seconds sec'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _isActive
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _overlayDurationSeconds = value!;
                                          });
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 40),

                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isActive ? null : _startBlinkReminder,
                      icon: Icon(Icons.play_arrow),
                      label: Text('Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isActive ? _stopBlinkReminder : null,
                      icon: Icon(Icons.stop),
                      label: Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                if (_isActive)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Blink reminders active',
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Every ${_formatInterval(_intervalSeconds)}',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 20),

                // Test button
                TextButton(
                  onPressed: _showBlinkReminder,
                  child: Text('Test Reminder'),
                ),
              ],
            ),
          ),

          // Overlay for blink reminder with gradient effect
          if (_showOverlay)
            AnimatedContainer(
              duration: Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7), // Dark at top
                    Colors.black.withOpacity(0.3), // Medium in middle
                    Colors.black.withOpacity(0.1), // Light at bottom
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  children: [
                    SizedBox(height: 120),
                    // Animated main text
                    TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 400),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: Opacity(
                            opacity: value,
                            child: Text(
                              'BLINK',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    // Animated subtitle
                    TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 300),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Text(
                            'Time to blink your eyes',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final int seconds;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isEnabled;

  const _IntervalChip({
    required this.label,
    required this.seconds,
    required this.isSelected,
    required this.onTap,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isEnabled ? Colors.black : Colors.grey),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
