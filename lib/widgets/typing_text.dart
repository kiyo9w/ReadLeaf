import 'package:flutter/material.dart';
import 'dart:async';

class TypingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final Duration typingSpeed;
  final VoidCallback? onTypingComplete;
  final bool skipAnimation;

  const TypingText({
    Key? key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.typingSpeed = const Duration(milliseconds: 15),
    this.onTypingComplete,
    this.skipAnimation = false,
  }) : super(key: key);

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  late String _displayText;
  late Timer _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _displayText = widget.skipAnimation ? widget.text : '';
    if (!widget.skipAnimation) {
      _startTyping();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTypingComplete?.call();
      });
    }
  }

  void _startTyping() {
    if (widget.text.isEmpty) {
      widget.onTypingComplete?.call();
      return;
    }

    _timer = Timer.periodic(widget.typingSpeed, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayText = widget.text.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        _timer.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onTypingComplete?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    if (!widget.skipAnimation) {
      _timer.cancel();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _currentIndex = 0;
      if (widget.skipAnimation) {
        _displayText = widget.text;
        widget.onTypingComplete?.call();
      } else {
        _displayText = '';
        _startTyping();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
