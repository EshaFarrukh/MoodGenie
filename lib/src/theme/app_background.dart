import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0F9FF), // Sky 50 (Very light blue, calming tech vibe)
            Color(0xFFE0F2FE), // Sky 100 (Slightly deeper clear oceanic shade)
          ],
        ),
      ),
    );
  }
}
