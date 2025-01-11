import 'package:get_it/get_it.dart';
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

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive adapters
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(ChatMessageAdapter());
  }

  // Load environment variables
  await dotenv.load(fileName: '.env');

  final fileRepository = FileRepository();
  await fileRepository.init();

  // Initialize AiCharacterService first
  final aiCharacterService = AiCharacterService();
  getIt.registerSingleton<AiCharacterService>(aiCharacterService);

  // Initialize Gemini service after AiCharacterService
  final geminiService = GeminiService();
  await geminiService.initialize();
  getIt.registerSingleton<GeminiService>(geminiService);

  // Initialize BookMetadataRepository
  final bookMetadataRepository = BookMetadataRepository();
  await bookMetadataRepository.init();
  getIt.registerSingleton<BookMetadataRepository>(bookMetadataRepository);

  getIt.registerSingleton<FileRepository>(fileRepository);
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
  getIt.registerLazySingleton<ReaderBloc>(() => ReaderBloc());
  getIt.registerLazySingleton<AnnasArchieve>(
      () => AnnasArchieve(dio: getIt<Dio>()));
  getIt.registerLazySingleton<StorageScannerService>(
      () => StorageScannerService());
  getIt.registerLazySingleton<FileBloc>(() => FileBloc(
        fileRepository: getIt<FileRepository>(),
        storageScannerService: getIt<StorageScannerService>(),
      ));
  getIt.registerLazySingleton<SearchBloc>(() => SearchBloc(
        annasArchieve: getIt<AnnasArchieve>(),
        fileRepository: getIt<FileRepository>(),
      ));

  // Register ChatService as a singleton
  final chatService = ChatService();
  await chatService.init();
  getIt.registerSingleton<ChatService>(chatService);
}
