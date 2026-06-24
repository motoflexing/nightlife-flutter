import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nightlife_shared/nightlife_shared.dart';

import 'admin_panel.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NightlifeAdminApp());
}

class NightlifeAdminApp extends StatelessWidget {
  const NightlifeAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nightlife Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AdminPanelPage(),
    );
  }
}
