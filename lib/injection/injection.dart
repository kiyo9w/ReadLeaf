import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:read_leaf/core/utils/file_utils.dart';
import 'package:read_leaf/features/search/data/annas_archieve.dart';
import 'package:read_leaf/features/library/presentation/blocs/file_bloc.dart';
import 'package:read_leaf/features/search/presentation/blocs/search_bloc.dart';
import 'package:read_leaf/features/reader/presentation/blocs/reader_bloc.dart';
import 'package:dio/dio.dart';
import 'package:read_leaf/features/library/data/storage_scanner_service.dart';
import 'package:read_leaf/features/companion_chat/data/gemini_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:read_leaf/features/library/data/book_metadata_repository.dart';
import 'package:read_leaf/features/characters/data/ai_character_service.dart';
import 'package:read_leaf/features/companion_chat/data/chat_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:read_leaf/features/companion_chat/domain/models/chat_message.dart';
import 'package:read_leaf/features/settings/presentation/blocs/theme_bloc.dart';
import 'package:read_leaf/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:read_leaf/features/companion_chat/data/rag_service.dart';
import 'package:read_leaf/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:read_leaf/features/settings/data/sync/supabase_service.dart';
import 'package:read_leaf/features/settings/data/sync/deep_link_service.dart';
import 'package:read_leaf/features/library/data/storage_service.dart';
import 'package:read_leaf/features/auth/data/social_auth_service.dart';
import 'package:read_leaf/features/characters/data/image_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character_preference.dart';
import 'package:read_leaf/features/settings/data/sync/sync_manager.dart';
import 'package:read_leaf/features/settings/data/sync/user_preferences_service.dart';
import 'package:read_leaf/features/library/data/thumbnail_service.dart';
import 'package:read_leaf/features/characters/data/character_template_service.dart';
import 'package:read_leaf/features/reader/data/text_selection_service.dart';
import 'package:read_leaf/features/reader/data/epub_service.dart';

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
  getIt.registerLazySingleton<DeepLinkService>(() => DeepLinkService());
  getIt.registerSingleton<String>(
    dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000',
    instanceName: 'backendUrl',
  );

  // Create and register sync manager first as it's needed by other services
  final syncManager = SyncManager(Supabase.instance.client);
  getIt.registerSingleton<SyncManager>(syncManager);

  // Initialize user preferences early as it affects the UI
  final userPreferencesService = UserPreferencesService(syncManager);
  getIt.registerSingleton<UserPreferencesService>(userPreferencesService);

  // Initialize critical services in parallel
  await Future.wait([
    syncManager.initialize(),
    userPreferencesService.init(),
  ]);

  // Create core service instances
  final fileRepository = FileRepository();
  final bookMetadataRepository = BookMetadataRepository();

  // Initialize core services in parallel
  await Future.wait([
    fileRepository.init(),
    bookMetadataRepository.init(),
  ]);

  // Register core services
  getIt.registerSingleton<FileRepository>(fileRepository);
  getIt.registerSingleton<BookMetadataRepository>(bookMetadataRepository);

  // Replace SettingsProvider with SettingsBloc
  getIt.registerSingleton<SettingsBloc>(SettingsBloc());

  // Register ThemeBloc
  getIt.registerSingleton<ThemeBloc>(ThemeBloc(userPreferencesService));

  // Register non-critical services lazily
  getIt.registerLazySingleton<StorageScannerService>(
      () => StorageScannerService());
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<ThumbnailService>(() => ThumbnailService());
  getIt.registerLazySingleton<CharacterTemplateService>(
      () => CharacterTemplateService());
  getIt.registerLazySingleton<SocialAuthService>(() => SocialAuthService());
  getIt.registerLazySingleton<ImageService>(() => ImageService());
  getIt.registerLazySingleton<AnnasArchieve>(
      () => AnnasArchieve(dio: getIt<Dio>()));

  // Initialize AI services in parallel
  final aiCharacterService = AiCharacterService();
  final chatService = ChatService(syncManager);
  final geminiService = GeminiService(aiCharacterService, chatService);
  final ragService = RagService();

  await Future.wait([
    aiCharacterService.init(),
    chatService.init(),
    geminiService.initialize(),
  ]);

  // Register AI services
  getIt.registerSingleton<AiCharacterService>(aiCharacterService);
  getIt.registerSingleton<ChatService>(chatService);
  getIt.registerSingleton<GeminiService>(geminiService);
  getIt.registerSingleton<RagService>(ragService);
  final textSelectionService = TextSelectionService();
  getIt.registerSingleton<TextSelectionService>(textSelectionService);

  // Register reader services
  final epubService = EpubService();
  getIt.registerSingleton<EpubService>(epubService);

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

  @lazySingleton
  ThumbnailService get thumbnailService => ThumbnailService();

  @lazySingleton
  CharacterTemplateService get characterTemplateService =>
      CharacterTemplateService();

  @lazySingleton
  TextSelectionService get textSelectionService => TextSelectionService();

  @lazySingleton
  EpubService get epubService => EpubService();
}
