import 'package:equatable/equatable.dart';

class FileInfo extends Equatable {
  final String filePath;
  final int fileSize;
  final bool isSelected;
  final bool isInternetBook;
  final String? author;
  final String? thumbnailUrl;

  const FileInfo(
      this.filePath,
      this.fileSize, {
        this.isSelected = false,
        this.isInternetBook = false,
        this.author,
        this.thumbnailUrl,
      });

  FileInfo copyWith({
    String? filePath,
    int? fileSize,
    bool? isSelected,
    bool? isInternetBook,
    String? author,
    String? thumbnailUrl,
  }) {
    return FileInfo(
      filePath ?? this.filePath,
      fileSize ?? this.fileSize,
      isSelected: isSelected ?? this.isSelected,
      isInternetBook: isInternetBook ?? this.isInternetBook,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  @override
  List<Object?> get props => [filePath, fileSize, isSelected, isInternetBook, author, thumbnailUrl];
}