import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:migrated/utils/file_utils.dart';
import 'package:migrated/services/annas_archieve.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/blocs/SearchBloc/search_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';
import 'package:dio/dio.dart';
import 'package:migrated/services/storage_scanner_service.dart';
import 'package:migrated/services/gemini_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:migrated/services/book_metadata_repository.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/services/chat_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:migrated/models/chat_message.dart';
import 'package:migrated/providers/theme_provider.dart';
import 'package:migrated/services/rag_service.dart';
import 'package:migrated/blocs/AuthBloc/auth_bloc.dart';
import 'package:migrated/services/supabase_service.dart';
import 'package:migrated/services/deep_link_service.dart';
import 'package:migrated/services/storage_service.dart';
import 'package:migrated/services/social_auth_service.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  // Initialize core services
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(ChatMessageAdapter());
  }
  await dotenv.load(fileName: '.env');

  // Register infrastructure services
  getIt.registerLazySingleton<Dio>(() {
    return Dio(
      BaseOptions(
        headers: {
          "user-agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36",
        },
      ),
    );
  });

  // Register backend URL
  final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';
  getIt.registerSingleton<String>(backendUrl, instanceName: 'backendUrl');

  // Register storage and file services
  final fileRepository = FileRepository();
  await fileRepository.init();
  getIt.registerSingleton<FileRepository>(fileRepository);
  getIt.registerLazySingleton<StorageScannerService>(
      () => StorageScannerService());
  getIt.registerLazySingleton<StorageService>(() => StorageService());

  // Register authentication services
  getIt.registerLazySingleton<SocialAuthService>(() => SocialAuthService());
  getIt.registerLazySingleton<DeepLinkService>(() => DeepLinkService());

  // Register AI and metadata services
  final aiCharacterService = AiCharacterService();
  getIt.registerSingleton<AiCharacterService>(aiCharacterService);

  final chatService = ChatService();
  await chatService.init();
  getIt.registerSingleton<ChatService>(chatService);

  final geminiService = GeminiService();
  await geminiService.initialize();
  getIt.registerSingleton<GeminiService>(geminiService);

  final ragService = RagService();
  getIt.registerSingleton<RagService>(ragService);

  final bookMetadataRepository = BookMetadataRepository();
  await bookMetadataRepository.init();
  getIt.registerSingleton<BookMetadataRepository>(bookMetadataRepository);

  // Register UI services
  final themeProvider = ThemeProvider();
  getIt.registerSingleton<ThemeProvider>(themeProvider);

  // Register API services
  getIt.registerLazySingleton<AnnasArchieve>(
      () => AnnasArchieve(dio: getIt<Dio>()));

  // Register blocs
  getIt.registerLazySingleton<ReaderBloc>(() => ReaderBloc());
  getIt.registerLazySingleton<FileBloc>(() => FileBloc(
        fileRepository: getIt<FileRepository>(),
        storageScannerService: getIt<StorageScannerService>(),
      ));
  getIt.registerLazySingleton<SearchBloc>(() => SearchBloc(
        annasArchieve: getIt<AnnasArchieve>(),
        fileRepository: getIt<FileRepository>(),
      ));
  getIt.registerLazySingleton<AuthBloc>(
      () => AuthBloc(getIt<SupabaseService>()));
}
