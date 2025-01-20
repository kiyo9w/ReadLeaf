import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/blocs/SearchBloc/search_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';
import 'package:migrated/screens/nav_screen.dart';
import 'package:migrated/screens/pdf_viewer.dart';
import 'package:migrated/screens/epub_viewer.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:migrated/models/ai_character_preference.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/models/book_metadata.dart';
import 'package:provider/provider.dart';
import 'package:migrated/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(AiCharacterPreferenceAdapter());

  // Initialize services
  await configureDependencies();

  // Initialize the AI character service
  final aiCharacterService = getIt<AiCharacterService>();
  await aiCharacterService.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<FileBloc>(
          create: (context) => getIt<FileBloc>()..add(InitFiles()),
        ),
        BlocProvider<SearchBloc>(
          create: (context) => getIt<SearchBloc>(),
        ),
        BlocProvider<ReaderBloc>(
          create: (context) => getIt<ReaderBloc>(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            routes: {
              '/pdf_viewer': (context) => const PDFViewerScreen(),
              '/epub_viewer': (context) => const EPUBViewerScreen(),
            },
            theme: themeProvider.theme,
            home: NavScreen(key: NavScreen.globalKey),
          );
        },
      ),
    );
  }
}
