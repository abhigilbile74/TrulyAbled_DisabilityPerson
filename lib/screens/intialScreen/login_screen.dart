import 'package:flutter/material.dart';
import 'package:trulyabled/config/app_routes.dart';
import 'package:trulyabled/screens/home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              Image.asset("assets/images/screen.png", height: 220),

              const SizedBox(height: 30),

              const Text(
                "Welcome to TrulyAbled",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const Text(
                "Sign in to personalize your accessibility experience.",
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.login),
                  label: const Text("Continue with Google"),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.apple),
                  label: const Text("Continue with Apple"),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text("Login with Email"),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
  onPressed: () {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.home,
    );
  },
  child: const Text("Skip for now"),
),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
