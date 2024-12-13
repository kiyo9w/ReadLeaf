part of 'download_bloc.dart';

abstract class DownloadEvent {}

class StartDownload extends DownloadEvent {
  final String url;
  final String fileName;

  StartDownload({required this.url, required this.fileName});
}

class CancelDownload extends DownloadEvent {}

class CheckDownloadStatus extends DownloadEvent {
  final String taskId;
  CheckDownloadStatus({required this.taskId});
}

class DownloadInProgress extends DownloadState {
  final double progress;
  final String message;
  final String? taskId;

  DownloadInProgress({required this.progress, required this.message, this.taskId});
}