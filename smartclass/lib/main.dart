import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:smartclass/models/login_model.dart';
// import 'package:smartclass/models/user_model.dart';
import 'package:smartclass/screens/continueWithGoogle.dart';
import 'package:smartclass/screens/onboarding.dart';
import 'package:smartclass/screens/theme/dark_theme.dart';
import 'package:smartclass/screens/theme/light_theme.dart';
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
import 'screens/common_screen/common_dashboard.dart';
import 'dart:math';

/* late Box<UserModel> userBox;
UserModel? userModel; */

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ✅ Initialize Hive
  await Hive.initFlutter(); // (see note below about the import)
  Hive.registerAdapter(LoginModelAdapter());

  await Hive.openBox<LoginModel>('loginBox');
  // Hive.registerAdapter(UserModelAdapter());
  // userBox = await Hive.openBox<UserModel>('userBox');

  // ✅ Initialize Supabase
  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // ✅ important
    ),
  );

  runApp(const MyApp());

  // ✅ Hand-off from native splash to your Flutter UI safely
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });
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
      theme: lightTheme, // Light Mode
      darkTheme: darkTheme, // Dark Mode
      themeMode: ThemeMode.system,
      home: const SplashRedirector(),

      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/commondashboard':
            return MaterialPageRoute(builder: (_) => const CommonDashboard());

          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());

          case '/loginGoogle':
            return MaterialPageRoute(
              builder: (_) => const ContinueWithGoogle(),
            );

          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupPage());

          // ❌ DO NOT open dashboards without classId
          case '/teacher-dashboard':
            {
              final cls = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => TeacherDashboard(cls: cls),
              );
            }

          case '/student-dashboard':
            {
              final cls = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => StudentDashboard(cls: cls),
              );
            }

          case '/upload':
            {
              final cls = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => UploadMaterialPage(classId: cls['id']),
              );
            }

          case '/quiz':
            {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) =>
                    QuizPage(quizId: args['quizId'], classId: args['classId']),
              );
            }

          case '/results':
            {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => ResultPage(classId: args['classId']),
              );
            }

          case '/chatbot':
            {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (_) => ChatbotPage(classId: args['classId']),
              );
            }

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

    /* // ✅ Delay for splash
    await Future.delayed(const Duration(seconds: 3));

    // ✅ Load Hive profile
    userModel = userBox.get('profile');

    if (!mounted) return;

    // ✅ Check offline data first
    if (userModel != null && userModel!.role.isNotEmpty) {
      // final role = userModel!.role.toLowerCase();
       Navigator.pushReplacementNamed(context, '/commondashboard');
    } else {
      // ✅ Fallback to login if no local data
      Navigator.pushReplacementNamed(context, '/loginGoogle');
      // Navigator.pushReplacementNamed(context, "/onboarding");
    } */

    await Future.delayed(const Duration(seconds: 3));

    final session = supabase.auth.currentSession;

    if (!mounted) return;

    if (session != null) {
      Navigator.pushReplacementNamed(context, '/commondashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/onboarding'); //onboarding
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
