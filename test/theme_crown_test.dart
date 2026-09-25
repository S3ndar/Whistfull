// ALTERATIONS.md (round 2) D2/D3 test 7 — guards the easy mistake:
// forgetting `crown` in AppSemanticColors.lerp would break theme
// animation silently (no compile error, since lerp doesn't have to
// touch every field to type-check).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/theme/app_theme.dart';

void main() {
  test('7: AppSemanticColors.lerp interpolates crown', () {
    final lerped = AppSemanticColors.light.lerp(AppSemanticColors.dark, 0.5);

    // Not equal to either endpoint's crown value — proves it was
    // actually interpolated, not just copied from one side.
    expect(lerped.crown, isNot(AppSemanticColors.light.crown));
    expect(lerped.crown, isNot(AppSemanticColors.dark.crown));

    // At t=0 / t=1 it must exactly match each endpoint.
    expect(AppSemanticColors.light.lerp(AppSemanticColors.dark, 0).crown, AppSemanticColors.light.crown);
    expect(AppSemanticColors.light.lerp(AppSemanticColors.dark, 1).crown, AppSemanticColors.dark.crown);
  });

  // ALTERATIONS.md (round 2) B1.3 test 3 — same guard as above, for the
  // other token missing from lerp would break silently. onAccentLead is
  // fixed (white in both modes), so unlike crown there's no midpoint to
  // distinguish from the endpoints — the meaningful assertion is just
  // that lerp doesn't drop the field (it would default-construct
  // without it, a compile error, so this also guards against a copy-
  // paste that swaps the field name and still type-checks).
  test('AppSemanticColors.lerp interpolates onAccentLead', () {
    final lerped = AppSemanticColors.light.lerp(AppSemanticColors.dark, 0.5);
    expect(lerped.onAccentLead, const Color(0xFFFFFFFF));
    expect(AppSemanticColors.light.lerp(AppSemanticColors.dark, 0).onAccentLead, AppSemanticColors.light.onAccentLead);
    expect(AppSemanticColors.light.lerp(AppSemanticColors.dark, 1).onAccentLead, AppSemanticColors.dark.onAccentLead);
  });
}
