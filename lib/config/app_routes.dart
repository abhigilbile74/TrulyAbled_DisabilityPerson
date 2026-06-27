import 'package:flutter/material.dart';
import 'package:trulyabled/screens/currency_recognition_screen.dart';
import 'package:trulyabled/screens/emergency_sos_screen.dart';
import 'package:trulyabled/screens/home_screen.dart';
import 'package:trulyabled/screens/intialScreen/login_screen.dart';
import 'package:trulyabled/screens/intialScreen/onborading_screen.dart';
import 'package:trulyabled/screens/intialScreen/splash_screen.dart';
import 'package:trulyabled/screens/live_detection_screen.dart';
import 'package:trulyabled/screens/navigation_screen.dart';
import 'package:trulyabled/screens/ocr_reader_screen.dart';
import 'package:trulyabled/screens/voice_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forget';
  static const home = '/home';
  static const camera = '/camera';
  static const voice = '/voice';
  static const history = '/history';
  static const profile = '/profile';
  static const sos = '/sos';
  static const ocrReader = '/ocrreader';
  static const currencyercognition = '/currencyrecognition';
  static const stt = '/stt';
  static const navigation_map = '/navigation_map';

  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    onboarding: (_) => const OnboardingScreen(),
    login: (_) => LoginScreen(),
    // signup: (_) => SignupScreen(),
    // forgotPassword: (_) => const ForgotPasswordScreen(),
    home: (_) => HomeScreen(),
    camera: (_) => LiveDetectionScreen(),
    sos: (_) => EmergencySosScreen(),
    ocrReader: (_) => OCRReaderScreen(),
    currencyercognition: (_) => CurrencyRecognitionScreen(),
    stt: (_) => SpeechToTextScreen(),
    navigation_map: (_)=> NavigationScreen(),
  };
}
