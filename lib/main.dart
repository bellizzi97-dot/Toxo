import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'data/app_update_checker.dart';
import 'data/demo_package.dart';
import 'data/knowledge_database.dart';
import 'data/offline_pack_manager.dart';
import 'data/offline_pack_manifest.dart';
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
  final packManager = OfflinePackManager(
    manifest: await OfflinePackManifest.loadBundled(),
    database: database,
    supportDirectory: documentsDirectory,
  );
  final appUpdateChecker = AppUpdateChecker();
  runApp(
    ToxoApp(
      database: database,
      packManager: packManager,
      appUpdateChecker: appUpdateChecker,
    ),
  );
}

class ToxoApp extends StatefulWidget {
  const ToxoApp({
    required this.database,
    required this.packManager,
    required this.appUpdateChecker,
    super.key,
  });

  final KnowledgeDatabase database;
  final OfflinePackManager packManager;
  final AppUpdateChecker appUpdateChecker;

  @override
  State<ToxoApp> createState() => _ToxoAppState();
}

class _ToxoAppState extends State<ToxoApp> {
  @override
  Widget build(BuildContext context) {
    final neuralTheme = widget.database.appearance == 'neural';
    return MaterialApp(
      title: 'Toxo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: neuralTheme
              ? const Color(0xFF38E0C0)
              : const Color(0xFF087F70),
          brightness: neuralTheme ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor:
            neuralTheme ? const Color(0xFF071622) : const Color(0xFFF3FAF5),
        appBarTheme: AppBarTheme(
          backgroundColor: neuralTheme
              ? const Color(0xFF0B2735)
              : const Color(0xFF087F70),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: ChatScreen(
        database: widget.database,
        packManager: widget.packManager,
        appUpdateChecker: widget.appUpdateChecker,
        onAppearanceChanged: () => setState(() {}),
      ),
    );
  }
}
