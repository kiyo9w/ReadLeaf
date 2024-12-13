part of 'download_bloc.dart';

abstract class DownloadState {}

class DownloadIdle extends DownloadState {}

class DownloadInfo extends DownloadState {

}

class DownloadCompleted extends DownloadState {
  final String filePath;

  DownloadCompleted({required this.filePath});
}

class DownloadFailed extends DownloadState {
  final String error;

  DownloadFailed({required this.error});
}
