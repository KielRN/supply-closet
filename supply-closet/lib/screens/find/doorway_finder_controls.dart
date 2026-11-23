import 'package:flutter/material.dart';
import '../../models/supply_item.dart';
import '../../models/supply_room.dart';
import '../../models/user_profile.dart';
import '../../services/doorway_scan.dart';
import '../room/room_initiation_screen.dart';

/// Finds the selected supply using only a measurement saved for its exact bin.
class DoorwayFinderControls extends StatefulWidget {
  final SupplyRoom room;
  final UserProfile? profile;
  final SupplyItem? supply;

  const DoorwayFinderControls({
    super.key,
    required this.room,
    required this.profile,
    required this.supply,
  });

  @override
  State<DoorwayFinderControls> createState() => _DoorwayFinderControlsState();
}

class _DoorwayFinderControlsState extends State<DoorwayFinderControls> {
  final _scanner = DoorwayScanService();
  Future<DoorwayMap?>? _load;
  bool _wasCurrent = false;
  bool _finding = false;
  String _message = '';

  bool get _hasScope => widget.profile?.facilityId != null && widget.profile?.unitId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current && !_wasCurrent && _hasScope) _load = _readMap();
    _wasCurrent = current;
  }

  @override
  void didUpdateWidget(DoorwayFinderControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.supply?.id != oldWidget.supply?.id) _message = '';
  }

  Future<DoorwayMap?> _readMap() => _scanner.load(
        uid: widget.profile!.uid,
        facilityId: widget.profile!.facilityId!,
        unitId: widget.profile!.unitId!,
        roomId: widget.room.id,
      );

  Future<void> _setup() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => RoomInitiationScreen(
        roomId: widget.room.id,
        roomName: widget.room.name,
        roomIsInitiated: widget.room.isInitiated,
        initialShelf: widget.supply?.location.shelf,
        initialBin: widget.supply?.location.bin,
      ),
    ));
    if (mounted && _hasScope) setState(() => _load = _readMap());
  }

  Future<void> _find(DoorwayMap map, String key) async {
    if (_finding) return;
    final supplyName = widget.supply?.name;
    final bin = DoorwayMap.binLabel(key);
    setState(() {
      _finding = true;
      _message = '';
    });
    try {
      final result = await _scanner.scan(
        roomName: widget.room.name,
        label: supplyName == null ? bin : '$supplyName · $bin',
        point: map.bins[key]!,
        width: map.width,
      );
      if (mounted) setState(() => _message = result.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'AR is unavailable. Use the shelf and bin labels.');
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supply = widget.supply;
    final shelf = supply?.location.shelf?.trim() ?? '';
    final bin = supply?.location.bin;
    final supplyKey = shelf.isNotEmpty && bin != null && bin > 0 ? DoorwayMap.binKey(shelf, bin) : null;
    return FutureBuilder<DoorwayMap?>(
      future: _load,
      builder: (context, snapshot) {
        final map = snapshot.data;
        final key = supply != null ? supplyKey : map?.bins.keys.lastOrNull;
        final mapped = key != null && map != null && map.bins.containsKey(key);
        final ready = snapshot.connectionState == ConnectionState.done;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (supply != null || mapped) ...[
              Text(supply?.name ?? 'Last mapped bin', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(supply?.location.displayLabel ?? DoorwayMap.binLabel(key!),
                style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
            ],
            if (mapped)
              ElevatedButton.icon(
                onPressed: _finding || !ready ? null : () => _find(map, key),
                icon: const Icon(Icons.view_in_ar),
                label: const Text('Find from doorway'),
              ),
            if (!_hasScope || snapshot.hasError || (ready && !mapped))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  !_hasScope ? 'Set your facility and unit in Profile to use doorway tracking.'
                    : snapshot.hasError ? 'Could not load the doorway map on this phone.'
                    : supply == null ? 'No bins mapped on this phone yet.'
                    : supplyKey == null ? 'Tag a shelf and bin for this item to use doorway tracking.'
                    : 'This bin has no saved position on this phone.',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Semantics(liveRegion: true, child: Text(_message, style: const TextStyle(fontSize: 16))),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _finding || !_hasScope ? null : _setup,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(supplyKey != null && !mapped ? 'Map this bin' : 'Room setup'),
            ),
          ],
        );
      },
    );
  }
}
