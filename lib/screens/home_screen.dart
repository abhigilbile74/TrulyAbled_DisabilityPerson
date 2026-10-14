import 'package:flutter/material.dart';
import '../config/app_constant.dart';
import 'package:trulyabled/widget/bottam_navigationbar_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, dynamic>> quickActions = const [
    {"title": "Scan Text", "icon": Icons.document_scanner},
    {"title": "Voice", "icon": Icons.mic},
    {"title": "SOS", "icon": Icons.emergency},
    {"title": "Navigate", "icon": Icons.navigation},
  ];

  final List<Map<String, dynamic>> services = const [
    {"title": "OCR Reader", "icon": Icons.menu_book},
    {"title": "Object Detection", "icon": Icons.visibility},
    {"title": "Currency", "icon": Icons.currency_rupee},
    {"title": "Text to Speech", "icon": Icons.record_voice_over},
    {"title": "Speech to Text", "icon": Icons.keyboard_voice},
    {"title": "Medicine Reminder", "icon": Icons.medication},
    {"title": "Emergency Call", "icon": Icons.call},
  ];

  /// Centralized Navigation Router Method
  void _handleNavigation(BuildContext context, String title) {
    switch (title) {
      // Quick Actions Mapping
      case "Scan Text":
      case "OCR Reader":
        Navigator.pushNamed(context, '/ocrreader');
        break;
      case "Voice":
      case "Speech to Text":
        Navigator.pushNamed(context, '/stt');
        break;
      case "SOS":
      case "Emergency Call":
        Navigator.pushNamed(context, '/sos');
        break;
      case "Navigate":
        Navigator.pushNamed(context, '/navigation_map');
        break;

      // Rest of the Services Mapping
      case "Object Detection":
        Navigator.pushNamed(context, '/camera');
        break;
      case "Currency":
        Navigator.pushNamed(context, '/currencyrecognition');
        break;
      case "Text to Speech":
        Navigator.pushNamed(context, '/tts');
        break;
      case "Medicine Reminder":
        Navigator.pushNamed(context, '/reminder');
        break;
      default:
        // Optional Fallback
        debugPrint("No route registered for: $title");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          AppConstant.appName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Icon(Icons.notifications_none, color: Colors.black),
          SizedBox(width: 15),
          CircleAvatar(
            backgroundColor: Color(0xff004AC6),
            child: Icon(Icons.person, color: Colors.white),
          ),
          SizedBox(width: 15),
        ],
      ),
      bottomNavigationBar: const BottamNavigationbarWidget(selectedIndex: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Greeting Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff004AC6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      color: Color(0xff004AC6),
                      size: 35,
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Good Morning 👋",
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Welcome Back",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SearchBar(
              hintText: "Search accessibility features...",
              leading: Icon(Icons.search),
            ),
            const SizedBox(height: 25),

            // Quick Actions Section
            const Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172B4D),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 20),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: quickActions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                mainAxisExtent: 175,
              ),
              itemBuilder: (context, index) {
                final item = quickActions[index];

                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFF3F7FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE2EAFB),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF004AC6).withOpacity(0.09),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _handleNavigation(context, item["title"]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 16,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF004AC6),
                                    Color(0xFF4285F4),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF004AC6,
                                    ).withOpacity(0.22),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                item["icon"],
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item["title"].toString(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF172B4D),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),
            const Text(
              "Accessibility Services",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            /// ListView for Accessibility Services
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final item = services[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(item["icon"], color: const Color(0xff004AC6)),
                    ),
                    title: Text(item["title"]),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _handleNavigation(
                      context,
                      item["title"],
                    ), // Dynamic logic here too
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            /// Bottom AI Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(
                        Icons.smart_toy,
                        color: Color(0xff004AC6),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AI Assistant",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text("Tap the microphone to ask for help anytime."),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _handleNavigation(
                        context,
                        "Voice",
                      ), // Routes to Speech screen
                      icon: const Icon(Icons.mic),
                      label: const Text("Speak"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}
