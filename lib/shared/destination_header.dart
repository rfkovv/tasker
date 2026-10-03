import 'package:flutter/material.dart';

import 'hide_on_scroll_header.dart';

/// Unified destination header hierarchy.
///
/// Row 1 (very top): screen title — the destination name (i18n, supplied
/// by the caller via [title]).
///
/// Row 2 (only if [toolbar] is provided): the controls toolbar — ONLY the
/// controls that belong to that menu (tasks: Lista|Kalendarz + Filtruj;
/// contacts: its filter control; settings: none).
///
/// Scroll behavior:
/// - [hideOnScroll] true (portrait mobile): title AND toolbar hide
///   TOGETHER on scroll down and reappear on scroll up
///   ([HideOnScrollHeader]).
/// - [hideOnScroll] false (desktop, compact chrome-less callers): both
///   rows static, always visible.
///
/// Compact callers pass [showTitle] false (toolbar only — unchanged
/// compact chrome). The floating search trigger is NOT part of this
/// widget; screens overlay [FloatingSearchButton] on their content Stack.
class DestinationBody extends StatelessWidget {
  const DestinationBody({
    super.key,
    required this.title,
    required this.child,
    this.toolbar,
    this.hideOnScroll = false,
    this.showTitle = true,
  });

  /// Destination name (l10n) rendered in the title row.
  final String title;

  /// Menu-specific controls row. Null → no toolbar (e.g. Settings).
  final Widget? toolbar;

  /// Scrollable content area; receives the remaining height.
  final Widget child;

  /// True in portrait mobile: title + toolbar hide/show on scroll.
  /// False on desktop (static) and for compact chrome-less headers.
  final bool hideOnScroll;

  /// False in compact mode (no title row — toolbar only).
  final bool showTitle;

  Widget _header(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              key: const Key('destination-title'),
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (toolbar != null) ...[
          toolbar!,
          const Divider(height: 1),
        ] else if (showTitle)
          const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = _header(context);
    if (hideOnScroll) {
      return HideOnScrollHeader(header: header, child: child);
    }
    return Column(
      children: [
        header,
        Expanded(child: child),
      ],
    );
  }
}
