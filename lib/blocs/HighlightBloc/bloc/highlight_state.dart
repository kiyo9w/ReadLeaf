part of 'highlight_bloc.dart';

abstract class HighlightState extends Equatable {
  const HighlightState();

  @override
  List<Object> get props => [];
}
  
class HighlightInitial extends HighlightState {}

class HighlightLoaded extends HighlightState {
  final Map<int, List<String>> highlights;

  const HighlightLoaded(this.highlights);

  @override
  List<Object> get props => [highlights];
}

class HighlightError extends HighlightState {
  final String message;

  const HighlightError(this.message);

  @override
  List<Object> get props => [message];
}