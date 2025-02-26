import 'package:equatable/equatable.dart';

class FileInfo extends Equatable {
  final String filePath;
  final int fileSize;
  final bool isSelected;
  final bool isInternetBook;
  final String? author;
  final String? thumbnailUrl;
  final bool isStarred;
  final bool wasRead; // For tracking last read book
  final bool hasBeenCompleted; // For "Have read" section

  const FileInfo(
    this.filePath,
    this.fileSize, {
    this.isSelected = false,
    this.isInternetBook = false,
    this.author,
    this.thumbnailUrl,
    this.isStarred = false,
    this.wasRead = false,
    this.hasBeenCompleted = false,
  });

  FileInfo copyWith({
    String? filePath,
    int? fileSize,
    bool? isSelected,
    bool? isInternetBook,
    String? author,
    String? thumbnailUrl,
    bool? isStarred,
    bool? wasRead,
    bool? hasBeenCompleted,
  }) {
    return FileInfo(
      filePath ?? this.filePath,
      fileSize ?? this.fileSize,
      isSelected: isSelected ?? this.isSelected,
      isInternetBook: isInternetBook ?? this.isInternetBook,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isStarred: isStarred ?? this.isStarred,
      wasRead: wasRead ?? this.wasRead,
      hasBeenCompleted: hasBeenCompleted ?? this.hasBeenCompleted,
    );
  }

  @override
  List<Object?> get props => [
        filePath,
        fileSize,
        isSelected,
        isInternetBook,
        author,
        thumbnailUrl,
        isStarred,
        wasRead,
        hasBeenCompleted,
      ];
}
