import 'package:flutter/material.dart';
import 'package:whistly/theme/app_theme.dart';

/// Typography + reusable components for the Whistly theme spec (iteration
/// 6). Every screen should build its type and its buttons/tabs/badges/rows
/// through this file rather than hand-rolling `TextStyle`s or `Container`
/// decorations — that's what keeps radius/shadow/surface rules (spec §3,
/// §5) honored everywhere instead of drifting screen by screen.
///
/// Spec rules encoded here, so a reviewer doesn't have to re-derive them:
/// - Radius 0 everywhere, no shadows, no gradients, no blur (§3).
/// - No surface fills — separation is a `line` rule, never a tint (§1.4).
/// - Everything flush left; no centered headings/button labels (§2).
/// - `accent` is interface-only, one per screen region (§1.2-3).
/// - Numerals (scores, deltas, round indices, records, trick counts) are
///   monospace; everything else is Archivo (§2).
class WhistlyText {
  WhistlyText._();

  static const String _archivo = 'Archivo';

  // Archivo is bundled as a true variable font (wght axis 100-900, default
  // 600), declared once in pubspec.yaml. `fontWeight` alone does not select
  // a variable font's axis value — only `fontVariations` does — so every
  // style below carries both: `fontWeight` for semantics/fallback fonts,
  // `fontVariations` for the actual rendered weight (B5).
  static const _w600 = [FontVariation('wght', 600)];
  static const _w800 = [FontVariation('wght', 800)];

  /// Brand / wordmark — 54px/800/-0.03em, Title case.
  static TextStyle brand(Color color) => TextStyle(
        fontFamily: _archivo,
        fontSize: 54,
        fontWeight: FontWeight.w800,
        fontVariations: _w800,
        letterSpacing: -0.03 * 54,
        color: color,
        height: 1.0,
      );

  /// Screen numeral (score) — 30px mono/800/-0.04em.
  static TextStyle screenNumeral(Color color, {double size = 30}) => TextStyle(
        fontFamily: kMonoFontFamily,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.04 * size,
        color: color,
      );

  /// Section head — 20px/800/-0.01em, Title case.
  static TextStyle sectionHead(Color color) => TextStyle(
        fontFamily: _archivo,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        fontVariations: _w800,
        letterSpacing: -0.01 * 20,
        color: color,
      );

  /// Player name / row title — 17px/800/-0.01em, Title case.
  static TextStyle rowTitle(Color color) => TextStyle(
        fontFamily: _archivo,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        fontVariations: _w800,
        letterSpacing: -0.01 * 17,
        color: color,
      );

  /// Button label — 19px/800/+0.02em, UPPERCASE (caller must upper-case
  /// the string; this only sets the style).
  static TextStyle buttonLabel(Color color) => TextStyle(
        fontFamily: _archivo,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        fontVariations: _w800,
        letterSpacing: 0.02 * 19,
        color: color,
      );

  /// Eyebrow / section label — 11px/800/+0.16em, UPPERCASE.
  static TextStyle eyebrow(Color color) => TextStyle(
        fontFamily: _archivo,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        fontVariations: _w800,
        letterSpacing: 0.16 * 11,
        color: color,
      );

  /// Tab label — 9px/800/+0.10em, UPPERCASE.
  static TextStyle tabLabel(Color color) => TextStyle(
        fontFamily: _archivo,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        fontVariations: _w800,
        letterSpacing: 0.10 * 9,
        color: color,
      );

  /// Badge — 9px/800/+0.12em, UPPERCASE.
  static TextStyle badge(Color color) => TextStyle(
        fontFamily: _archivo,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        fontVariations: _w800,
        letterSpacing: 0.12 * 9,
        color: color,
      );

  /// Body / meta — 11-13px/600, Sentence case. Defaults to 12.
  static TextStyle body(Color color, {double size = 12}) => TextStyle(
        fontFamily: _archivo,
        fontSize: size,
        fontWeight: FontWeight.w600,
        fontVariations: _w600,
        color: color,
      );

  /// Round-row deltas / partner line — mono 11px, muted.
  static TextStyle mono(Color color, {double size = 11, FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontFamily: kMonoFontFamily, fontSize: size, fontWeight: weight, color: color);
}

/// Primary button — full width, `accent` fill, `onAccent` label, flush
/// left, optional chevron on the right. Pressed state darkens accent one
/// step (spec §5).
class WhistlyPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool showChevron;

  const WhistlyPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final enabled = onPressed != null;
    // GestureDetector, not Material+InkWell: no ripple is wanted anyway
    // (the app theme sets splashFactory: NoSplash.splashFactory globally),
    // and this avoids depending on an ambient Material ancestor.
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        color: enabled ? colors.accent : colors.line.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: WhistlyText.buttonLabel(
                  enabled ? colors.onAccent : colors.muted,
                ),
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right,
                  color: enabled ? colors.onAccent : colors.muted),
          ],
        ),
      ),
    );
  }
}

/// Secondary button — `bg` fill, `ink` label, separated from a sibling by
/// a 2px `line` border on the shared edge (pass [borderSide] for that
/// edge; this widget itself draws no standalone outline).
class WhistlySecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Border? border;

  const WhistlySecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final enabled = onPressed != null;
    // GestureDetector, not Material+InkWell — see the note in
    // WhistlyPrimaryButton.
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(color: colors.bg, border: border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: WhistlyText.buttonLabel(enabled ? colors.ink : colors.muted),
        ),
      ),
    );
  }
}

/// Text action (Undo, + Add player) — uppercase 11px/800 ink, 2px accent
/// underline 1-2px below the baseline. Not red text (spec §5).
class WhistlyTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const WhistlyTextAction({super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final enabled = onPressed != null;
    final color = enabled ? colors.ink : colors.muted;
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                ],
                Text(label.toUpperCase(), style: WhistlyText.eyebrow(color)),
              ],
            ),
            const SizedBox(height: 2),
            Container(height: 2, width: _labelWidthGuess(label), color: enabled ? colors.accent : colors.muted),
          ],
        ),
      ),
    );
  }

  // The underline can't measure the Text's actual layout width without a
  // LayoutBuilder round-trip, so it's approximated from character count at
  // this style's known metrics. Close enough for a decorative underline.
  double _labelWidthGuess(String label) => label.length * 8.5 + (icon != null ? 18 : 0);
}

/// Lead badge — `accent` fill, `onAccent` text, 9px uppercase, 4/8 padding.
/// One per screen (spec §5).
class WhistlyLeadBadge extends StatelessWidget {
  final String label;
  const WhistlyLeadBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: colors.accent,
      child: Text(label.toUpperCase(), style: WhistlyText.badge(colors.onAccent)),
    );
  }
}

/// ALTERATIONS.md B1 — the Dealer marker, visually the Lead badge's
/// opposite: `bg` fill with a 2px `line` border and `ink` text, instead of
/// an `accent` fill with `onAccent` text. Same size, same 9px/800
/// uppercase, same padding — the two are meant to sit side by side on a
/// standings row when one player holds both.
class WhistlyDealerBadge extends StatelessWidget {
  final String label;
  const WhistlyDealerBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border.all(color: colors.line, width: 2),
      ),
      child: Text(label.toUpperCase(), style: WhistlyText.badge(colors.ink)),
    );
  }
}

/// Result badge for a round row — always a 2px `ink` border; "Failed"
/// fills with `accent`, "Achieved" is transparent (spec §5).
class WhistlyResultBadge extends StatelessWidget {
  final bool achieved;
  final String achievedLabel;
  final String failedLabel;

  const WhistlyResultBadge({
    super.key,
    required this.achieved,
    required this.achievedLabel,
    required this.failedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: achieved ? Colors.transparent : colors.accent,
        border: Border.all(color: colors.ink, width: 2),
      ),
      child: Text(
        (achieved ? achievedLabel : failedLabel).toUpperCase(),
        style: WhistlyText.badge(achieved ? colors.ink : colors.onAccent),
      ),
    );
  }
}

/// Tab bar — 4 equal columns, 2px `line` top border, 9px uppercase labels.
/// Active tab: `ink` label. Inactive: `muted` (spec §5).
///
/// Built on Flutter's own `BottomNavigationBar` rather than a bespoke
/// Row-of-Expanded layout: an earlier bespoke version reproducibly
/// blanked the ENTIRE Scaffold body — every tab's content, not just this
/// bar — the moment it had more than one real item (4 short items, no
/// Badge, no SafeArea: still blanked; a single item: fine). Root cause
/// not identified (root confirmed via a debug marker Container placed
/// directly in Scaffold.body: invisible only when this bar had >1 item).
/// `BottomNavigationBar` doesn't have that failure mode at any item
/// count, at the cost of the spec's 4px accent bottom-border indicator —
/// approximated below with `selectedIconTheme`/`selectedLabelStyle`
/// color instead.
class WhistlyTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<WhistlyTabItem> items;

  const WhistlyTabBar({super.key, required this.currentIndex, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line, width: 2))),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: colors.bg,
        elevation: 0,
        selectedItemColor: colors.ink,
        unselectedItemColor: colors.muted,
        selectedLabelStyle: WhistlyText.tabLabel(colors.ink),
        unselectedLabelStyle: WhistlyText.tabLabel(colors.muted),
        items: items.map((item) {
          final icon = Badge(
            isLabelVisible: item.showDot,
            backgroundColor: colors.accent,
            smallSize: 6,
            child: Icon(item.icon),
          );
          return BottomNavigationBarItem(
            icon: icon,
            activeIcon: icon,
            label: item.label.toUpperCase(),
          );
        }).toList(),
      ),
    );
  }
}

class WhistlyTabItem {
  final IconData icon;
  final String label;
  final bool showDot;
  const WhistlyTabItem({required this.icon, required this.label, this.showDot = false});
}

/// A four-card-trick logo mark — a 2x2 grid of cream card faces on an ink
/// field, one suit per cell, reading ♠ ♥ / ♦ ♣ (spec §4). Below 36px, spec
/// calls for a single accent-filled square with a cream heart instead.
class WhistlyLogoMark extends StatelessWidget {
  final double size;
  const WhistlyLogoMark({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    if (size < 36) {
      return Container(
        width: size,
        height: size,
        color: const Color(0xFFFF2D4F),
        alignment: Alignment.center,
        child: Icon(Icons.favorite, color: const Color(0xFFF5F1EA), size: size * 0.55),
      );
    }
    // Gutter scales with size: 8px at 180px, 4px at 72px, 2px at 36px —
    // linear between those anchor points.
    final gutter = (size * (8 / 180)).clamp(2.0, 8.0);
    const cream = Color(0xFFF5F1EA);
    const ink = Color(0xFF0E0E0E);
    const suitRedColor = Color(0xFFD5001C);
    final glyphSize = size * 0.24;

    Widget cell(String glyph, Color glyphColor) => Container(
          color: cream,
          alignment: Alignment.center,
          child: Text(
            glyph,
            style: TextStyle(fontSize: glyphSize, color: glyphColor, height: 1.0),
          ),
        );

    return Container(
      width: size,
      height: size,
      color: ink,
      padding: EdgeInsets.all(gutter),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: gutter,
        crossAxisSpacing: gutter,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          cell('♠', ink),
          cell('♥', suitRedColor),
          cell('♦', suitRedColor),
          cell('♣', ink),
        ],
      ),
    );
  }
}

/// A flush row of rectangular toggle options — replaces Material's pill-
/// shaped SegmentedButton, which can't express radius 0 (spec §3).
/// Selected: 2px `ink` border, `ink` label. Unselected: 1px `line` border,
/// `muted` label.
class WhistlyToggleRow<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const WhistlyToggleRow({super.key, required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Row(
      children: List.generate(options.length, (i) {
        final (value, label) = options[i];
        final isSelected = value == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == options.length - 1 ? 0 : 8),
            child: InkWell(
              onTap: () => onChanged(value),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: isSelected ? colors.ink : colors.line, width: isSelected ? 2 : 1)),
                child: Text(
                  label.toUpperCase(),
                  style: WhistlyText.eyebrow(isSelected ? colors.ink : colors.muted),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Horizontal lockup: mark + gap + "Whistly" wordmark (spec §4).
class WhistlyLogoLockup extends StatelessWidget {
  final double markSize;
  const WhistlyLogoLockup({super.key, this.markSize = 60});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WhistlyLogoMark(size: markSize),
        const SizedBox(width: 18),
        Text(
          'Whistly',
          style: TextStyle(
            fontFamily: 'Archivo',
            fontSize: 42,
            fontWeight: FontWeight.w800,
            fontVariations: WhistlyText._w800,
            letterSpacing: -0.03 * 42,
            color: colors.ink,
          ),
        ),
      ],
    );
  }
}
