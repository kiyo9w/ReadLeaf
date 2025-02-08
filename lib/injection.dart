import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:read_leaf/utils/file_utils.dart';
import 'package:read_leaf/services/annas_archieve.dart';
import 'package:read_leaf/blocs/FileBloc/file_bloc.dart';
import 'package:read_leaf/blocs/SearchBloc/search_bloc.dart';
import 'package:read_leaf/blocs/ReaderBloc/reader_bloc.dart';
import 'package:dio/dio.dart';
import 'package:read_leaf/services/storage_scanner_service.dart';
import 'package:read_leaf/services/gemini_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:read_leaf/services/book_metadata_repository.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/services/chat_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:read_leaf/models/chat_message.dart';
import 'package:read_leaf/providers/theme_provider.dart';
import 'package:read_leaf/services/rag_service.dart';
import 'package:read_leaf/blocs/AuthBloc/auth_bloc.dart';
import 'package:read_leaf/services/supabase_service.dart';
import 'package:read_leaf/services/deep_link_service.dart';
import 'package:read_leaf/services/storage_service.dart';
import 'package:read_leaf/services/social_auth_service.dart';
import 'package:read_leaf/services/image_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:read_leaf/models/ai_character_preference.dart';
import 'package:read_leaf/services/sync/sync_manager.dart';
import 'package:read_leaf/services/user_preferences_service.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  // Initialize core services in parallel
  await Future.wait([
    Hive.initFlutter(),
    _initializeHiveAdapters(),
  ]);

  // Verify environment variables
  if (dotenv.env['SUPABASE_URL'] == null ||
      dotenv.env['SUPABASE_ANON_KEY'] == null) {
    throw Exception('Required environment variables are not set');
  }

  // Register infrastructure services
  getIt.registerLazySingleton<Dio>(() {
    return Dio(
      BaseOptions(
        headers: {
          "user-agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36",
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  });

  // Register Supabase service first as other services might depend on it
  getIt.registerLazySingleton<SupabaseService>(
    () => SupabaseService(Supabase.instance.client),
  );

  // Register DeepLinkService early as it's a core service
  getIt.registerLazySingleton<DeepLinkService>(() => DeepLinkService());

  // Register backend URL
  final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';
  getIt.registerSingleton<String>(backendUrl, instanceName: 'backendUrl');

  // Create and register sync manager first
  final syncManager = SyncManager(Supabase.instance.client);
  getIt.registerSingleton<SyncManager>(syncManager);
  await syncManager.initialize();

  // Create and register user preferences service
  final userPreferencesService = UserPreferencesService(syncManager);
  getIt.registerSingleton<UserPreferencesService>(userPreferencesService);
  await userPreferencesService.init();

  // Create instances of core services
  final fileRepository = FileRepository();
  final bookMetadataRepository = BookMetadataRepository();
  final aiCharacterService = AiCharacterService();
  final storageService = StorageService();
  final storageScannerService = StorageScannerService();
  final socialAuthService = SocialAuthService();
  final themeProvider = ThemeProvider(getIt<UserPreferencesService>());
  final ragService = RagService();
  final imageService = ImageService();
  final chatService = ChatService(syncManager);
  final geminiService = GeminiService(aiCharacterService, chatService);

  // Initialize services that require async initialization
  await Future.wait([
    fileRepository.init(),
    bookMetadataRepository.init(),
    chatService.init(),
    geminiService.initialize(),
    aiCharacterService.init(),
  ]);

  // Register all services
  // Storage and file services
  getIt.registerSingleton<FileRepository>(fileRepository);
  getIt.registerSingleton<StorageScannerService>(storageScannerService);
  getIt.registerSingleton<StorageService>(storageService);

  // Authentication services
  getIt.registerSingleton<SocialAuthService>(socialAuthService);

  // AI and metadata services
  getIt.registerSingleton<AiCharacterService>(aiCharacterService);
  getIt.registerSingleton<ChatService>(chatService);
  getIt.registerSingleton<GeminiService>(geminiService);
  getIt.registerSingleton<RagService>(ragService);
  getIt.registerSingleton<BookMetadataRepository>(bookMetadataRepository);

  // UI services
  getIt.registerSingleton<ThemeProvider>(themeProvider);
  getIt.registerSingleton<ImageService>(imageService);

  // API services
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
  getIt.registerLazySingleton<AuthBloc>(() => AuthBloc(
        getIt<SupabaseService>(),
        getIt<ChatService>(),
        getIt<BookMetadataRepository>(),
        getIt<UserPreferencesService>(),
      ));
}

Future<void> _initializeHiveAdapters() async {
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(ChatMessageAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(AiCharacterPreferenceAdapter());
  }
}

@module
abstract class RegisterModule {
  @lazySingleton
  Dio get dio => Dio(BaseOptions(
        headers: {
          "user-agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36",
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

  @lazySingleton
  String get backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';

  @lazySingleton
  SupabaseClient get supabaseClient => Supabase.instance.client;

  @lazySingleton
  AiCharacterService get aiCharacterService => AiCharacterService();

  @lazySingleton
  ChatService get chatService => ChatService(getIt<SyncManager>());

  @lazySingleton
  GeminiService get geminiService =>
      GeminiService(aiCharacterService, chatService);

  @lazySingleton
  BookMetadataRepository get bookMetadataRepository => BookMetadataRepository();

  @lazySingleton
  ThemeProvider get themeProvider =>
      ThemeProvider(getIt<UserPreferencesService>());

  @lazySingleton
  FileRepository get fileRepository => FileRepository();

  @lazySingleton
  StorageScannerService get storageScannerService => StorageScannerService();

  @lazySingleton
  RagService get ragService => RagService();

  @lazySingleton
  AnnasArchieve get annasArchieve => AnnasArchieve(dio: dio);

  @lazySingleton
  ReaderBloc get readerBloc => ReaderBloc();

  @lazySingleton
  FileBloc get fileBloc => FileBloc(
        fileRepository: fileRepository,
        storageScannerService: storageScannerService,
      );

  @lazySingleton
  SearchBloc get searchBloc => SearchBloc(
        annasArchieve: annasArchieve,
        fileRepository: fileRepository,
      );

  @lazySingleton
  AuthBloc get authBloc => AuthBloc(
        SupabaseService(supabaseClient),
        chatService,
        bookMetadataRepository,
        UserPreferencesService(getIt<SyncManager>()),
      );
}
