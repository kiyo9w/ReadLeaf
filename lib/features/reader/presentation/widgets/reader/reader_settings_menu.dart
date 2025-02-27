import 'package:flutter/material.dart';
import 'package:read_leaf/features/reader/presentation/blocs/reader_bloc.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:read_leaf/features/library/presentation/blocs/file_bloc.dart';
import 'package:read_leaf/core/utils/utils.dart';

enum ReaderLayoutMode { vertical, horizontal, facing, longStrip }

class ReaderSettingsMenu extends StatelessWidget {
  final String filePath;
  final ReaderLayoutMode currentLayoutMode;
  final Function(ReaderLayoutMode) onLayoutModeChanged;
  final VoidCallback onClose;
  final bool showFacingOption;
  final bool showLongStripOption;

  const ReaderSettingsMenu({
    super.key,
    required this.filePath,
    required this.currentLayoutMode,
    required this.onLayoutModeChanged,
    required this.onClose,
    this.showFacingOption = false,
    this.showLongStripOption = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF251B2F)
            : const Color(0xFFFAF9F7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const Divider(height: 1),
          _buildLayoutSection(context),
          const Divider(height: 1),
          _buildReadingModeSection(context),
          const Divider(height: 1),
          _buildFileActionsSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: ResponsiveConstants.getTitleFontSize(context),
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF2F2F7)
                  : const Color(0xFF1C1C1E),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF2F2F7)
                  : const Color(0xFF1C1C1E),
              size: 24,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Page Layout',
            style: TextStyle(
              fontSize: ResponsiveConstants.getBodyFontSize(context) + 2,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF2F2F7)
                  : const Color(0xFF1C1C1E),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              _buildLayoutOption(
                context,
                ReaderLayoutMode.vertical,
                'Vertical',
                Icons.vertical_distribute,
              ),
              const SizedBox(width: 12),
              _buildLayoutOption(
                context,
                ReaderLayoutMode.horizontal,
                'Horizontal',
                Icons.horizontal_distribute,
              ),
              if (showFacingOption) ...[
                const SizedBox(width: 12),
                _buildLayoutOption(
                  context,
                  ReaderLayoutMode.facing,
                  'Facing',
                  Icons.book_outlined,
                ),
              ],
              if (showLongStripOption) ...[
                const SizedBox(width: 12),
                _buildLayoutOption(
                  context,
                  ReaderLayoutMode.longStrip,
                  'Long Strip',
                  Icons.view_day,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutOption(
    BuildContext context,
    ReaderLayoutMode mode,
    String label,
    IconData icon,
  ) {
    final isSelected = currentLayoutMode == mode;
    final primaryColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFAA96B6)
        : const Color(0xFF9E7B80);

    return GestureDetector(
      onTap: () => onLayoutModeChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.15)
              : Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF352A3B).withOpacity(0.5)
                  : const Color(0xFFF8F1F1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF352A3B)
                    : const Color(0xFFE5E5EA),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? primaryColor
                  : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF2F2F7)
                      : const Color(0xFF1C1C1E),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveConstants.getBodyFontSize(context) - 1,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? primaryColor
                    : Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF2F2F7)
                        : const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingModeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'Reading Mode',
            style: TextStyle(
              fontSize: ResponsiveConstants.getBodyFontSize(context) + 2,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF2F2F7)
                  : const Color(0xFF1C1C1E),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              _buildReadingModeOption(
                context,
                ReadingMode.light,
                'Light',
                Icons.light_mode,
              ),
              const SizedBox(width: 12),
              _buildReadingModeOption(
                context,
                ReadingMode.dark,
                'Dark',
                Icons.dark_mode,
              ),
              const SizedBox(width: 12),
              _buildReadingModeOption(
                context,
                ReadingMode.sepia,
                'Sepia',
                Icons.auto_awesome,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadingModeOption(
    BuildContext context,
    ReadingMode mode,
    String label,
    IconData icon,
  ) {
    final currentMode = context.select((ReaderBloc bloc) {
      if (bloc.state is ReaderLoaded) {
        return (bloc.state as ReaderLoaded).readingMode;
      }
      return ReadingMode.light;
    });

    final isSelected = currentMode == mode;
    final primaryColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFAA96B6)
        : const Color(0xFF9E7B80);

    return GestureDetector(
      onTap: () {
        context.read<ReaderBloc>().add(setReadingMode(mode));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.15)
              : Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF352A3B).withOpacity(0.5)
                  : const Color(0xFFF8F1F1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF352A3B)
                    : const Color(0xFFE5E5EA),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? primaryColor
                  : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF2F2F7)
                      : const Color(0xFF1C1C1E),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveConstants.getBodyFontSize(context) - 1,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? primaryColor
                    : Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF2F2F7)
                        : const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            'File Actions',
            style: TextStyle(
              fontSize: ResponsiveConstants.getBodyFontSize(context) + 2,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF2F2F7)
                  : const Color(0xFF1C1C1E),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              _buildActionButton(
                context,
                'Share File',
                Icons.share_outlined,
                () async {
                  try {
                    final file = File(filePath);
                    if (await file.exists()) {
                      await Share.share(
                        filePath,
                        subject: filePath.split('/').last,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Utils.showErrorSnackBar(
                          context, 'Error sharing file: $e');
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                context,
                'Toggle Star',
                Icons.star_outline,
                () {
                  context.read<FileBloc>().add(ToggleStarred(filePath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Updated starred status'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                context,
                'Mark as Read',
                Icons.check_circle_outline,
                () {
                  context.read<FileBloc>().add(ViewFile(filePath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Marked as read'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                context,
                'Move to Trash',
                Icons.delete_outline,
                () async {
                  final shouldDelete = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete File'),
                      content: const Text(
                          'Are you sure you want to delete this file? This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (shouldDelete == true && context.mounted) {
                    try {
                      final file = File(filePath);
                      if (await file.exists()) {
                        await file.delete();
                        if (context.mounted) {
                          context.read<FileBloc>().add(RemoveFile(filePath));
                          context.read<ReaderBloc>().add(CloseReader());
                          Navigator.of(context).pop();
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Utils.showErrorSnackBar(
                            context, 'Error deleting file: $e');
                      }
                    }
                  }
                },
                textColor: Colors.red,
                iconColor: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    Color? textColor,
    Color? iconColor,
  }) {
    final defaultColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF2F2F7)
        : const Color(0xFF1C1C1E);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF352A3B).withOpacity(0.5)
              : const Color(0xFFF8F1F1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF352A3B)
                : const Color(0xFFE5E5EA),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? defaultColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveConstants.getBodyFontSize(context),
                fontWeight: FontWeight.w400,
                color: textColor ?? defaultColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to show the settings menu
void showReaderSettingsMenu({
  required BuildContext context,
  required String filePath,
  required ReaderLayoutMode currentLayoutMode,
  required Function(ReaderLayoutMode) onLayoutModeChanged,
  bool showFacingOption = false,
  bool showLongStripOption = false,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: ReaderSettingsMenu(
        filePath: filePath,
        currentLayoutMode: currentLayoutMode,
        onLayoutModeChanged: onLayoutModeChanged,
        onClose: () => Navigator.pop(context),
        showFacingOption: showFacingOption,
        showLongStripOption: showLongStripOption,
      ),
    ),
  );
}

// Helper function to convert between different layout mode types
ReaderLayoutMode convertToReaderLayoutMode(dynamic layoutMode) {
  if (layoutMode.toString().contains('facing')) {
    return ReaderLayoutMode.facing;
  } else if (layoutMode.toString().contains('horizontal')) {
    return ReaderLayoutMode.horizontal;
  } else if (layoutMode.toString().contains('longStrip') ||
      layoutMode.toString().contains('long')) {
    return ReaderLayoutMode.longStrip;
  } else {
    return ReaderLayoutMode.vertical;
  }
}
