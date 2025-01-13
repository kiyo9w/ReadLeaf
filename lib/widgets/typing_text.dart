import 'package:flutter/material.dart';
import 'dart:async';

class TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration typingSpeed;
  final bool startTyping;
  final int? maxLines;
  final TextOverflow? overflow;

  const TypingText({
    required this.text,
    required this.style,
    this.typingSpeed = const Duration(milliseconds: 50),
    this.startTyping = true,
    this.maxLines,
    this.overflow,
    Key? key,
  }) : super(key: key);

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  late String _displayText;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _displayText = '';
    if (widget.startTyping) {
      _startTyping();
    } else {
      _displayText = widget.text;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.typingSpeed, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayText += widget.text[_currentIndex];
          _currentIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow ??
          (widget.maxLines != null ? TextOverflow.ellipsis : null),
    );
  }
}
