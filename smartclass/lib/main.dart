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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Classroom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),
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

class SplashRedirector extends StatefulWidget {
  const SplashRedirector({super.key});

  @override
  State<SplashRedirector> createState() => _SplashRedirectorState();
}

class _SplashRedirectorState extends State<SplashRedirector> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  void checkAuth() async {
    final session = supabase.auth.currentSession;

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
    } else {
      final user = session.user;
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      final role = profile['role'];

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (role == 'teacher') {
          Navigator.pushReplacementNamed(context, '/teacher-dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/student-dashboard');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
