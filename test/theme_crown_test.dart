// ALTERATIONS.md (round 2) D2/D3 test 7 — guards the easy mistake:
// forgetting `crown` in AppSemanticColors.lerp would break theme
// animation silently (no compile error, since lerp doesn't have to
// touch every field to type-check).
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
}
