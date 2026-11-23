import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supply_closet/services/doorway_scan.dart';

class _Storage extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late DoorwayScanService scanner;
  setUp(() {
    storage = _Storage();
    scanner = DoorwayScanService(storage: storage);
  });
  const success =
      DoorwayScanResult(status: 'saved', width: 0.88, point: [1.25, -0.5, 3]);
  Future<void> save(String shelf, int bin, DoorwayScanResult result) =>
      scanner.saveBin(
          uid: 'u',
          facilityId: 'f',
          unitId: 'floor',
          roomId: 'r',
          shelf: shelf,
          bin: bin,
          result: result);

  test(
      'two committed bins survive reopening, a canceled rescan and account switching',
      () async {
    await Future.wait([save('Shelf A', 1, success), save('A', 2, success)]);
    await expectLater(
        save('Shelf A', 1, const DoorwayScanResult(status: 'cancelled')),
        throwsStateError);
    final reopened = DoorwayScanService(storage: storage);
    final map = await reopened.load(
        uid: 'u', facilityId: 'f', unitId: 'floor', roomId: 'r');
    expect(map!.width, 0.88);
    expect(map.bins, {'A:1': success.point, 'A:2': success.point});
    expect(
        await reopened.load(
            uid: 'v', facilityId: 'f', unitId: 'floor', roomId: 'r'),
        isNull);
    expect(
        await reopened.load(
            uid: 'u', facilityId: 'f', unitId: 'floor', roomId: 'other'),
        isNull);
  });

  test(
      'Finder passes the saved local coordinates and doorway width to the native tracker',
      () async {
    const channel = MethodChannel('app.supplycloset/doorway');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'scan');
      expect(call.arguments, {
        'mode': 'find',
        'roomName': 'North',
        'label': 'Shelf A, bin 2',
        'point': success.point,
        'width': success.width,
      });
      return {'status': 'cancelled'};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final result = await scanner.scan(
        roomName: 'North',
        label: 'Shelf A, bin 2',
        point: success.point,
        width: success.width);
    expect(result.status, 'cancelled');
  });
}
