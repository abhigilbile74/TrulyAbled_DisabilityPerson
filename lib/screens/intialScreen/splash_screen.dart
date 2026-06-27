import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trulyabled/config/app_constant.dart';
import 'package:trulyabled/screens/intialScreen/onborading_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Example navigation after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const OnboardingScreen(),
    ),
  );
});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FF), Color(0xFFEFF4FF)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  const Spacer(),

                  // Logo
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Image.asset(
                      "assets/images/screen.png",
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Title
                  Text(
                    AppConstant.appName,
                    style: GoogleFonts.atkinsonHyperlegible(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "Helping everyone live independently",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF464652),
                        height: 1.5,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Loader
                  const SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: Color(0xFF4F46E5),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
