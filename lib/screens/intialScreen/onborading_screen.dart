import 'package:flutter/material.dart';
import 'package:trulyabled/config/app_constant.dart';
import 'package:trulyabled/config/app_routes.dart';
import 'package:trulyabled/screens/intialScreen/login_screen.dart';
import 'package:trulyabled/widget/onborading_page_widget.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;

  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> nextPage() async {
    if (currentPage < 2) {
      setState(() {
        currentPage++;
      });

      await _pageController.animateToPage(
        currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text(AppConstant.appName),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                OnboardingPage(
                  image: "assets/images/image1.png",
                  title: "Mobility for All",
                  subtitle: "Navigate your world with confidence and ease.",
                ),
                OnboardingPage(
                  image: "assets/images/image2.png",
                  title: "Clear Vision, Clear Path",
                  subtitle:
                      "Assistive tools designed for your daily journey.",
                ),
                OnboardingPage(
                  image: "assets/images/image3.png",
                  title: "You're Ready!",
                  subtitle:
                      "Let's personalize your accessibility experience.",
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text("Step ${currentPage + 1} of 3"),

                const SizedBox(height: 10),

                LinearProgressIndicator(
                  value: (currentPage + 1) / 3,
                  minHeight: 8,
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: nextPage,
                    child: Text(
                      currentPage == 2 ? "Get Started" : "Next",
                    ),
                  ),
                ),
                const SizedBox(height: 15,),
               SizedBox(
  width: MediaQuery.of(context).size.width*0.4,
  height: 25,
  child: ElevatedButton(
    onPressed: () {
      Navigator.pushNamed(context, AppRoutes.login);
    },
    child: const Text("Skip"),
  ),
),
              ],
            ),
          ),
        ],
      ),
    );
  }
}