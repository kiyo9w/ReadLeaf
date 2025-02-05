import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/blocs/FileBloc/file_bloc.dart';
import 'package:read_leaf/blocs/SearchBloc/search_bloc.dart';
import 'package:read_leaf/blocs/ReaderBloc/reader_bloc.dart';
import 'package:read_leaf/blocs/AuthBloc/auth_bloc.dart';
import 'package:read_leaf/blocs/AuthBloc/auth_event.dart';
import 'package:read_leaf/screens/nav_screen.dart';
import 'package:read_leaf/screens/pdf_viewer.dart';
import 'package:read_leaf/screens/epub_viewer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:read_leaf/models/ai_character_preference.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/models/book_metadata.dart';
import 'package:provider/provider.dart';
import 'package:read_leaf/providers/theme_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'injection.dart';
import 'services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables first
  await dotenv.load(fileName: '.env');

  // Initialize Supabase with env variables
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialize all dependencies (including Hive and its adapters)
  await configureDependencies();

  runApp(
    ChangeNotifierProvider(
      create: (_) => getIt<ThemeProvider>(),
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
            },
            theme: themeProvider.theme,
            home: NavScreen(key: NavScreen.globalKey),
          );
        },
      ),
    );
  }
}
