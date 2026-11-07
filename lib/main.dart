import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'data/demo_package.dart';
import 'data/knowledge_database.dart';
import 'screens/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final documentsDirectory = await getApplicationSupportDirectory();
  final database = KnowledgeDatabase(
    sqlite3.open(p.join(documentsDirectory.path, 'toxo.sqlite3')),
  );
  database.initialize();
  if (database.articleCount == 0) {
    database.importPackage(demoKnowledgePackage);
  }
  runApp(ToxoApp(database: database));
}

class ToxoApp extends StatelessWidget {
  const ToxoApp({required this.database, super.key});

  final KnowledgeDatabase database;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF087F70);
    return MaterialApp(
      title: 'Toxo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3FAF5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF087F70),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: ChatScreen(database: database),
    );
  }
}
