import 'package:flutter/material.dart';

/// Shared hide-on-scroll header (floating app-bar behavior).
///
/// Wraps a toolbar [header] above a vertically scrollable [child]:
/// the header collapses when the scrollable below scrolls down and
/// reappears when it scrolls up. This is the SINGLE place in the app
/// where scroll-hide toolbar logic lives — screens must not fork it.
///
/// The [child] is placed in an [Expanded] slot, so this widget must sit
/// directly under a flex parent such as a [Column] inside a [Scaffold].
class HideOnScrollHeader extends StatefulWidget {
  const HideOnScrollHeader({
    super.key,
    required this.header,
    required this.child,
  });

  /// Chrome that hides/shows on scroll (toolbar row + optional divider).
  final Widget header;

  /// Scrollable content area; receives the remaining height.
  final Widget child;

  @override
  State<HideOnScrollHeader> createState() => _HideOnScrollHeaderState();
}

class _HideOnScrollHeaderState extends State<HideOnScrollHeader> {
  double _lastPixels = 0;
  bool _visible = true;

  bool _onScroll(ScrollNotification notification) {
    // Only the outermost vertical scrollable directly below the header.
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final pixels = notification.metrics.pixels;
    if (pixels > _lastPixels && pixels > 0) {
      // Scrolling down (content moving up) → hide.
      if (_visible) setState(() => _visible = false);
    } else if (pixels < _lastPixels) {
      // Scrolling up → show.
      if (!_visible) setState(() => _visible = true);
    }
    _lastPixels = pixels;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Column(
        children: [
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _visible
                  ? widget.header
                  : const SizedBox(width: double.infinity),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
