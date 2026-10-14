
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shake/shake.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen>
    with WidgetsBindingObserver {
  static const List<Map<String, String>> emergencyContacts = [
    {
      'name': 'Emergency Contact 1',
      'phone': '+919022787593',
    },
    {
      'name': 'Emergency Contact 2',
      'phone': '+917499723141',
    },
  ];

  Timer? _countdownTimer;
  ShakeDetector? _shakeDetector;
  final FlutterTts _tts = FlutterTts();

  int _countdown = 5;
  bool _countdownActive = false;
  bool _sosActivated = false;
  bool _working = false;
  bool _shakeEnabled = true;

  Position? _currentPosition;
  String _status = 'Your safety matters. Help is one tap away.';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTts();

    // Phone shake detection is intended for a real Android/iOS device.
    // It cannot work as a phone sensor on Flutter Web.
    if (!kIsWeb) {
      _startShakeDetection();
    }
  }

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
    } catch (_) {
      // Voice announcements are optional.
    }
  }

  void _startShakeDetection() {
    try {
      _shakeDetector?.stopListening();

      _shakeDetector = ShakeDetector.autoStart(
        onPhoneShake: (event) {
          if (!mounted ||
              !_shakeEnabled ||
              _countdownActive ||
              _sosActivated ||
              _working) {
            return;
          }

          _startSOS(source: 'Phone shake detected');
        },
        shakeThresholdGravity: 2.7,
        shakeSlopTimeMS: 500,
        shakeCountResetTime: 3000,
        minimumShakeCount: 2,
        useFilter: false,
      );
    } catch (e) {
      debugPrint('Shake detector error: $e');
    }
  }

  void _startSOS({String source = 'SOS button pressed'}) {
    if (_countdownActive || _sosActivated || _working) return;

    HapticFeedback.heavyImpact();

    setState(() {
      _countdownActive = true;
      _countdown = 5;
      _error = null;
      _status = '$source. SOS will activate shortly.';
    });

    _announce('Emergency SOS countdown started. Shake or press cancel to stop.');

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_countdown <= 1) {
          timer.cancel();

          setState(() {
            _countdown = 0;
            _countdownActive = false;
            _sosActivated = true;
          });

          _triggerEmergency();
        } else {
          setState(() {
            _countdown--;
          });

          if (_countdown <= 3) {
            HapticFeedback.mediumImpact();
          }
        }
      },
    );
  }

  void _cancelSOS() {
    if (!_countdownActive) return;

    _countdownTimer?.cancel();

    setState(() {
      _countdownActive = false;
      _countdown = 5;
      _status = 'SOS cancelled.';
      _error = null;
    });

    _announce('Emergency SOS cancelled.');
  }

  Future<void> _triggerEmergency() async {
    if (_working) return;

    setState(() {
      _working = true;
      _status = 'SOS activated. Getting your location...';
      _error = null;
    });

    try {
      if (!kIsWeb) {
        try {
          final hasVibrator = await Vibration.hasVibrator() ?? false;
          if (hasVibrator) {
            await Vibration.vibrate(
              pattern: [0, 500, 250, 500, 250, 800],
            );
          }
        } catch (_) {
          // Continue even if vibration is unavailable.
        }
      }

      await _announce('Emergency SOS activated. Getting your location.');

      final position = await _getCurrentLocation();

      if (!mounted) return;

      _currentPosition = position;

      final locationText = position == null
          ? 'Location unavailable. Please call me for help.'
          : 'My location: '
              'https://www.google.com/maps/search/?api=1'
              '&query=${position.latitude},${position.longitude}';

      final timestamp = DateTime.now().toLocal().toString().split('.').first;

      final message = 'EMERGENCY SOS!\n'
          'I may need immediate help.\n'
          '$locationText\n'
          'Time: $timestamp\n'
          'Please try to contact me or call emergency services.';

      setState(() {
        _status = position == null
            ? 'SOS activated, but GPS location could not be retrieved.'
            : 'SOS activated. Your current location is ready to share.';
      });

      // On a real phone this opens the messaging app with the message
      // prepared. The user must review and press Send.
      await _openSmsComposer(message);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not prepare the SOS alert: $e';
        _status = 'SOS activated, but the alert could not be prepared.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _error = 'Turn on Location/GPS and try again.';
          });
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _error = 'Location permission is required to share GPS coordinates.';
          });
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  Future<void> _openSmsComposer(String message) async {
    final recipients = emergencyContacts
        .map((contact) => contact['phone']!)
        .join(',');

    final smsUri = Uri(
      scheme: 'sms',
      path: recipients,
      queryParameters: {'body': message},
    );

    try {
      final launched = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (launched) {
        setState(() {
          _status =
              'SMS app opened. Verify both recipients and press Send to alert them.';
        });

        _showMessage(
          'SMS opened. Confirm both contact numbers and press Send.',
        );
      } else {
        setState(() {
          _error =
              'Could not open the SMS app. Use the location and call buttons below.';
          _status = 'SOS activated. SMS was not sent.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not open the SMS app. Please call 112 if needed.';
        _status = 'SOS activated. SMS was not sent.';
      });

      debugPrint('SMS launch error: $e');
    }
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage('Could not open the phone dialer.');
      }
    } catch (e) {
      if (mounted) _showMessage('Calling is unavailable on this device.');
      debugPrint('Call error: $e');
    }
  }

  Future<void> _shareLocation() async {
    setState(() {
      _working = true;
      _error = null;
      _status = 'Getting your current GPS location...';
    });

    final position = await _getCurrentLocation();

    if (!mounted) return;

    setState(() {
      _working = false;
      _currentPosition = position;
      _status = position == null
          ? 'Location unavailable. Check GPS and location permissions.'
          : 'Current GPS location retrieved.';
    });

    if (position == null) {
      _showMessage('Could not get GPS location. Check the error message.');
      return;
    }

    final mapsUrl = 'https://www.google.com/maps/search/?api=1'
        '&query=${position.latitude},${position.longitude}';

    await Clipboard.setData(ClipboardData(text: mapsUrl));

    if (!mounted) return;

    _showMessage('Location link copied. Paste it into a message to share.');
  }

  Future<void> _announce(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // TTS is optional.
    }
  }

  void _resetSOS() {
    _countdownTimer?.cancel();

    setState(() {
      _countdownActive = false;
      _sosActivated = false;
      _working = false;
      _countdown = 5;
      _status = 'Your safety matters. Help is one tap away.';
      _error = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Shake detection is not guaranteed to run while the app is backgrounded
    // or the phone is locked. This screen does not claim otherwise.
    if (state == AppLifecycleState.resumed &&
        !kIsWeb &&
        _shakeDetector == null) {
      _startShakeDetection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _shakeDetector?.stopListening();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Call emergency services',
            onPressed: () => _callNumber('112'),
            icon: const Icon(Icons.call),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.red.withValues(alpha: 0.14)
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.health_and_safety,
                    color: Colors.red,
                    size: 46,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Emergency Assistance',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            Center(
              child: GestureDetector(
                onLongPress: () {
                  if (!_countdownActive && !_sosActivated && !_working) {
                    _startSOS(source: 'SOS button long-pressed');
                  }
                },
                child: InkWell(
                  onTap: () {
                    if (_countdownActive) {
                      _cancelSOS();
                    } else if (!_sosActivated && !_working) {
                      _startSOS();
                    }
                  },
                  customBorder: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      color: _countdownActive
                          ? Colors.orange
                          : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.25),
                          blurRadius: 25,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _working
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _countdownActive
                                      ? Icons.close
                                      : Icons.sos,
                                  color: Colors.white,
                                  size: 54,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _countdownActive
                                      ? 'CANCEL ($_countdown)'
                                      : _sosActivated
                                          ? 'SOS ACTIVE'
                                          : 'SOS',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!_countdownActive && !_sosActivated)
                                  const Text(
                                    'Tap to start',
                                    style: TextStyle(color: Colors.white),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              _countdownActive
                  ? 'Tap the SOS circle to cancel the countdown.'
                  : 'Tap SOS to start a 5-second countdown. '
                      'Long-press also starts the countdown.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            _actionTile(
              icon: Icons.call,
              title: 'Call Emergency Services',
              subtitle: 'Dial India emergency number 112',
              color: Colors.red,
              onTap: () => _callNumber('112'),
            ),
            const SizedBox(height: 12),

            _actionTile(
              icon: Icons.location_on,
              title: 'Get My Location',
              subtitle: _currentPosition == null
                  ? 'Retrieve GPS coordinates and copy the Maps link'
                  : '${_currentPosition!.latitude.toStringAsFixed(5)}, '
                      '${_currentPosition!.longitude.toStringAsFixed(5)}',
              color: Colors.blue,
              onTap: _working ? null : _shareLocation,
            ),
            const SizedBox(height: 12),

            _actionTile(
              icon: Icons.message,
              title: 'Alert Emergency Contacts',
              subtitle: 'Prepare an SMS containing your location',
              color: Colors.deepOrange,
              onTap: _working
                  ? null
                  : () async {
                      final position = await _getCurrentLocation();
                      if (!mounted) return;

                      final locationText = position == null
                          ? 'Location unavailable.'
                          : 'My location: https://www.google.com/maps/search/'
                              '?api=1&query=${position.latitude},'
                              '${position.longitude}';

                      final message = 'EMERGENCY SOS!\n'
                          'I need help.\n$locationText\n'
                          'Please contact me immediately.';

                      await _openSmsComposer(message);
                    },
            ),
            const SizedBox(height: 20),

            const Text(
              'Emergency contacts',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),

            for (final contact in emergencyContacts)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(contact['name']!),
                  subtitle: Text(contact['phone']!),
                  trailing: IconButton(
                    tooltip: 'Call contact',
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () => _callNumber(contact['phone']!),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            SwitchListTile(
              value: _shakeEnabled,
              onChanged: (value) {
                setState(() {
                  _shakeEnabled = value;
                });

                if (value && !kIsWeb) {
                  _startShakeDetection();
                } else {
                  _shakeDetector?.stopListening();
                  _shakeDetector = null;
                }
              },
              title: const Text('Activate SOS by shaking phone'),
              subtitle: Text(
                kIsWeb
                    ? 'Phone shake detection requires a real mobile device.'
                    : 'Shake detection works while this screen is active.',
              ),
              secondary: const Icon(Icons.vibration),
            ),

            if (_sosActivated || _countdownActive) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _countdownActive ? _cancelSOS : _resetSOS,
                icon: const Icon(Icons.refresh),
                label: Text(
                  _countdownActive ? 'Cancel SOS' : 'Reset SOS screen',
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Text(
              'Important: SMS may require you to press Send. '
              'Check that the messaging app includes both contacts. '
              'Shake detection may stop when the app is backgrounded '
              'or the phone is locked. Test this feature safely before '
              'relying on it in an emergency.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
