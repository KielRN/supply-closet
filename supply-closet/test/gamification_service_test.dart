import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:supply_closet/models/supply_room.dart';
import 'package:supply_closet/services/firestore_service.dart';
import 'package:supply_closet/services/gamification_service.dart';
import 'package:supply_closet/services/spatial_room_scanner.dart';

void main() {
  test('level progress is bounded for launch XP values', () {
    expect(GamificationService.levelFromXp(0), 1);
    expect(GamificationService.levelFromXp(100), 2);
    expect(GamificationService.levelProgress(50), 0.5);
  });

  test('tag supply result distinguishes create from confirm and bounty claim', () {
    const created = TagSupplyResult(
      supplyId: 'new-supply',
      action: TagSupplyAction.createdNew,
      claimedBountyId: 'bounty-1',
    );
    const confirmed = TagSupplyResult(
      supplyId: 'existing-supply',
      action: TagSupplyAction.confirmedExisting,
    );

    expect(created.createdNew, isTrue);
    expect(created.claimedBounty, isTrue);
    expect(confirmed.createdNew, isFalse);
    expect(confirmed.claimedBounty, isFalse);
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

  test('room initiation, room captain, and bounty claim award high XP bonuses', () {
    final initRoom = GamificationService.calculateXp(
      action: GameAction.initiateRoom,
      streakDays: 1,
      userLevel: 1,
    );
    final roomCaptain = GamificationService.calculateXp(
      action: GameAction.becomeRoomCaptain,
      streakDays: 1,
      userLevel: 1,
    );
    final claimBounty = GamificationService.calculateXp(
      action: GameAction.claimBounty,
      streakDays: 1,
      userLevel: 1,
    );

    expect(initRoom.baseXp, 250);
    expect(roomCaptain.baseXp, 150);
    expect(claimBounty.baseXp, 50);
  });

  test('SupplyRoom resolves deterministic non-zero 3D coordinates and Captain Hints', () {
    final hint = RoomHint(
      id: 'h1',
      text: 'Extra flushes behind top bin',
      shelfId: 'A',
      binNumber: 2,
      x: -1.1,
      y: 1.5,
      z: 1.9,
      yawDegrees: -32.0,
      captainUid: 'u1',
      captainName: 'Nurse Maya',
      captainAvatar: 'avatar:trauma_captain',
      createdAt: DateTime(2026, 11, 9),
    );
    final room = SupplyRoom(
      id: 'med_3a_south',
      name: 'Med 3A · South Supply Rm',
      doorCode: 'RM 3A-204',
      isInitiated: true,
      shelves: SupplyRoom.defaultInitiatedShelves(),
      captainUid: 'u1',
      captainName: 'Nurse Maya',
      captainAvatar: 'avatar:trauma_captain',
      captainTagCount: 14,
      hints: [hint],
    );

    final locA6 = room.resolveLocation(shelf: 'A', bin: 6);
    final locC4 = room.resolveLocation(shelf: 'C', bin: 4);

    expect(room.hasCaptain, isTrue);
    expect(room.hints.first.captainName, 'Nurse Maya');
    expect(locA6.shelf, 'A');
    expect(locA6.bin, 6);
    expect(locA6.x, lessThan(0)); // Shelf A is on left wall (-yaw)
    expect(locA6.z, greaterThan(0));
    expect(locC4.x, greaterThan(0)); // Shelf C is on right wall (+yaw)
  });

  test('SpatialRoomScannerEngine progressively accumulates sticky 3D feature dots and projects 3D bins', () {
    final engine = SpatialRoomScannerEngine();
    expect(engine.totalPointCount, 0);

    // Seed feature points around Shelf A (-12 deg)
    engine.seedFeaturePointsAround(
      centerYawDeg: -12.0,
      centerPitchDeg: 0.0,
      depthMeters: 2.1,
      count: 15,
    );
    expect(engine.totalPointCount, greaterThan(0));

    // Project 3D bins when looking toward Shelf A
    final shelves = [
      const ShelfRack(
        id: 'A',
        label: 'Shelf A · Left Wall',
        yawDegrees: -12.0,
        distanceMeters: 2.1,
      ),
    ];
    final binsAtOrigin = engine.projectBinsForShelves(
      shelves: shelves,
      pinnedShelfIds: const {'A'},
      screenSize: const Size(400, 800),
    );
    expect(binsAtOrigin, isNotEmpty);
    final bin2InitialX = binsAtOrigin
        .firstWhere((b) => b.binNumber == 2)
        .frontRect
        .center
        .dx;

    // Pan camera to the right -> anchored Shelf A bin boxes shift left on screen
    engine.addManualPan(-40.0, 0.0);
    final binsAfterPan = engine.projectBinsForShelves(
      shelves: shelves,
      pinnedShelfIds: const {'A'},
      screenSize: const Size(400, 800),
    );
    final bin2PannedX = binsAfterPan
        .firstWhere((b) => b.binNumber == 2)
        .frontRect
        .center
        .dx;
    expect(bin2PannedX, lessThan(bin2InitialX));

    engine.dispose();
  });
}
