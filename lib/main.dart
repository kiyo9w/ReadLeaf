import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/features/library/presentation/blocs/file_bloc.dart';
import 'package:read_leaf/features/search/presentation/blocs/search_bloc.dart';
import 'package:read_leaf/features/reader/presentation/blocs/reader_bloc.dart';
import 'package:read_leaf/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:read_leaf/features/auth/presentation/blocs/auth_event.dart';
import 'package:read_leaf/nav_screen.dart';
import 'package:read_leaf/features/reader/presentation/screens/pdf_viewer.dart';
import 'package:read_leaf/features/reader/presentation/screens/epub_viewer.dart';
import 'package:read_leaf/features/reader/presentation/screens/reader_loading_screen_route.dart';
import 'package:provider/provider.dart';
import 'package:read_leaf/core/providers/theme_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:read_leaf/features/library/presentation/screens/splash_screen.dart';
import 'injection/injection.dart';
import 'package:read_leaf/features/library/presentation/screens/home_screen.dart';
import 'package:read_leaf/features/characters/data/character_suggestion_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    ),
  );

  try {
    await dotenv.load(fileName: '.env');
    await _initializeSupabase();
    await configureDependencies();
    await CharacterSuggestionService.initialize();
    runApp(
      ChangeNotifierProvider(
        create: (_) => getIt<ThemeProvider>(),
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Initialization error: $e');
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text(
              'Failed to initialize app: $e',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _initializeSupabase() async {
  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (url == null || anonKey == null) {
    throw Exception('Missing Supabase configuration');
  }

  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
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
        BlocProvider<AuthBloc>(
          create: (context) => getIt<AuthBloc>()..add(AuthCheckRequested()),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            routes: {
              '/pdf_viewer': (context) => const PDFViewerScreen(),
              '/epub_viewer': (context) => const EPUBViewerScreen(),
              '/reader_loading': (context) {
                final args = ModalRoute.of(context)!.settings.arguments
                    as Map<String, dynamic>;
                return ReaderLoadingScreenRoute(
                  filePath: args['filePath'],
                  targetRoute: args['targetRoute'],
                );
              },
            },
            theme: themeProvider.theme,
            home: NavScreen(key: NavScreen.globalKey),
          );
        },
      ),
    );
  }
}
