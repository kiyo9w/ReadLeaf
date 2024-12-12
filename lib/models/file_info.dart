import 'package:equatable/equatable.dart';

class FileInfo extends Equatable {
  final String filePath;
  final int fileSize;
  final bool isSelected;

  const FileInfo(this.filePath, this.fileSize, {this.isSelected = false});

  FileInfo copyWith({
    String? filePath,
    int? fileSize,
    bool? isSelected,
  }) {
    return FileInfo(
      filePath ?? this.filePath,
      fileSize ?? this.fileSize,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object> get props => [filePath, fileSize, isSelected];
}