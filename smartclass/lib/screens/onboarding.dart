import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:smartclass/screens/continueWithGoogle.dart';
import 'package:smartclass/screens/login_page.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onFinished});

  /// Called when the user taps "Get started".
  final VoidCallback? onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;


  static const _curve = Curves.easeOutCubic;
  static final _slideTween = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  );
  void replaceWithAnimation(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: _curve);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: _slideTween.animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  final pages = <_OnboardPageData>[
    _OnboardPageData(
      title: 'Upload Materials Effortlessly',
      subtitle:
          'Teachers can upload PDFs and notes. We handle extraction, organization, and delivery to students automatically.',
      lottieAsset: 'assets/animations/upload.json',
      gradient: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    ),
    _OnboardPageData(
      title: 'Ask Our AI Tutor',
      subtitle:
          'Get instant answers, step-by-step explanations, and practice questions tailored to your class.',
      lottieAsset: 'assets/animations/AI.json',
      gradient: const [Color(0xFF06B6D4), Color(0xFF3B82F6)], // teal → blue
    ),
    _OnboardPageData(
      title: 'Auto‑Generate Quizzes',
      subtitle:
          'AI turns lesson content into quizzes in seconds. Save time and keep students engaged.',
      lottieAsset: 'assets/animations/quiz.json',
      gradient: const [
        Color.fromARGB(255, 83, 22, 225),
        Color.fromARGB(255, 49, 9, 171),
      ],
    ),
    _OnboardPageData(
      title: 'Track Progress Instantly',
      subtitle:
          'View performance analytics, quiz results, and learning patterns with powerful insights.',
      lottieAsset: 'assets/animations/analytics.json',
      gradient: const [
        Color.fromARGB(255, 21, 51, 246),
        Color.fromARGB(255, 52, 100, 211),
      ],
    ),
  ];

  @override
  void initState() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.initState();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (widget.onFinished != null) {
      widget.onFinished!();
    } else {
      // Default action: replace with your route
      replaceWithAnimation(context, const ContinueWithGoogle());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == pages.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: pages[_index].gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top action row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // App logo / name
                    Row(
                      children: [
                        const _AppBadge(),
                        const SizedBox(width: 8),
                        Text(
                          'TechClass',
                          style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _finish,
                      child:  Text(
                        'Skip',
                        style: TextStyle(color: Theme.of(context).textTheme.titleMedium?.color),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Pages (responsive — no fixed height)
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _OnboardSlide(data: pages[i]),
                ),
              ),

              const SizedBox(height: 16),

              // Dots indicator
              SmoothPageIndicator(
                controller: _controller,
                count: pages.length,
                effect: ExpandingDotsEffect(
                  dotColor: Theme.of(context).cardColor.withAlpha((0.4 * 255).toInt()),
                  activeDotColor: Theme.of(context).cardColor,
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 4,
                  spacing: 8,
                ),
              ),

              const SizedBox(height: 16),

              // Bottom controls
              Padding(
                
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(
                  children: [
                    // Prev
                    _RoundIconButton(
                      icon:  Icons.chevron_left_rounded,
                      onTap: _index == 0
                          ? null
                          : () => _controller.previousPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOut,
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Next / Get started
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).cardColor,
                          foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: isLast
                            ? _finish
                            : () => _controller.nextPage(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOut,
                              ),
                        child: Text(isLast ? 'Get started' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardSlide extends StatelessWidget {
  const _OnboardSlide({required this.data});

  final _OnboardPageData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Card container
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(  context).cardColor,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.08 * 255).toInt()),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Illustration (kept within aspect ratio and responsive)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: AspectRatio(
                            aspectRatio: 1.2,
                            child: _SafeLottie(
                              url: data.lottieUrl,
                              asset: data.lottieAsset,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title
                        Text(
                          data.title,
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Subtitle
                        Text(
                          data.subtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            // color: const Color(0xFF334155),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SafeLottie extends StatelessWidget {
  const _SafeLottie({this.url, this.asset});
  final String? url;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => const Center(
      child: Icon(Icons.school_rounded, size: 96, color: Color(0xFF94A3B8)),
    );

    if (url != null && url!.isNotEmpty) {
      return Lottie.network(
        url!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => fallback(),
      );
    }
    if (asset != null && asset!.isNotEmpty) {
      return Lottie.asset(
        asset!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => fallback(),
      );
    }
    return fallback();
  }
}

class _OnboardPageData {
  final String title;
  final String subtitle;
  final String? lottieUrl;
  final String? lottieAsset;
  final List<Color> gradient;
  const _OnboardPageData({
    required this.title,
    required this.subtitle,
    this.lottieUrl,
    this.lottieAsset,
    required this.gradient,
  });
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: Theme.of(  context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.08 * 255).toInt()),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: Theme.of(  context).textTheme.titleLarge?.color),
        ),
      ),
    );
  }
}

class _AppBadge extends StatelessWidget {
  const _AppBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 40,
      padding: const EdgeInsets.only(bottom: 2.5),
      child: Image.asset(
        'assets/images/icon1.png',
        scale: 1.5,
        color: Theme.of(context).cardColor,
      ),
    );
  }
}
