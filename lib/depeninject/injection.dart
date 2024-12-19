import 'package:get_it/get_it.dart';
import 'package:migrated/utils/file_utils.dart';
import 'package:migrated/services/annas_archieve.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';
import 'package:dio/dio.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final fileRepository = FileRepository();
  await fileRepository.init();

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
  getIt.registerLazySingleton<AnnasArchieve>(() => AnnasArchieve(dio: getIt<Dio>()));
  getIt.registerLazySingleton<FileBloc>(() => FileBloc(annasArchieve: getIt<AnnasArchieve>(),fileRepository: getIt<FileRepository>()));
}