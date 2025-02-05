// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:read_leaf/services/deep_link_service.dart' as _i932;
import 'package:read_leaf/services/image_service.dart' as _i744;
import 'package:read_leaf/services/social_auth_service.dart' as _i68;
import 'package:read_leaf/services/storage_service.dart' as _i39;

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
    gh.lazySingleton<_i932.DeepLinkService>(() => _i932.DeepLinkService());
    gh.lazySingleton<_i68.SocialAuthService>(() => _i68.SocialAuthService());
    gh.lazySingleton<_i39.StorageService>(() => _i39.StorageService());
    gh.lazySingleton<_i744.ImageService>(() => _i744.ImageService());
    return this;
  }
}
