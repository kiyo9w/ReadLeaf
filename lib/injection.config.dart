// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:read_leaf/blocs/AuthBloc/auth_bloc.dart' as _i77;
import 'package:read_leaf/blocs/FileBloc/file_bloc.dart' as _i396;
import 'package:read_leaf/blocs/ReaderBloc/reader_bloc.dart' as _i1006;
import 'package:read_leaf/blocs/SearchBloc/search_bloc.dart' as _i900;
import 'package:read_leaf/injection.dart' as _i511;
import 'package:read_leaf/providers/theme_provider.dart' as _i462;
import 'package:read_leaf/services/ai_character_service.dart' as _i697;
import 'package:read_leaf/services/annas_archieve.dart' as _i602;
import 'package:read_leaf/services/book_metadata_repository.dart' as _i150;
import 'package:read_leaf/services/chat_service.dart' as _i743;
import 'package:read_leaf/services/deep_link_service.dart' as _i1035;
import 'package:read_leaf/services/gemini_service.dart' as _i817;
import 'package:read_leaf/services/image_service.dart' as _i649;
import 'package:read_leaf/services/rag_service.dart' as _i201;
import 'package:read_leaf/services/social_auth_service.dart' as _i524;
import 'package:read_leaf/services/storage_scanner_service.dart' as _i268;
import 'package:read_leaf/services/storage_service.dart' as _i949;
import 'package:read_leaf/services/sync/sync_manager.dart' as _i589;
import 'package:read_leaf/services/user_preferences_service.dart' as _i179;
import 'package:read_leaf/utils/file_utils.dart' as _i569;
import 'package:supabase_flutter/supabase_flutter.dart' as _i454;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final registerModule = _$RegisterModule();
    gh.lazySingleton<_i361.Dio>(() => registerModule.dio);
    gh.lazySingleton<String>(() => registerModule.backendUrl);
    gh.lazySingleton<_i454.SupabaseClient>(() => registerModule.supabaseClient);
    gh.lazySingleton<_i697.AiCharacterService>(
        () => registerModule.aiCharacterService);
    gh.lazySingleton<_i743.ChatService>(() => registerModule.chatService);
    gh.lazySingleton<_i817.GeminiService>(() => registerModule.geminiService);
    gh.lazySingleton<_i150.BookMetadataRepository>(
        () => registerModule.bookMetadataRepository);
    gh.lazySingleton<_i462.ThemeProvider>(() => registerModule.themeProvider);
    gh.lazySingleton<_i569.FileRepository>(() => registerModule.fileRepository);
    gh.lazySingleton<_i268.StorageScannerService>(
        () => registerModule.storageScannerService);
    gh.lazySingleton<_i201.RagService>(() => registerModule.ragService);
    gh.lazySingleton<_i602.AnnasArchieve>(() => registerModule.annasArchieve);
    gh.lazySingleton<_i1006.ReaderBloc>(() => registerModule.readerBloc);
    gh.lazySingleton<_i396.FileBloc>(() => registerModule.fileBloc);
    gh.lazySingleton<_i900.SearchBloc>(() => registerModule.searchBloc);
    gh.lazySingleton<_i77.AuthBloc>(() => registerModule.authBloc);
    gh.lazySingleton<_i1035.DeepLinkService>(() => _i1035.DeepLinkService());
    gh.lazySingleton<_i524.SocialAuthService>(() => _i524.SocialAuthService());
    gh.lazySingleton<_i949.StorageService>(() => _i949.StorageService());
    gh.lazySingleton<_i649.ImageService>(() => _i649.ImageService());
    gh.factory<_i589.SyncManager>(
        () => _i589.SyncManager(gh<_i454.SupabaseClient>()));
    gh.lazySingleton<_i179.UserPreferencesService>(
        () => _i179.UserPreferencesService(gh<_i589.SyncManager>()));
    return this;
  }
}

class _$RegisterModule extends _i511.RegisterModule {}
