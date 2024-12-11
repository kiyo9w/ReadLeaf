part of 'highlight_bloc.dart';

abstract class HighlightEvent extends Equatable {
  const HighlightEvent();

  @override
  List<Object> get props => [];
}

class AddHighlight extends HighlightEvent {
  final String text;
  final int pageIndex;

  const AddHighlight(this.text, this.pageIndex);

  @override
  List<Object> get props => [text, pageIndex];
}

class RemoveHighlight extends HighlightEvent {
  final String text;
  final int pageIndex;

  const RemoveHighlight(this.text, this.pageIndex);

  @override
  List<Object> get props => [text, pageIndex];
}

class ClearHighlights extends HighlightEvent {
  // Call remove for all highlights
}