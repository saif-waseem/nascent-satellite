import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const OnboardingOverlay({super.key, required this.onDismiss});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  int _step = 0;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: 'أهلاً بك في تجربتك الفاخرة',
      subtitle: 'استكشف منتجاتنا بلمسة عصرية وانتقالات سلسة.',
      icon: Icons.auto_awesome,
      position: Alignment.center,
    ),
    OnboardingStep(
      title: 'نظام النقاط الذكي',
      subtitle: 'اجمع النقاط مع كل عملية شراء واستبدلها بخصومات حقيقية.',
      icon: Icons.stars_rounded,
      position: Alignment.bottomCenter,
    ),
    OnboardingStep(
      title: 'شارك واكسب',
      subtitle: 'ادعُ أصدقاءك وسجل نقاط إضافية فور انضمامهم.',
      icon: Icons.share_rounded,
      position: Alignment.topRight,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_step >= _steps.length) return const SizedBox.shrink();

    final current = _steps[_step];

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(current.icon, color: Colors.amber, size: 80),
                  ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).shimmer(delay: 1.seconds),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      current.title,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      current.subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 200,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () {
                        if (_step < _steps.length - 1) {
                          setState(() => _step++);
                        } else {
                          widget.onDismiss();
                        }
                      },
                      child: Text(_step == _steps.length - 1 ? 'ابدأ الاستمتاع' : 'التالي'),
                    ),
                  ).animate().fadeIn(delay: 600.ms).scale(),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _step == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _step == index ? Colors.amber : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final Alignment position;

  OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.position = Alignment.center,
  });
}
