// AI generated animation
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class PullToRefreshAnimation extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Function(double)? onPull;

  const PullToRefreshAnimation({
    Key? key,
    required this.child,
    required this.onRefresh,
    this.onPull,
  }) : super(key: key);

  @override
  _PullToRefreshAnimationState createState() => _PullToRefreshAnimationState();
}

class _PullToRefreshAnimationState extends State<PullToRefreshAnimation>
    with TickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isRefreshing = false;

  /// Tracks if we've already triggered the pop effect when crossing the threshold.
  bool _hasTriggeredPop = false;

  late AnimationController _refreshController;
  late AnimationController _pullCompleteController;

  @override
  void initState() {
    super.initState();
    // Animates the "wave" effect while refreshing.
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // Base scale from 1.0 to 1.3, with a quick pop up to 1.5 on threshold.
    _pullCompleteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 1.0,
      upperBound: 1.3,
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _pullCompleteController.dispose();
    super.dispose();
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    // Animate back-and-forth wave while refreshing.
    _refreshController.repeat(reverse: true);

    // Perform the refresh logic.
    await widget.onRefresh();

    // Reset once done.
    _refreshController.reset();
    setState(() {
      _isRefreshing = false;
      _dragOffset = 0.0;
      _hasTriggeredPop = false;
    });
  }

  void _updateDragOffset(double offset) {
    if (_isRefreshing) return;

    final threshold = _currentThreshold(context);
    final newOffset = offset < 0 ? -offset : 0;

    setState(() {
      _dragOffset = newOffset.toDouble();
    });

    // Notify parent about drag offset
    widget.onPull?.call(_dragOffset);

    // Trigger the pop effect once if crossing the threshold.
    if (!_hasTriggeredPop && _dragOffset >= threshold) {
      _hasTriggeredPop = true;
      // Briefly scale from 1.3 to 1.5, then back.
      _pullCompleteController
          .animateTo(
        1.5,
        duration: const Duration(milliseconds: 120),
      )
          .then((_) {
        _pullCompleteController.animateTo(
          1.3,
          duration: const Duration(milliseconds: 120),
        );
      });
      HapticFeedback.lightImpact();
    }
  }

  void _onScrollEnd() {
    // If user has pulled enough, start refresh; else reset.
    if (!_isRefreshing && _dragOffset >= _currentThreshold(context)) {
      _startRefresh();
    } else {
      setState(() {
        _dragOffset = 0.0;
        _hasTriggeredPop = false;
      });
    }
  }

  // User must pull down 1/6 of screen height to trigger refresh.
  double _currentThreshold(BuildContext context) =>
      MediaQuery.of(context).size.height / 6;

  @override
  Widget build(BuildContext context) {
    final threshold = _currentThreshold(context);
    // progress = how far we are (0..1) toward threshold
    final progress = (_dragOffset / threshold).clamp(0.0, 1.5);

    // Content moves down up to ~40 px.
    final offsetY = 40 * (progress <= 1 ? progress : 1 + (progress - 1) * 0.1);

    // Icon grows from 1.0 → 1.3 as user drags, times the pullCompleteController.
    final scale =
        (1 + min(progress, 1.0) * 0.3) * _pullCompleteController.value;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification && !_isRefreshing) {
          final pixels = notification.metrics.pixels;
          if (pixels < 0) {
            _updateDragOffset(pixels);
          } else {
            _updateDragOffset(0);
          }
        }
        if (notification is ScrollEndNotification) {
          _onScrollEnd();
        }
        return false;
      },
      child: Stack(
        children: [
          // The main content, moved down while dragging.
          Transform.translate(
            offset: Offset(0, offsetY),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
              ),
              child: widget.child,
            ),
          ),
          // Our custom pull-to-refresh icon.
          if (_dragOffset > 0 || _isRefreshing)
            Positioned(
              top: 24 + offsetY,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _refreshController,
                  builder: (context, child) {
                    final pathAnimValue =
                        _isRefreshing ? _refreshController.value : 0.0;
                    return Transform.scale(
                      scale: scale,
                      child: CustomPaint(
                        size: const Size(33, 33),
                        painter: _AppIconPainter(
                          progress: progress,
                          pathAnimationValue: pathAnimValue,
                          context: context,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// This painter first draws the entire shape in grey (silhouette),
// then draws the partial "traced" portion in white.
class _AppIconPainter extends CustomPainter {
  final double progress;
  final double pathAnimationValue;
  final BuildContext context;

  // Use grey for silhouette, but primary color will come from theme
  static final Color _silhouetteColor = Colors.grey.shade500;

  _AppIconPainter({
    required this.progress,
    required this.pathAnimationValue,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Get primary color from theme
    final Color _traceColor = Theme.of(context).primaryColor;

    // 1) Combine all paths, applying the <g> transform from your SVG.
    final Matrix4 groupTransform = Matrix4.identity()
      ..translate(0.0, 640.0)
      ..scale(0.1, -0.1);

    final Path combinedPath = Path();
    for (final d in _allSvgPaths) {
      final rawPath = parseSvgPathData(d);
      final transformed = rawPath.transform(groupTransform.storage);
      combinedPath.addPath(transformed, Offset.zero);
    }

    // 2) Scale + center that shape into our 66×66 space.
    final Rect originalBounds = combinedPath.getBounds();
    final double scaleFactor = min(
      size.width / originalBounds.width,
      size.height / originalBounds.height,
    );

    final Matrix4 toOrigin = Matrix4.identity()
      ..translate(-originalBounds.left, -originalBounds.top);
    final Matrix4 scaleMatrix = Matrix4.identity()
      ..scale(scaleFactor, scaleFactor);
    final Path scaledPath =
        combinedPath.transform(toOrigin.storage).transform(scaleMatrix.storage);

    final Rect scaledBounds = scaledPath.getBounds();
    final Offset centerOffset = Offset(
      (size.width - scaledBounds.width) / 2,
      (size.height - scaledBounds.height) / 2,
    );
    final Path finalPath = scaledPath.shift(centerOffset);

    // 3) We'll compute total length so we can extract a partial path.
    final List<PathMetric> metrics = finalPath.computeMetrics().toList();
    final double totalLength = metrics.fold(0.0, (sum, m) => sum + m.length);

    // The partial line grows with a power curve for slower start.
    final double drawProgress = pow(progress.clamp(0.0, 1.0), 1.5).toDouble();
    final double drawnLength = totalLength * drawProgress;

    // Build the partial path for the "traced" portion.
    final Path tracedPath = Path();
    double remaining = drawnLength;
    for (final m in metrics) {
      if (remaining <= 0) break;
      final double draw = min(remaining, m.length);
      tracedPath.addPath(m.extractPath(0, draw), Offset.zero);
      remaining -= draw;
    }

    // 4) Draw the full silhouette in grey first.
    final Paint silhouettePaint = Paint()
      ..color = _silhouetteColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(finalPath, silhouettePaint);

    // 5) Draw the partial trace in white on top of the grey silhouette.
    final Paint tracePaint = Paint()
      ..color = _traceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(tracedPath, tracePaint);

    // 6) If refreshing, overlay an additional wave for the animated portion.
    if (pathAnimationValue > 0) {
      final double animLength = totalLength * pathAnimationValue;
      final Path wavePath = Path();
      double remainingAnim = animLength;
      for (final m in metrics) {
        if (remainingAnim <= 0) break;
        final double draw = min(remainingAnim, m.length);
        wavePath.addPath(m.extractPath(0, draw), Offset.zero);
        remainingAnim -= draw;
      }

      final Paint wavePaint = Paint()
        ..color = _traceColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(wavePath, wavePaint);
    }
  }

  @override
  bool shouldRepaint(_AppIconPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pathAnimationValue != pathAnimationValue;
  }
}

// All <path> elements from your SVG, unchanged.
final List<String> _allSvgPaths = [
  // Path #1
  "M3900 5953 c-659 -35 -1293 -231 -1759 -544 -513 -343 -822 -805 "
      "-938 -1399 -24 -122 -26 -158 -27 -370 0 -201 3 -254 22 -365 38 -215 105 "
      "-421 193 -596 78 -157 209 -342 249 -352 24 -6 70 31 70 57 0 18 126 363 174 "
      "475 50 117 175 346 261 476 181 274 374 505 660 790 269 270 477 447 685 585 "
      "77 50 65 39 -130 -137 -649 -583 -1157 -1274 -1453 -1978 -79 -188 -83 -202 "
      "-61 -226 20 -22 47 -25 62 -6 5 6 26 55 47 107 101 257 308 645 488 915 345 "
      "517 880 1080 1405 1479 86 66 102 82 102 106 0 72 -50 65 -253 -38 -296 -150 "
      "-564 -353 -898 -680 -589 -576 -954 -1124 -1124 -1688 -15 -49 -31 -93 -35 "
      "-98 -11 -11 -118 152 -175 264 -92 184 -163 417 -191 633 -20 152 -15 476 10 "
      "612 56 309 182 603 363 845 100 135 300 336 430 433 493 364 1108 567 1852 "
      "609 232 13 488 2 726 -31 l120 -16 22 -135 c57 -351 84 -700 84 -1088 1 -412 "
      "-26 -724 -91 -1057 -43 -215 -147 -565 -169 -565 -4 0 -47 9 -96 19 -50 11 "
      "-130 25 -178 31 -80 11 -90 10 -108 -6 -45 -41 -8 -78 87 -88 67 -7 226 -33 "
      "252 -41 29 -10 -164 -339 -288 -490 -79 -97 -250 -258 -349 -329 -164 -117 "
      "-378 -209 -601 -257 -90 -20 -135 -23 -315 -23 -225 -1 -321 12 -515 68 l-85 "
      "25 -240 -151 c-431 -272 -679 -430 -738 -470 -32 -22 -61 -38 -63 -35 -3 3 62 "
      "187 146 408 83 222 150 412 148 423 -2 10 -11 24 -20 30 -29 18 -50 -4 -80 "
      "-80 -27 -68 -284 -748 -314 -831 l-16 -43 -624 0 -624 0 0 -45 0 -45 636 0 "
      "636 0 296 189 c163 103 426 270 585 370 l287 182 65 -20 c169 -53 277 -66 520 "
      "-65 199 0 244 3 335 23 367 78 701 273 946 551 99 112 239 323 311 468 32 64 "
      "58 118 59 120 3 8 193 -67 279 -110 155 -78 261 -153 376 -268 110 -109 181 "
      "-204 241 -325 106 -210 144 -460 99 -637 -37 -142 -103 -240 -226 -333 -73 "
      "-54 -85 -74 -66 -104 17 -26 112 -32 569 -38 l452 -5 0 46 0 46 -353 0 c-195 "
      "0 -388 3 -430 6 l-76 7 63 68 c70 75 127 179 153 279 23 87 23 305 -1 408 -72 "
      "323 -263 605 -541 800 -105 74 -282 165 -411 211 l-91 33 33 89 c103 273 181 "
      "671 215 1104 15 189 15 668 0 885 -19 271 -82 775 -107 852 -7 22 -48 33 -204 "
      "52 -254 32 -514 42 -750 29z",
  // Path #2
  "M3129 3116 c-70 -48 -85 -148 -32 -214 57 -71 151 -80 218 -21 65 57 "
      "68 153 7 214 -52 53 -133 61 -193 21z",
  // Path #3
  "M3542 2999 c-93 -37 -143 -138 -87 -175 74 -49 225 34 225 124 0 48 "
      "-76 76 -138 51z",
  // Path #4
  "M3795 1766 c-17 -12 -18 -19 -8 -73 26 -140 103 -284 208 -389 148 "
      "-148 366 -238 678 -279 134 -17 408 -20 438 -5 21 12 26 52 7 68 -7 5 -104 12 "
      "-218 15 -288 7 -471 43 -645 126 -197 94 -306 222 -371 436 -36 120 -47 132 "
      "-89 101z",
  // Path #5
  "M4652 1760 c-68 -64 -7 -174 82 -149 100 28 82 169 -22 169 -25 0 "
      "-46 -7 -60 -20z",
  // Path #6
  "M5129 1767 c-67 -52 -32 -157 53 -157 52 0 88 35 88 85 0 50 -36 85 "
      "-87 85 -21 0 -45 -6 -54 -13z",
];
