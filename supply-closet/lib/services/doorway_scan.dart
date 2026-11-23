import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<double>? _point(Object? value) {
  if (value is! List || value.length != 3) return null;
  if (!value.every((v) => v is num && v.isFinite)) return null;
  return List<double>.unmodifiable(value.cast<num>().map((v) => v.toDouble()));
}

double? _width(Object? value) =>
    value is num && value.isFinite && value > 0 ? value.toDouble() : null;

class DoorwayMap {
  final double width;
  final Map<String, List<double>> bins;

  DoorwayMap._(this.width, this.bins);

  static String binLabel(String key) {
    final sep = key.lastIndexOf(':');
    return sep < 1
        ? key
        : 'Shelf ${key.substring(0, sep)}, Bin ${key.substring(sep + 1)}';
  }

  static String binKey(String shelf, int bin) {
    final id =
        shelf.trim().toUpperCase().replaceFirst(RegExp(r'^SHELF\s+'), '');
    if (id.isEmpty || bin < 1) throw ArgumentError('Select a shelf and bin.');
    return '$id:$bin';
  }

  factory DoorwayMap._decode(String encoded) {
    final data = jsonDecode(encoded);
    if (data is! Map ||
        data['version'] != 1 ||
        _width(data['width']) == null ||
        data['bins'] is! Map) {
      throw const FormatException('Unrecognized saved doorway map.');
    }
    final bins = <String, List<double>>{};
    for (final entry in (data['bins'] as Map).entries) {
      final point = _point(entry.value);
      if (point == null || entry.key is! String) {
        throw const FormatException('Invalid saved bin position.');
      }
      bins[entry.key as String] = point;
    }
    return DoorwayMap._(_width(data['width'])!, Map.unmodifiable(bins));
  }
}

class DoorwayScanResult {
  final String status;
  final String message;
  final List<double>? point;
  final double? width;

  const DoorwayScanResult({
    required this.status,
    this.message = '',
    this.point,
    this.width,
  });
}

class DoorwayScanService {
  static const _channel = MethodChannel('app.supplycloset/doorway');
  final SharedPreferencesAsync _storage;

  DoorwayScanService({SharedPreferencesAsync? storage})
      : _storage = storage ?? SharedPreferencesAsync();

  // A room map is replaced as one DataStore value. Serialize read-modify-writes
  // across routes so concurrent saves cannot discard another measured bin.
  static Future<void> _writes = Future<void>.value();

  String _key(String uid, String facility, String unit, String room) {
    final path = [uid, facility, unit, room];
    if (path.any((part) => part.trim().isEmpty)) {
      throw ArgumentError(
          'A signed-in account and a selected room are required.');
    }
    return 'doorway.v1/${path.map(Uri.encodeComponent).join('/')}';
  }

  Future<DoorwayMap?> load(
      {required String uid,
      required String facilityId,
      required String unitId,
      required String roomId}) async {
    await _writes;
    final data =
        await _storage.getString(_key(uid, facilityId, unitId, roomId));
    return data == null ? null : DoorwayMap._decode(data);
  }

  Future<DoorwayScanResult> scan(
      {required String roomName,
      required String label,
      List<double>? point,
      double? width}) async {
    if ((point != null && (_point(point) == null || width == null)) ||
        (width != null && _width(width) == null)) {
      throw ArgumentError('Invalid saved doorway or bin.');
    }
    try {
      final reply = await _channel.invokeMapMethod<String, dynamic>('scan', {
        'roomName': roomName,
        'label': label,
        'mode': point == null ? 'place' : 'find',
        if (point != null) 'point': point,
        if (width != null) 'width': width,
      });
      final status = reply?['status'];
      final position = _point(reply?['point']);
      final measuredWidth = _width(reply?['width']);
      if (status == 'saved' && (position == null || measuredWidth == null)) {
        throw const FormatException(
            'The scanner returned an incomplete measurement.');
      }
      return DoorwayScanResult(
        status: status is String ? status : 'error',
        message: reply?['message'] as String? ?? 'Scanner closed.',
        point: position,
        width: measuredWidth,
      );
    } on MissingPluginException {
      return const DoorwayScanResult(
          status: 'unavailable',
          message:
              'Doorway tracking is available on supported Android phones.');
    } on PlatformException catch (error) {
      return DoorwayScanResult(
          status: 'error', message: error.message ?? error.code);
    }
  }

  Future<void> saveBin(
      {required String uid,
      required String facilityId,
      required String unitId,
      required String roomId,
      required String shelf,
      required int bin,
      required DoorwayScanResult result}) {
    final write = _writes.then((_) async {
      final point = _point(result.point);
      final width = _width(result.width);
      if (result.status != 'saved' || point == null || width == null) {
        throw StateError('Confirm a measured bin before saving.');
      }
      final key = _key(uid, facilityId, unitId, roomId);
      final data = await _storage.getString(key);
      final old = data == null ? null : DoorwayMap._decode(data);
      final binId = DoorwayMap.binKey(shelf, bin);
      final bins = {...?old?.bins}..remove(binId);
      bins[binId] = point;
      await _storage.setString(
          key,
          jsonEncode({
            'version': 1,
            'width': old?.width ?? width,
            'bins': bins,
          }));
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}
