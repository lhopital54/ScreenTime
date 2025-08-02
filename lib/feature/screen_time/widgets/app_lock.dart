// features/screen_time/widgets/app_lock.dart
import 'package:flutter/material.dart';

class AppLock extends StatelessWidget {
  final bool isAppLocked;
  final VoidCallback onToggle;

  const AppLock({
    Key? key,
    required this.isAppLocked,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Lock apps',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isAppLocked ? Colors.red[400] : Colors.green[400],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isAppLocked ? Colors.red : Colors.green)
                        .withValues(alpha: 0.3),
                    spreadRadius: 3,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                isAppLocked ? Icons.lock : Icons.lock_open,
                color: Colors.white,
                size: 35,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}