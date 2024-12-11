import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'highlight_event.dart';
part 'highlight_state.dart';

class HighlightBloc extends Bloc<HighlightEvent, HighlightState> {
  HighlightBloc() : super(HighlightInitial());

  final Map<int, List<String>> _highlights = {};

  @override
  Stream<HighlightState> mapEventToState(HighlightEvent event) async* {
    try {
      if (event is AddHighlight) {
        _highlights.putIfAbsent(event.pageIndex, () => []);
        _highlights[event.pageIndex]?.add(event.text);
        yield HighlightLoaded(Map.from(_highlights));
      } else if (event is RemoveHighlight) {
        if (_highlights.containsKey(event.pageIndex)) {
          _highlights[event.pageIndex]?.remove(event.text);
          if (_highlights[event.pageIndex]?.isEmpty ?? false) {
            _highlights.remove(event.pageIndex);
          }
        }
        yield HighlightLoaded(Map.from(_highlights));
      } else if (event is ClearHighlights) {
        _highlights.clear();
        yield HighlightLoaded(Map.from(_highlights));
      }
    } catch (e) {
      yield HighlightError("An error occurred: ${e.toString()}");
    }
  }
}