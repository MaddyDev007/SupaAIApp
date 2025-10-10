import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secrets.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/teacher_dashboard.dart';
import 'screens/student_dashboard.dart';
import 'screens/upload_material_page.dart';
import 'screens/quiz_page.dart';
import 'screens/result_page.dart';
import 'screens/chatbot_page.dart';
import 'screens/profile_page.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
  );

  runApp(const MyApp());
}
class SplashRedirector extends StatefulWidget {
  const SplashRedirector({super.key});

  @override
  State<SplashRedirector> createState() => _SplashRedirectorState();
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Classroom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashRedirector(),

      // Dynamic route handling to pass arguments to QuizPage
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfilePage());

          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupPage());
          case '/teacher-dashboard':
            return MaterialPageRoute(builder: (_) => const TeacherDashboard());
          case '/student-dashboard':
            return MaterialPageRoute(builder: (_) => const StudentDashboard());
          case '/upload':
            return MaterialPageRoute(
              builder: (_) => const UploadMaterialPage(),
            );
          case '/quiz':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) =>
                  QuizPage(department: args['department'], year: args['year']),
            );
          case '/results':
            return MaterialPageRoute(builder: (_) => const ResultPage());
          case '/chatbot':
            return MaterialPageRoute(builder: (_) => const ChatbotPage());
          default:
            return null;
        }
      },
    );
  }
}

class _SplashRedirectorState extends State<SplashRedirector>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final Random _random = Random();

  late AnimationController _fadeController;
  late AnimationController _glowController;
  late List<Offset> _particles;

  @override
  void initState() {
    super.initState();

    _particles = List.generate(
      25,
      (_) => Offset(_random.nextDouble(), _random.nextDouble()),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Start authentication check
    checkAuth();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> checkAuth() async {
    await Future.delayed(const Duration(seconds: 4));
    final session = supabase.auth.currentSession;

    if (!mounted) return;

    if (session == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final user = session.user;
    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;
    final role = profile?['role'];
    if (role == 'teacher') {
      Navigator.pushReplacementNamed(context, '/teacher-dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/student-dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF001B3A),
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return Stack(
            children: [
              // Floating neon particles
              ..._particles.map((p) {
                final dx = (p.dx * size.width +
                        sin(DateTime.now().millisecondsSinceEpoch / 800 + p.dx) *
                            10)
                    .clamp(0, size.width);
                final dy = (p.dy * size.height +
                        cos(DateTime.now().millisecondsSinceEpoch / 1000 + p.dy) *
                            10)
                    .clamp(0, size.height);
                return Positioned(
                  left: dx.toDouble(),
                  top: dy.toDouble(),
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withAlpha((0.6 * 255).toInt()),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withAlpha((0.8 * 255).toInt()),
                          blurRadius: 6,
                        )
                      ],
                    ),
                  ),
                );
              }),

              // Center logo + glow animation
              Center(
                child: FadeTransition(
                    opacity: _fadeController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFF00B4FF), Color(0xFF003C8F)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withAlpha((0.5 * 255).toInt()),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lightbulb_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                            // child: Image(
                            //   image: AssetImage('./assets/images/icon1.png'),
                            //   fit: BoxFit.cover,
                            // ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "TechClass",
                          style: TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.lightBlueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
            ],
          );
        },
      ),
    );
  }
}
