# ReadLeaf UI Updates

This document provides instructions for implementing the UI updates to the PDF and EPUB viewers.

## Changes Made

1. Created a unified settings menu widget (`ReaderSettingsMenu`) in `lib/widgets/reader/reader_settings_menu.dart`
2. Updated the PDF viewer to use the new settings menu
3. Created a template for updating the EPUB viewer

## Implementation Steps

### 1. PDF Viewer Updates

The PDF viewer has been updated to use the new settings menu. The changes include:
- Replaced the old popup menu with the new settings menu
- Improved the UI for a cleaner, more modern look

### 2. EPUB Viewer Updates

To update the EPUB viewer, you need to:

1. Replace the popup menu button with the settings menu button:
   ```dart
   IconButton(
     icon: Icon(
       Icons.more_vert,
       color: Theme.of(context).brightness == Brightness.dark
           ? const Color(0xFFF2F2F7)
           : const Color(0xFF1C1C1E),
       size: ResponsiveConstants.getIconSize(context),
     ),
     onPressed: () {
       showReaderSettingsMenu(
         context: context,
         filePath: state.file.path,
         currentLayoutMode: convertToReaderLayoutMode(_layoutMode),
         onLayoutModeChanged: (mode) {
           Navigator.pop(context); // Close the menu
           
           switch (mode) {
             case ReaderLayoutMode.vertical:
               _handleLayoutChange(EpubLayoutMode.vertical);
               break;
             case ReaderLayoutMode.horizontal:
               _handleLayoutChange(EpubLayoutMode.horizontal);
               break;
             case ReaderLayoutMode.longStrip:
               _handleLayoutChange(EpubLayoutMode.longStrip);
               break;
             default:
               _handleLayoutChange(EpubLayoutMode.vertical);
           }
         },
         showLongStripOption: true,
       );
     },
     padding: EdgeInsets.all(
         ResponsiveConstants.isTablet(context) ? 12 : 8),
   )
   ```

2. Add the floating chat widget to the Stack in the build method, right before the closing of the Stack:
   ```dart
   // Floating chat widget
   FloatingChatWidget(
     character: _characterService.getSelectedCharacter() ??
         AiCharacter(
           name: 'Amelia',
           avatarImagePath:
               'assets/images/ai_characters/amelia.png',
           personality: 'A friendly and helpful AI assistant.',
           summary:
               'Amelia is a friendly AI assistant who helps readers understand and engage with their books.',
           scenario:
               'You are reading with Amelia, who is eager to help you understand and enjoy your book.',
           greetingMessage:
               'Hello! I\'m Amelia. How can I help you with your reading today?',
           exampleMessages: [
             'Can you explain this passage?',
             'What are your thoughts on this chapter?',
             'Help me understand the main themes.'
           ],
           characterVersion: '1',
           tags: ['Default', 'Reading Assistant'],
           creator: 'ReadLeaf',
           createdAt: DateTime.now(),
           updatedAt: DateTime.now(),
         ),
     onSendMessage: _handleChatMessage,
     bookId: state.file.path,
     bookTitle: _epubBook?.Title ?? path.basename(state.file.path),
     key: _floatingChatKey,
   )
   ```

## UI Design Principles

The new settings menu follows these design principles:
- Clean, modern, and aesthetically pleasing
- Consistent with the app's existing design language
- Intuitive and easy to use
- Responsive to different screen sizes

The menu is organized into sections:
1. Page Layout - Options for how pages are displayed
2. Reading Mode - Light, dark, and sepia modes
3. File Actions - Share, star, mark as read, and delete options

## Next Steps

1. Implement the EPUB viewer updates as described above
2. Test the UI on different devices to ensure responsiveness
3. Consider adding additional features to the settings menu as needed 