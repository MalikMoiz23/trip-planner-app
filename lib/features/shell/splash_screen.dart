import 'package:flutter/material.dart';

import 'package:trip_planner/core/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.error, this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = error != null;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryDark, context.palette.primary],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The mark rather than the full lockup: its wordmark is set in
                // dark navy, which would disappear against this gradient. The
                // name is typed alongside it instead, in the app's own face.
                Image.asset(
                  'assets/brand/mark.png',
                  height: 108,
                  filterQuality: FilterQuality.medium,
                  // A missing asset should not be a black screen on first launch.
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.landscape_rounded,
                    color: Colors.white,
                    size: 62,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Triplyst',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PLAN SMART. TRAVEL BETTER.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Pick a place, set the days and the people, and get the whole cost '
                  'broken down before you leave the house.',
                  style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 34),
                if (failed) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: AppRadius.md,
                    ),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                    ),
                    child: const Text('Try again'),
                  ),
                ] else
                  const Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading destinations',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
