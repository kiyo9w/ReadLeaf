import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/features/library/presentation/blocs/file_bloc.dart';
import 'package:read_leaf/features/library/presentation/widgets/file_card.dart';
import 'package:read_leaf/nav_screen.dart';
import 'package:read_leaf/features/library/domain/models/file_info.dart';
import 'package:read_leaf/core/utils/utils.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  bool _favouriteExpanded = true;
  bool _localStorageExpanded = true;
  bool _haveReadExpanded = true;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollingDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (!_isScrollingDown) {
        _isScrollingDown = true;
        NavScreen.globalKey.currentState?.hideNavBar(true);
      }
    }
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (_isScrollingDown) {
        _isScrollingDown = false;
        NavScreen.globalKey.currentState?.hideNavBar(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = ResponsiveConstants.isTablet(context);

    return BlocBuilder<FileBloc, FileState>(
      builder: (context, state) {
        if (state is FileLoaded) {
          if (state.lastRemovedFile != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Utils.showUndoSnackBar(
                  context,
                  'File deleted',
                  () {
                    context.read<FileBloc>().add(const UndoRemoveFile());
                  },
                );
              }
            });
          }

          final starredBooks =
              state.files.where((file) => file.isStarred).toList();
          final completedBooks =
              state.files.where((file) => file.hasBeenCompleted).toList();
          final localFiles = state.files.toList();

          return Scaffold(
            appBar: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              centerTitle: false,
              title: Text(
                'My Library',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: isTablet ? 28 : 24,
                ),
              ),
            ),
            body: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryHeader(
                      title: "Starred Books",
                      count: starredBooks.length,
                      isExpanded: _favouriteExpanded,
                      onTap: () {
                        setState(() {
                          _favouriteExpanded = !_favouriteExpanded;
                        });
                      },
                    ),
                    if (_favouriteExpanded && starredBooks.isNotEmpty)
                      ..._buildBookCards(starredBooks),
                    SizedBox(height: isTablet ? 24 : 20),
                    _buildCategoryHeader(
                      title: "Have Read",
                      count: completedBooks.length,
                      isExpanded: _haveReadExpanded,
                      onTap: () {
                        setState(() {
                          _haveReadExpanded = !_haveReadExpanded;
                        });
                      },
                    ),
                    if (_haveReadExpanded && completedBooks.isNotEmpty)
                      ..._buildBookCards(completedBooks),
                    SizedBox(height: isTablet ? 24 : 20),
                    _buildCategoryHeader(
                      title: "Local Storage",
                      count: localFiles.length,
                      isExpanded: _localStorageExpanded,
                      onTap: () {
                        setState(() {
                          _localStorageExpanded = !_localStorageExpanded;
                        });
                      },
                    ),
                    if (_localStorageExpanded && localFiles.isNotEmpty)
                      ..._buildBookCards(localFiles),
                    SizedBox(height: isTablet ? 48 : 40),
                  ],
                ),
              ),
            ),
          );
        }
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: theme.primaryColor,
              strokeWidth: isTablet ? 3 : 2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryHeader({
    required String title,
    required int count,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isTablet = ResponsiveConstants.isTablet(context);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: isTablet ? 24 : 20,
              ),
            ),
            Row(
              children: [
                Text(
                  count.toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
                SizedBox(width: isTablet ? 6 : 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.iconTheme.color,
                  size: isTablet ? 28 : 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBookCards(List<FileInfo> books) {
    final isTablet = ResponsiveConstants.isTablet(context);
    return books.map((book) {
      return Padding(
        padding: EdgeInsets.only(bottom: isTablet ? 12 : 10),
        child: FileCard(
          filePath: book.filePath,
          fileSize: book.fileSize,
          isSelected: book.isSelected,
          onSelected: () {
            context.read<FileBloc>().add(SelectFile(book.filePath));
          },
          onView: () {
            context.read<FileBloc>().add(ViewFile(book.filePath));
          },
          onRemove: () {
            context.read<FileBloc>().add(RemoveFile(book.filePath));
          },
          onDownload: () {},
          onStar: () {
            context.read<FileBloc>().add(ToggleStarred(book.filePath));
          },
          title: FileCard.extractFileName(book.filePath),
          isInternetBook: book.isInternetBook,
          author: book.author ?? 'Unknown',
          thumbnailUrl: book.thumbnailUrl,
          isStarred: book.isStarred,
          wasRead: book.wasRead,
          hasBeenCompleted: book.hasBeenCompleted,
        ),
      );
    }).toList();
  }
}
