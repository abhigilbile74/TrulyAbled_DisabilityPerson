import 'package:flutter/material.dart';
import '../config/app_routes.dart';

class BottamNavigationbarWidget extends StatelessWidget {
  final int selectedIndex;

  const BottamNavigationbarWidget({
    super.key,
    required this.selectedIndex,
  });

  void _navigate(BuildContext context, int index) {
    if (index == selectedIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.home,
        );
        break;

      case 1:
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.camera,
        );
        break;

      case 2:
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.sos,
        );
        break;

      case 3:
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.profile,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1976D2);
    const Color lightBlue = Color(0xFFE3F2FD);
    const Color indicatorBlue = Color(0xFF90CAF9);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: lightBlue,
            indicatorColor: indicatorBlue.withValues(alpha: 0.35),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(
                    color: primaryBlue,
                    size: 28,
                  );
                }
                return const IconThemeData(
                  color: Colors.grey,
                  size: 24,
                );
              },
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) {
                return TextStyle(
                  color: states.contains(WidgetState.selected)
                      ? primaryBlue
                      : Colors.grey.shade700,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: 12,
                );
              },
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            height: 72,
            elevation: 0,
            labelBehavior:
                NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              _navigate(context, index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.camera_alt_outlined),
                label: 'Camera',
              ),
              NavigationDestination(
                icon: Icon(Icons.emergency_share_outlined),
                label: 'SOS',
              ),
              
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}