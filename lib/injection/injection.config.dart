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
import 'package:read_leaf/core/utils/file_utils.dart' as _i924;
import 'package:read_leaf/features/auth/data/social_auth_service.dart'
    as _i1034;
import 'package:read_leaf/features/auth/presentation/blocs/auth_bloc.dart'
    as _i19;
import 'package:read_leaf/features/characters/data/ai_character_service.dart'
    as _i655;
import 'package:read_leaf/features/characters/data/character_template_service.dart'
    as _i710;
import 'package:read_leaf/features/characters/data/image_service.dart' as _i111;
import 'package:read_leaf/features/companion_chat/data/chat_service.dart'
    as _i57;
import 'package:read_leaf/features/companion_chat/data/gemini_service.dart'
    as _i233;
import 'package:read_leaf/features/companion_chat/data/rag_service.dart'
    as _i659;
import 'package:read_leaf/features/library/data/book_metadata_repository.dart'
    as _i425;
import 'package:read_leaf/features/library/data/storage_scanner_service.dart'
    as _i977;
import 'package:read_leaf/features/library/data/storage_service.dart' as _i207;
import 'package:read_leaf/features/library/data/thumbnail_service.dart'
    as _i938;
import 'package:read_leaf/features/library/presentation/blocs/file_bloc.dart'
    as _i64;
import 'package:read_leaf/features/reader/data/text_selection_service.dart'
    as _i401;
import 'package:read_leaf/features/reader/presentation/blocs/reader_bloc.dart'
    as _i187;
import 'package:read_leaf/features/search/data/annas_archieve.dart' as _i576;
import 'package:read_leaf/features/search/presentation/blocs/search_bloc.dart'
    as _i890;
import 'package:read_leaf/features/settings/data/sync/deep_link_service.dart'
    as _i253;
import 'package:read_leaf/features/settings/data/sync/sync_manager.dart'
    as _i998;
import 'package:read_leaf/features/settings/data/sync/user_preferences_service.dart'
    as _i402;
import 'package:read_leaf/injection/injection.dart' as _i473;
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
    gh.lazySingleton<_i253.DeepLinkService>(() => _i253.DeepLinkService());
    gh.lazySingleton<_i1034.SocialAuthService>(
        () => _i1034.SocialAuthService());
    gh.lazySingleton<_i207.StorageService>(() => _i207.StorageService());
    gh.lazySingleton<_i111.ImageService>(() => _i111.ImageService());
    gh.lazySingleton<_i361.Dio>(() => registerModule.dio);
    gh.lazySingleton<String>(() => registerModule.backendUrl);
    gh.lazySingleton<_i454.SupabaseClient>(() => registerModule.supabaseClient);
    gh.lazySingleton<_i655.AiCharacterService>(
        () => registerModule.aiCharacterService);
    gh.lazySingleton<_i57.ChatService>(() => registerModule.chatService);
    gh.lazySingleton<_i233.GeminiService>(() => registerModule.geminiService);
    gh.lazySingleton<_i425.BookMetadataRepository>(
        () => registerModule.bookMetadataRepository);
    gh.lazySingleton<_i924.FileRepository>(() => registerModule.fileRepository);
    gh.lazySingleton<_i977.StorageScannerService>(
        () => registerModule.storageScannerService);
    gh.lazySingleton<_i659.RagService>(() => registerModule.ragService);
    gh.lazySingleton<_i576.AnnasArchieve>(() => registerModule.annasArchieve);
    gh.lazySingleton<_i187.ReaderBloc>(() => registerModule.readerBloc);
    gh.lazySingleton<_i64.FileBloc>(() => registerModule.fileBloc);
    gh.lazySingleton<_i890.SearchBloc>(() => registerModule.searchBloc);
    gh.lazySingleton<_i19.AuthBloc>(() => registerModule.authBloc);
    gh.lazySingleton<_i938.ThumbnailService>(
        () => registerModule.thumbnailService);
    gh.lazySingleton<_i710.CharacterTemplateService>(
        () => registerModule.characterTemplateService);
    gh.lazySingleton<_i401.TextSelectionService>(
        () => registerModule.textSelectionService);
    gh.factory<_i998.SyncManager>(
        () => _i998.SyncManager(gh<_i454.SupabaseClient>()));
    gh.lazySingleton<_i402.UserPreferencesService>(
        () => _i402.UserPreferencesService(gh<_i998.SyncManager>()));
    return this;
  }
}

class _$RegisterModule extends _i473.RegisterModule {}
