import 'package:get_it/get_it.dart';
import 'package:migrated/utils/file_utils.dart';

final getIt = GetIt.instance;

void configureDependencies() async {
  getIt.registerSingleton<FileRepository>(FileRepository());
}
