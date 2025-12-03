import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:smartclass/models/user_model.dart';
import 'package:smartclass/screens/onboarding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secrets.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/teacher_screen/teacher_dashboard.dart';
import 'screens/student_screen/student_dashboard.dart';
import 'screens/teacher_screen/upload_material_page.dart';
import 'screens/student_screen/quiz_page.dart';
import 'screens/teacher_screen/result_page.dart';
import 'screens/common_screen/chatbot_page.dart';
import 'dart:math';

late Box<UserModel> userBox;
UserModel? userModel;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(UserModelAdapter());
  userBox = await Hive.openBox<UserModel>('userBox');

  // ✅ Initialize Supabase
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
      // theme: ThemeData(primarySwatch: Colors.blue),
      theme: ThemeData(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.blue, // Cursor color
          selectionColor: Colors.blue.withOpacity(0.3), // Drag selection color
          selectionHandleColor: Colors.blue, // Handle color
        ),
      ),
      home: const SplashRedirector(),

      onGenerateRoute: (settings) {
        switch (settings.name) {
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
                  QuizPage(department: args['department'], year: args['year'],quizId: args['quizId'],),
            );
          case '/results':
            return MaterialPageRoute(builder: (_) => const ResultPage());
          case '/chatbot':
            return MaterialPageRoute(builder: (_) => const ChatbotPage());
          case '/onboarding':
            return MaterialPageRoute(builder: (_) => const OnboardingScreen());
           
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
    _initSplash();
  }

  Future<void> _initSplash() async {
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

    // ✅ Delay for splash
    await Future.delayed(const Duration(seconds: 3));

    // ✅ Load Hive profile
    userModel = userBox.get('profile');

    if (!mounted) return;

    // ✅ Check offline data first
    if (userModel != null && userModel!.role.isNotEmpty) {
      final role = userModel!.role.toLowerCase();
      if (role == 'teacher') {
        Navigator.pushReplacementNamed(context, '/teacher-dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/student-dashboard');
      }
    } else {
      // ✅ Fallback to login if no local data
      // Navigator.pushReplacementNamed(context, '/login');
      Navigator.pushReplacementNamed(context, "/onboarding");
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _glowController.dispose();
    super.dispose();
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
                final dx =
                    (p.dx * size.width +
                            sin(
                                  DateTime.now().millisecondsSinceEpoch / 800 +
                                      p.dx,
                                ) *
                                10)
                        .clamp(0, size.width);
                final dy =
                    (p.dy * size.height +
                            cos(
                                  DateTime.now().millisecondsSinceEpoch / 1000 +
                                      p.dy,
                                ) *
                                10)
                        .clamp(0, size.height);
                return Positioned(
                  left: dx.toDouble(),
                  top: dy.toDouble(),
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withAlpha(150),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withAlpha(200),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Center logo + text
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
                              color: Colors.blueAccent.withAlpha(120),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            "assets/images/icon1.png",
                            width: 184,
                            height: 184,
                            colorBlendMode: BlendMode.overlay,
                          ),
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
