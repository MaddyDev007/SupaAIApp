import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:smartclass/models/login_model.dart';
// import 'package:smartclass/models/user_model.dart';
import 'package:smartclass/screens/continueWithGoogle.dart';
import 'package:smartclass/screens/onboarding.dart';
import 'package:smartclass/screens/theme/dark_theme.dart';
import 'package:smartclass/screens/theme/light_theme.dart';
import 'package:smartclass/screens/theme/theme_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secrets.dart';
import 'screens/teacher_screen/teacher_dashboard.dart';
import 'screens/student_screen/student_dashboard.dart';
import 'screens/teacher_screen/upload_material_page.dart';
import 'screens/student_screen/quiz_page.dart';
import 'screens/teacher_screen/result_page.dart';
import 'screens/common_screen/chatbot_page.dart';
import 'screens/common_screen/common_dashboard.dart';

/* late Box<UserModel> userBox;
UserModel? userModel; */
// The notifier is initialized with a safe default and loaded from Hive
// only after Hive has been initialized in main().
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.system);

// Keep one stable Navigator key while MaterialApp rebuilds for theme changes.
// This preserves the current route stack when the user changes appearance.
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Hive.initFlutter();
  Hive.registerAdapter(LoginModelAdapter());
  await Hive.openBox<LoginModel>('loginBox');
  await ThemeService.init();

  // Load the saved theme only after the Hive box is ready.
  themeModeNotifier.value = ThemeService.loadTheme();

  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Supabase initialization restores the persisted session before runApp.
  final initialSession = Supabase.instance.client.auth.currentSession;
  final initialHome = initialSession != null
      ? const CommonDashboard()
      : const OnboardingScreen();

  runApp(MyApp(initialHome: initialHome));

  // The native splash is shown only while real startup work is running.
  // Remove it after Flutter has rendered the first ready screen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.initialHome});

  final Widget initialHome;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, child) {
        return MaterialApp(
          // This key remains identical across theme updates, so the Navigator
          // and its current route stack are retained.
          navigatorKey: appNavigatorKey,
          title: 'Smart Classroom',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          themeAnimationDuration: const Duration(milliseconds: 350),
          themeAnimationCurve: Curves.easeInOutCubic,
          home: initialHome,
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/commondashboard':
                return MaterialPageRoute(
                  builder: (_) => const CommonDashboard(),
                );

              case '/loginGoogle':
                return MaterialPageRoute(
                  builder: (_) => const ContinueWithGoogle(),
                );

              case '/teacher-dashboard':
                final cls = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => TeacherDashboard(cls: cls),
                );

              case '/student-dashboard':
                final cls = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => StudentDashboard(cls: cls),
                );

              case '/upload':
                final cls = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => UploadMaterialPage(classId: cls['id']),
                );

              case '/quiz':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => QuizPage(
                    quizId: args['quizId'],
                    classId: args['classId'],
                  ),
                );

              case '/results':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => ResultPage(classId: args['classId']),
                );

              case '/chatbot':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => ChatbotPage(classId: args['classId']),
                );

              case '/onboarding':
                return MaterialPageRoute(
                  builder: (_) => const OnboardingScreen(),
                );

              default:
                return null;
            }
          },
        );
      },
    );
  }
}
