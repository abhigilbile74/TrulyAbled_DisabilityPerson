import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_compass/flutter_compass.dart';

import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _searchController = TextEditingController();

  Position? _currentPosition;
  LatLng? _destination;
  List<LatLng> _routePoints = [];

  bool _isNavigating = false;
  bool _isListening = false;
  bool _mapReady = false;
  String _distanceText = "";
  String _durationText = "";
  String _nextInstruction = "Search or speak your destination";
  double _heading = 0;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
    _getCurrentLocation();
    _initCompass();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-IN");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _speak("Navigation ready. Tap mic or search for destination");
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
  }

  Future<void> _initCompass() async {
    _compassStream = FlutterCompass.events?.listen((event) {
      setState(() => _heading = event.heading ?? 0);
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _speak("Please enable location services");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) return;

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (_currentPosition != null && mounted) {
      setState(() {});

      _moveMapToCurrentLocation();
    }
  }

  Future<void> _searchDestination(String query) async {
    if (query.trim().isEmpty) return;

    await _speak("Searching for $query");

    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
    });

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'LastMinutesDeal-Flutter-App'},
      );

      if (response.statusCode != 200) {
        throw Exception('Search failed: ${response.statusCode}');
      }

      final List<dynamic> data = jsonDecode(response.body);

      if (data.isEmpty) {
        await _speak("Location not found");
        return;
      }

      final place = data.first;

      final double lat = double.parse(place['lat'].toString());

      final double lng = double.parse(place['lon'].toString());

      final String name = place['display_name'] ?? query;

      setState(() {
        _destination = LatLng(lat, lng);
      });

      if (_mapReady) {
        _mapController.move(_destination!, 15);
      }

      await _speak("Found $name. Calculating route.");

      await _getRoute();
    } catch (e) {
      debugPrint("Search Error: $e");

      await _speak("Error finding location");
    }
  }

  Future<void> _getRoute() async {
    if (_currentPosition == null || _destination == null) {
      return;
    }

    final startLat = _currentPosition!.latitude;
    final startLng = _currentPosition!.longitude;

    final endLat = _destination!.latitude;
    final endLng = _destination!.longitude;

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/walking/'
      '$startLng,$startLat;'
      '$endLng,$endLat'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Route failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (data['code'] != 'Ok' ||
          data['routes'] == null ||
          data['routes'].isEmpty) {
        await _speak("Route not found");
        return;
      }

      final route = data['routes'][0];

      final coordinates = route['geometry']['coordinates'] as List;

      final points = coordinates.map<LatLng>((point) {
        // GeoJSON is longitude, latitude
        return LatLng(
          (point[1] as num).toDouble(),
          (point[0] as num).toDouble(),
        );
      }).toList();

      final double distance = (route['distance'] as num).toDouble();

      final double duration = (route['duration'] as num).toDouble();

      setState(() {
        _routePoints = points;

        if (distance >= 1000) {
          _distanceText = '${(distance / 1000).toStringAsFixed(1)} km';
        } else {
          _distanceText = '${distance.toStringAsFixed(0)} m';
        }

        _durationText = '${(duration / 60).round()} min';
      });

      await _speak(
        "Route found. $_distanceText. "
        "About $_durationText.",
      );
    } catch (e) {
      debugPrint("Route Error: $e");

      await _speak("Error calculating route");
    }
  }

  void _startNavigation() {
    if (_destination == null) {
      _speak("Please select a destination first");
      return;
    }

    setState(() => _isNavigating = true);
    _speak("Navigation started. Follow voice instructions");
    Vibration.vibrate(duration: 500);

    // Track location updates
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          _updateNavigation(position);
        });
  }

  void _updateNavigation(Position position) {
    if (_destination == null) return;

    _currentPosition = position;
    if (mounted) {
      setState(() {});
    }

    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _destination!.latitude,
      _destination!.longitude,
    );

    // Check if arrived
    if (distance < 20) {
      _speak("You have arrived at your destination");
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
      _stopNavigation();
      return;
    }

    // Simple turn instruction based on bearing
    double bearing = Geolocator.bearingBetween(
      position.latitude,
      position.longitude,
      _destination!.latitude,
      _destination!.longitude,
    );

    double diff = (bearing - _heading).abs();
    if (diff > 180) diff = 360 - diff;

    String instruction = "";
    if (distance < 50) {
      instruction = "Destination ahead in ${distance.toInt()} meters";
    } else if (diff < 30) {
      instruction = "Continue straight for ${distance.toInt()} meters";
    } else if (bearing > _heading) {
      instruction = "Turn right and continue ${distance.toInt()} meters";
    } else {
      instruction = "Turn left and continue ${distance.toInt()} meters";
    }

    if (instruction != _nextInstruction) {
      setState(() => _nextInstruction = instruction);
      _speak(instruction);
      Vibration.vibrate(duration: 200);
    }

    // Update camera
    _moveMapToCurrentLocation();
  }

  void _moveMapToCurrentLocation() {
    if (_mapReady && _currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16,
      );
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _nextInstruction = "Navigation stopped";
    });
    _positionStream?.cancel();
    _speak("Navigation stopped");
  }

  Future<void> _startVoiceSearch() async {
    if (!_speech.isAvailable) return;

    setState(() => _isListening = true);
    Vibration.vibrate(duration: 100);
    await _speak("Where do you want to go?");

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _searchController.text = result.recognizedWords;
          _searchDestination(result.recognizedWords);
          setState(() => _isListening = false);
        }
      },
      listenFor: const Duration(seconds: 5),
    );
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    _tts.stop();
    _speech.stop();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f9ff),
      appBar: AppBar(
        backgroundColor: const Color(0xfff8f9ff),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xff15157D),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Navigation",
          style: TextStyle(
            color: Color(0xff15157D),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: const Color(0xffFFDAD6),
              child: IconButton(
                icon: const Icon(Icons.emergency),
                color: Colors.red,
                onPressed: () =>
                    _speak("Emergency button. Long press to call for help"),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Field
            TextField(
              controller: _searchController,
              onSubmitted: _searchDestination,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: "Where would you like to go?",
                prefixIcon: const Icon(Icons.search, size: 28),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 28,
                  ),
                  color: _isListening ? Colors.red : const Color(0xff15157D),
                  onPressed: _startVoiceSearch,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Map
            Stack(
              children: [
                Container(
                  height: 350,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _currentPosition == null
                        ? const Center(child: CircularProgressIndicator())
                        : FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              initialZoom: 16,
                              onMapReady: () {
                                _mapReady = true;
                                _moveMapToCurrentLocation();
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.trulyabled',
                              ),

                              PolylineLayer(
                                polylines: [
                                  if (_routePoints.isNotEmpty)
                                    Polyline(
                                      points: _routePoints,
                                      strokeWidth: 6,
                                      color: const Color(0xff15157D),
                                    ),
                                ],
                              ),

                              MarkerLayer(
                                markers: [
                                  // Current location
                                  Marker(
                                    point: LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                    ),
                                    width: 50,
                                    height: 50,
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Colors.blue,
                                      size: 35,
                                    ),
                                  ),

                                  // Destination
                                  if (_destination != null)
                                    Marker(
                                      point: _destination!,
                                      width: 50,
                                      height: 50,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                        size: 45,
                                      ),
                                    ),
                                ],
                              ),

                              RichAttributionWidget(
                                attributions: [
                                  TextSourceAttribution(
                                    'OpenStreetMap contributors',
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isNavigating ? Colors.green : Colors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isNavigating ? "Navigating" : "AI Mapping Active",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_distanceText.isNotEmpty)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff15157D),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        "$_distanceText • $_durationText",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Column(
                    children: [
                      FloatingActionButton.large(
                        backgroundColor: _isListening
                            ? Colors.red
                            : const Color(0xff15157D),
                        onPressed: _startVoiceSearch,
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff15157D),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          "Voice Nav",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Current instruction
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xffeff4ff),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xff15157D), width: 2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.volume_up,
                    color: Color(0xff15157D),
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _nextInstruction,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay),
                    onPressed: () => _speak(_nextInstruction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nearby Places
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Nearby Places",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                TextButton(onPressed: () {}, child: const Text("View All")),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  NearbyCard(
                    icon: Icons.medical_services,
                    title: "Pharmacy",
                    color: Colors.teal,
                    onTap: () => _searchDestination("Pharmacy near me"),
                  ),
                  NearbyCard(
                    icon: Icons.local_grocery_store,
                    title: "Grocery",
                    color: Colors.orange,
                    onTap: () => _searchDestination("Grocery store near me"),
                  ),
                  NearbyCard(
                    icon: Icons.directions_bus,
                    title: "Bus Stop",
                    color: Colors.indigo,
                    onTap: () => _searchDestination("Bus stop near me"),
                  ),
                  NearbyCard(
                    icon: Icons.coffee,
                    title: "Coffee",
                    color: Colors.brown,
                    onTap: () => _searchDestination("Coffee shop near me"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 70,
              child: FilledButton.icon(
                onPressed: _isNavigating ? _stopNavigation : _startNavigation,
                style: FilledButton.styleFrom(
                  backgroundColor: _isNavigating
                      ? Colors.red
                      : const Color(0xff15157D),
                ),
                icon: Icon(_isNavigating ? Icons.stop : Icons.navigation),
                label: Text(
                  _isNavigating ? "Stop Navigation" : "Start Navigation",
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xffFFDCC3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Pro Tip",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Shake your phone at any time to repeat the last navigation command. Voice commands work offline.",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class NearbyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback? onTap;

  const NearbyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: .15),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
