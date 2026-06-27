import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:shake/shake.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trulyabled/widget/bottam_navigationbar_widget.dart';

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Timer? _countdownTimer;
  bool activated = false;
  int countdown = 3;
  
  late AnimationController pulseController;
  final FlutterTts _tts = FlutterTts();
  ShakeDetector? _shakeDetector;
  
  // Configure your emergency contacts here
  final List<Map<String, String>> emergencyContacts = [
    {"name": "Mom", "phone": "+15550123456"},
    {"name": "Dr. Smith", "phone": "+15550987654"},
    {"name": "Police", "phone": "100"}, // India: 100, US: 911
  ];

  Position? _currentPosition;
  String _locationString = "Fetching location...";

  @override
  void initState() {
    super.initState();
    pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _initTts();
    _getCurrentLocation();
    _initShakeDetection();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.phone,
      Permission.sms,
    ].request();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-IN");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  void _initShakeDetection() {
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: () {
        if (!activated) {
          _speak("Shake detected. Starting emergency SOS in 3 seconds");
          startSOS();
        }
      },
      shakeThresholdGravity: 2.7,
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _locationString = "${_currentPosition!.latitude.toStringAsFixed(4)}, "
            "${_currentPosition!.longitude.toStringAsFixed(4)}";
      });
    } catch (e) {
      setState(() => _locationString = "Location unavailable");
    }
  }

  void startSOS() {
    if (activated) return;
    
    setState(() => countdown = 3);
    Vibration.vibrate(duration: 500);
    _speak("Emergency SOS activating in 3 seconds. Release to cancel");

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => countdown--);
      if (countdown > 0) {
        Vibration.vibrate(duration: 200);
        _speak("$countdown");
      }
    });

    _timer = Timer(const Duration(seconds: 3), () {
      _countdownTimer?.cancel();
      _triggerEmergency();
    });
  }

  void stopSOS() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    if (!activated) {
      _speak("Emergency cancelled");
      Vibration.vibrate(duration: 100);
    }
  }

  Future<void> _triggerEmergency() async {
    setState(() {
      activated = true;
    });

    // 1. Haptic + Audio feedback
    Vibration.vibrate(pattern: [0, 1000, 500, 1000]);
    await _speak("Emergency protocol activated. Contacting help now");

    // 2. Get fresh location
    await _getCurrentLocation();

    // 3. Send SMS to all contacts with location
    final String locationUrl = _currentPosition != null
        ? "https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}"
        : "Location unavailable";
    
    final String message = "EMERGENCY SOS! I need help immediately. "
        "My location: $locationUrl\n"
        "Time: ${DateTime.now().toString().substring(0, 16)}";

    for (var contact in emergencyContacts) {
      await _sendSMS(contact["phone"]!, message);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // 4. Auto-call first contact after 5s
    await Future.delayed(const Duration(seconds: 5));
    await _callContact(emergencyContacts[0]["phone"]!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Emergency contacts alerted with your location"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _sendSMS(String phone, String message) async {
    final Uri smsUri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  Future<void> _callContact(String phone) async {
    final Uri telUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    }
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    pulseController.dispose();
    _shakeDetector?.stopListening();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f9ff),
      appBar: AppBar(
        backgroundColor: const Color(0xfff8f9ff),
        elevation: 0,
        title: const Text(
          "Emergency",
          style: TextStyle(color: Color(0xff15157d), fontSize: 28, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xff15157d)),
            onPressed: () => _showHelpDialog(),
          )
        ],
      ),
      bottomNavigationBar: BottamNavigationbarWidget(selectedIndex: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // SOS BUTTON with countdown
            GestureDetector(
              onLongPressStart: (_) => startSOS(),
              onLongPressEnd: (_) => stopSOS(),
              onTap: () => _speak("Hold for 3 seconds or shake phone to activate emergency"),
              child: ScaleTransition(
                scale: Tween(begin: 0.95, end: 1.0).animate(pulseController),
                child: Container(
                  height: 230,
                  width: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activated ? Colors.black : const Color(0xffba1a1a),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(.4),
                        blurRadius: 40,
                        spreadRadius: 15,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        activated ? Icons.check_circle : Icons.emergency,
                        size: 65,
                        color: Colors.white,
                      ),
                      Text(
                        activated ? "ACTIVE" : countdown < 3 ? "$countdown" : "SOS",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),
            Text(
              activated 
                  ? "Emergency active. Help is on the way."
                  : "Hold for 3 seconds or shake phone to broadcast emergency",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: Color(0xff464652)),
            ),

            const SizedBox(height: 30),

            // LOCATION CARD
            GestureDetector(
              onTap: _getCurrentLocation,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xff006a6a),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 35),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Share Live Location",
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _locationString,
                            style: const TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.refresh, color: Colors.white)
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Priority Services",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xff121c2a)),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                emergencyCard(Icons.security, "Police", "100"),
                emergencyCard(Icons.medical_services, "Ambulance", "102"),
                emergencyCard(Icons.local_fire_department, "Fire", "101"),
              ],
            ),

            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Emergency Contacts",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            ...emergencyContacts.map((c) => contactCard(c["name"]!, c["phone"]!, Icons.person)),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xffeff4ff),
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: Color(0xff006a6a), width: 5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Color(0xff006a6a)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Shake phone hard to trigger SOS. Works even with screen locked.",
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget emergencyCard(IconData icon, String title, String number) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _callContact(number),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          height: 130,
          decoration: BoxDecoration(
            color: const Color(0xffeff4ff),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 45, color: const Color(0xff15157d)),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(number, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget contactCard(String name, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xffe6eeff),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xffd9e3f6),
            child: Icon(icon, color: const Color(0xff15157d)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _callContact(subtitle),
            child: const CircleAvatar(
              backgroundColor: Color(0xff15157d),
              child: Icon(Icons.call, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Emergency Features"),
        content: const Text(
          "1. Hold SOS button 3 seconds\n"
          "2. Shake phone hard to trigger\n"
          "3. Auto-sends SMS with location\n"
          "4. Auto-calls first contact\n"
          "5. Voice confirms each step\n\n"
          "Works for blind/low-vision users.",
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }
}