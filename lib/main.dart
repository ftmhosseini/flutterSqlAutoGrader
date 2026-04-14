import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const SqlAutoGraderApp(),
    ),
  );
}

class SqlAutoGraderApp extends StatelessWidget {
  const SqlAutoGraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(context);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SQL Auto Grader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4e73df)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
