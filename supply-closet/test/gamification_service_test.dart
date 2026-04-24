import 'package:flutter_test/flutter_test.dart';
import 'package:supply_closet/services/firestore_service.dart';
import 'package:supply_closet/services/gamification_service.dart';

void main() {
  test('level progress is bounded for launch XP values', () {
    expect(GamificationService.levelFromXp(0), 1);
    expect(GamificationService.levelFromXp(100), 2);
    expect(GamificationService.levelProgress(50), 0.5);
  });

  test('tag supply result distinguishes create from confirm', () {
    const created = TagSupplyResult(
      supplyId: 'new-supply',
      action: TagSupplyAction.createdNew,
    );
    const confirmed = TagSupplyResult(
      supplyId: 'existing-supply',
      action: TagSupplyAction.confirmedExisting,
    );

    expect(created.createdNew, isTrue);
    expect(confirmed.createdNew, isFalse);
  });

  test('confirm existing awards less base XP than a new tag', () {
    final newTag = GamificationService.calculateXp(
      action: GameAction.tagNew,
      streakDays: 1,
      userLevel: 1,
    );
    final confirm = GamificationService.calculateXp(
      action: GameAction.confirmExisting,
      streakDays: 1,
      userLevel: 1,
    );

    expect(newTag.baseXp, greaterThan(confirm.baseXp));
  });
}
