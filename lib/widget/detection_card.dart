import 'package:flutter/material.dart';

class DetectionCard extends StatelessWidget {
  final String object;

  const DetectionCard({
    super.key,
    required this.object,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.blue,
      child: Column(
        children: [
          const Text(
            "Detected Object",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            object,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}