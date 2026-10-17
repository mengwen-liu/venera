import 'package:flutter/material.dart';
import 'package:venera/foundation/ui_tokens.dart';

/// Pure presentation widgets for the Home refresh (UI Refresh v0.1, UX-01).
///
/// Everything here receives immutable display data and callbacks from the
/// caller. These widgets do not read storage, the network or comic sources,
/// do not navigate, and translate nothing: all strings come from the caller.
///
/// "Pure" means the widgets themselves have no storage or network dependency.
/// An [ImageProvider] supplied by the caller may still perform I/O (for
/// example a `NetworkImage`); tests should pass deterministic providers.

/// Reading progress within the current chapter.
@immutable
class ReadingProgress {
  const ReadingProgress._(this.page, this.total);

  /// 1-based page the reader stopped at.
  final int page;

  /// Number of pages in the chapter. Always greater than zero.
  final int total;

  /// `page / total`, between 0 and 1.
  double get fraction => (page / total).clamp(0.0, 1.0).toDouble();

  /// Returns null when the data cannot describe a progress: a missing or
  /// non-positive [maxPage], a [page] that is missing or below 1, or a [page]
  /// above [maxPage].
  ///
  /// A [page] above [maxPage] is treated as invalid (for example a stale
  /// record after the chapter got shorter), so it is never shown as a
  /// completed chapter. [page] equal to [maxPage] is valid.
  static ReadingProgress? tryCreate({int? page, int? maxPage}) {
    if (page == null || maxPage == null) return null;
    if (page < 1 || maxPage < 1) return null;
    if (page > maxPage) return null;
    return ReadingProgress._(page, maxPage);
  }
}

/// Display data of [RecentComicCard].
@immutable
class RecentComicCardData {
  const RecentComicCardData({
    required this.title,
    this.detailLine,
    this.sourceLabel,
    this.progress,
    this.progressLabel,
    this.cover,
  });

  final String title;

  /// For example "Chapter 3 - Page 8". Hidden when null or empty.
  final String? detailLine;

  /// Name of the comic source. Hidden when null or empty.
  final String? sourceLabel;

  /// The progress bar and [progressLabel] are only shown when this is not null.
  final ReadingProgress? progress;

  final String? progressLabel;

  /// A missing cover shows a placeholder.
  final ImageProvider? cover;

  /// One spoken sentence for assistive technologies.
  String semanticsLabel({String? prefix}) {
    return [
      prefix,
      title,
      detailLine,
      sourceLabel,
      if (progress != null) progressLabel,
    ].whereType<String>().where((e) => e.isNotEmpty).join(', ');
  }
}

/// Comic cover with a placeholder for a missing, loading or broken image.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    this.image,
    this.width = UiSize.coverWidth,
    this.height = UiSize.coverHeight,
  });

  final ImageProvider? image;

  final double width;

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Center(
      child: Icon(Icons.menu_book_outlined, color: scheme.uiOnCoverFill),
    );
    final provider = image;
    final Widget child;
    if (provider == null) {
      child = placeholder;
    } else {
      child = Image(
        image: provider,
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          return wasSynchronouslyLoaded || frame != null ? child : placeholder;
        },
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.uiCoverFill,
          borderRadius: BorderRadius.circular(UiRadius.cover),
        ),
        child: child,
      ),
    );
  }
}

/// Section title with an optional count badge and an optional action.
class HomeSectionHeading extends StatelessWidget {
  const HomeSectionHeading({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
  });

  final String title;

  final int? count;

  /// The action is shown only when both [actionLabel] and [onAction] are set.
  final String? actionLabel;

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = actionLabel;
    final onAction = this.onAction;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: UiSize.minTouchTarget),
      // LayoutBuilder bounds the action to half of the row, so a long label
      // wraps instead of overflowing. It does not support intrinsic sizing.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: UiSpace.s2,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: theme.textTheme.uiSectionTitle?.copyWith(
                          color: scheme.uiTextPrimary,
                        ),
                      ),
                    ),
                    if (count != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.uiBadgeFill,
                          borderRadius: BorderRadius.circular(UiSpace.s2),
                        ),
                        child: Text(
                          count.toString(),
                          style: theme.textTheme.uiCaption?.copyWith(
                            color: scheme.uiOnBadge,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (label != null && onAction != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth / 2,
                  ),
                  child: TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        UiSize.minTouchTarget,
                        UiSize.minTouchTarget,
                      ),
                    ),
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Card for a recently read comic: cover, title, detail, progress and an
/// optional action button.
class RecentComicCard extends StatelessWidget {
  const RecentComicCard({
    super.key,
    required this.data,
    this.onTap,
    this.actionLabel,
    this.onAction,
    this.semanticsPrefix,
  });

  final RecentComicCardData data;

  /// Tapping the cover and text area. The card is not interactive when null.
  final VoidCallback? onTap;

  /// The action button is shown only when both [actionLabel] and [onAction]
  /// are set. It is separate from [onTap].
  final String? actionLabel;

  final VoidCallback? onAction;

  /// Spoken before the comic title, for example "Continue reading".
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final detailLine = data.detailLine;
    final sourceLabel = data.sourceLabel;
    final progress = data.progress;
    final progressLabel = data.progressLabel;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    final secondary = textTheme.uiCaption?.copyWith(
      color: scheme.uiTextSecondary,
    );

    final content = Padding(
      padding: const EdgeInsets.all(UiSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoverImage(image: data.cover),
          const SizedBox(width: UiSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.uiItemTitle?.copyWith(
                    color: scheme.uiTextPrimary,
                  ),
                ),
                if (detailLine != null && detailLine.isNotEmpty) ...[
                  const SizedBox(height: UiSpace.s1),
                  Text(
                    detailLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: secondary,
                  ),
                ],
                if (sourceLabel != null && sourceLabel.isNotEmpty) ...[
                  const SizedBox(height: UiSpace.s1),
                  Text(
                    sourceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: secondary,
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: UiSpace.s3),
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(UiSpace.s1),
                      child: LinearProgressIndicator(
                        value: progress.fraction,
                        minHeight: UiSpace.s1,
                        color: scheme.uiProgressIndicator,
                        backgroundColor: scheme.uiProgressTrack,
                      ),
                    ),
                  ),
                  if (progressLabel != null && progressLabel.isNotEmpty) ...[
                    const SizedBox(height: UiSpace.s1),
                    Text(progressLabel, style: secondary),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: scheme.uiCardFill,
      borderRadius: BorderRadius.circular(UiRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            button: onTap != null,
            label: data.semanticsLabel(prefix: semanticsPrefix),
            onTap: onTap,
            excludeSemantics: true,
            child: InkWell(onTap: onTap, child: content),
          ),
          if (actionLabel != null && onAction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UiSpace.s4,
                0,
                UiSpace.s4,
                UiSpace.s4,
              ),
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(UiSize.minTouchTarget),
                ),
                child: Text(actionLabel),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty state with an optional call to action.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;

  final String message;

  /// The button is shown only when both [actionLabel] and [onAction] are set.
  final String? actionLabel;

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(UiSpace.s6),
      decoration: BoxDecoration(
        color: scheme.uiCardFill,
        borderRadius: BorderRadius.circular(UiRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: UiSpace.s8 + UiSpace.s2,
            color: scheme.uiTextSecondary,
          ),
          const SizedBox(height: UiSpace.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.uiBody?.copyWith(
              color: scheme.uiTextPrimary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: UiSpace.s4),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  UiSize.minTouchTarget,
                  UiSize.minTouchTarget,
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

/// Static loading placeholder with the footprint of a [RecentComicCard].
///
/// It has no animation, so it needs no reduced-motion handling.
class HomeCardPlaceholder extends StatelessWidget {
  const HomeCardPlaceholder({
    super.key,
    this.height = UiSize.coverHeight + 2 * UiSpace.s4,
    this.semanticsLabel,
  });

  final double height;

  /// Spoken label such as "Loading". The placeholder is silent when null.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.uiCardFill,
        borderRadius: BorderRadius.circular(UiRadius.card),
      ),
    );
    final label = semanticsLabel;
    if (label == null) return ExcludeSemantics(child: box);
    return Semantics(container: true, label: label, child: box);
  }
}
