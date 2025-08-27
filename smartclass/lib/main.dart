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

  late AnimationController _bookController;
  late AnimationController _capController;
  late Animation<double> _capAnimation;
  final Random _random = Random();

  final List<Offset> _particles = List.generate(20, (index) => Offset(0, 0));

  @override
  void initState() {
    super.initState();

    // Flying books animation
    _bookController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Bouncing graduation cap
    _capController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _capAnimation = CurvedAnimation(
      parent: _capController,
      curve: Curves.easeInOut,
    );

    // Start auth check after splash animation
    checkAuth();
  }

  @override
  void dispose() {
    _bookController.dispose();
    _capController.dispose();
    super.dispose();
  }

  void checkAuth() async {
    await Future.delayed(const Duration(seconds: 4)); // splash effect duration

    final session = supabase.auth.currentSession;

    if (session == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      final user = session.user;
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      final role = profile['role'];

      if (!mounted) return;
      if (role == 'teacher') {
        Navigator.pushReplacementNamed(context, '/teacher-dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/student-dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade700,
      body: Stack(
        children: [
          // Particle background
          ..._particles.map((particle) {
            final dx = _random.nextDouble() * MediaQuery.of(context).size.width;
            final dy = _random.nextDouble() * MediaQuery.of(context).size.height;
            return Positioned(
              left: dx,
              top: dy,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.amberAccent,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated flying books
                AnimatedBuilder(
                  animation: _bookController,
                  builder: (context, child) {
                    double t = _bookController.value;
                    double x = 100 * sin(2 * pi * t);
                    double y = 50 * cos(2 * pi * t);
                    return Transform.translate(
                      offset: Offset(x, y),
                      child: const Icon(
                        Icons.book,
                        size: 60,
                        color: Colors.orangeAccent,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // App name
                const Text(
                  'Student Smart Class',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 20),

                // Bouncing graduation cap
                ScaleTransition(
                  scale: _capAnimation,
                  child: const Icon(
                    Icons.school_outlined,
                    color: Colors.amberAccent,
                    size: 60,
                  ),
                ),

                const SizedBox(height: 30),

                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
