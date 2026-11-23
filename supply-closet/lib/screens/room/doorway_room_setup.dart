import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/gamification_provider.dart';
import '../../services/doorway_scan.dart';
import '../../services/firestore_service.dart';
import '../../services/gamification_service.dart';

class DoorwayRoomSetup extends StatefulWidget {
  final UserProfile profile;
  final String roomId;
  final String roomName;
  final bool roomIsInitiated;
  final String? initialShelf;
  final int? initialBin;

  const DoorwayRoomSetup({
    super.key,
    required this.profile,
    required this.roomId,
    required this.roomName,
    required this.roomIsInitiated,
    this.initialShelf,
    this.initialBin,
  });

  @override
  State<DoorwayRoomSetup> createState() => _DoorwayRoomSetupState();
}

class _DoorwayRoomSetupState extends State<DoorwayRoomSetup> {
  final _scanner = DoorwayScanService();
  final _form = GlobalKey<FormState>();
  late final TextEditingController _shelf;
  late final TextEditingController _bin;
  late bool _registered;
  DoorwayMap? _map;
  bool _busy = false;
  bool _loaded = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _shelf = TextEditingController(text: widget.initialShelf);
    _bin = TextEditingController(text: widget.initialBin?.toString());
    _registered = widget.roomIsInitiated;
    _load();
  }

  @override
  void dispose() {
    _shelf.dispose();
    _bin.dispose();
    super.dispose();
  }

  Future<DoorwayMap?> _readMap() => _scanner.load(
        uid: widget.profile.uid,
        facilityId: widget.profile.facilityId!,
        unitId: widget.profile.unitId!,
        roomId: widget.roomId,
      );

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final map = await _readMap();
      if (!mounted) return;
      setState(() {
        _map = map;
        _loaded = true;
        _message = '';
      });
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not read the map on this phone.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registerRoom() async {
    final profile = widget.profile;
    final roomId = widget.roomId;
    final game = context.read<GamificationProvider>();
    final first = await FirestoreService().initiateMeasuredRoom(
      facilityId: profile.facilityId!,
      unitId: profile.unitId!,
      roomId: roomId,
      roomName: widget.roomName,
      userId: profile.uid,
    );
    if (mounted) setState(() => _registered = true);
    if (first) {
      final hour = DateTime.now().hour;
      await game.recordAction(
        profile: profile,
        action: GameAction.initiateRoom,
        isNightShift: hour >= 19 || hour < 7,
        facilityId: profile.facilityId,
        unitId: profile.unitId,
        roomId: roomId,
      );
    }
  }

  Future<void> _finishRoom() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _registerRoom();
      if (mounted) setState(() => _message = 'Room setup is complete.');
    } catch (_) {
      if (mounted) setState(() => _message = _syncFailure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _syncFailure => _registered
      ? 'Room setup is complete. The XP award could not be verified.'
      : 'The bin is saved on this phone. Finish room setup when you have a connection.';

  Future<void> _measure() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final shelf = _shelf.text.trim();
    final bin = int.parse(_bin.text);
    final label = DoorwayMap.binLabel(DoorwayMap.binKey(shelf, bin));
    final profile = widget.profile;
    final roomId = widget.roomId;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final result = await _scanner.scan(
        roomName: widget.roomName,
        label: label,
        width: _map?.width,
      );
      if (!mounted) return;
      if (result.status != 'saved') {
        setState(() => _message = result.message);
        return;
      }
      await _scanner.saveBin(
        uid: profile.uid,
        facilityId: profile.facilityId!,
        unitId: profile.unitId!,
        roomId: roomId,
        shelf: shelf,
        bin: bin,
        result: result,
      );
      if (!mounted) return;
      final map = await _readMap();
      if (!mounted) return;
      setState(() {
        _map = map;
        _message = '$label saved on this phone.';
      });
      if (!_registered) {
        try {
          await _registerRoom();
        } catch (_) {
          if (mounted) setState(() => _message = _syncFailure);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not verify the saved position. Reopen room setup to check before measuring again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _find(String key) async {
    if (_busy) return;
    final map = _map!;
    setState(() => _busy = true);
    try {
      final result = await _scanner.scan(
        roomName: widget.roomName,
        label: DoorwayMap.binLabel(key),
        point: map.bins[key]!,
        width: map.width,
      );
      if (mounted) setState(() => _message = result.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'AR is unavailable. Use the shelf and bin labels.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = _map?.bins.keys.toList().reversed ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Room setup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.roomName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Start inside the room facing the doorway. Scan both upper inside corners, then mark the bin. Use this same doorway each time.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Form(
              key: _form,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _shelf,
                      enabled: !_busy,
                      decoration: const InputDecoration(labelText: 'Shelf', hintText: 'e.g. A'),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        final name = (value ?? '').trim();
                        return name.isEmpty || DoorwayMap.binKey(name, 1) == ':1'
                            ? 'Enter a shelf label'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _bin,
                      enabled: !_busy,
                      decoration: const InputDecoration(labelText: 'Bin', hintText: 'e.g. 2'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1 ? 'Enter a bin number' : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loaded && !_busy ? _measure : null,
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Measure bin with AR'),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(liveRegion: true, child: Text(_message, style: const TextStyle(fontSize: 16))),
              ),
            if (!_loaded && !_busy)
              OutlinedButton(onPressed: _load, child: const Text('Reload saved bins')),
            if (keys.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Saved on this phone', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              for (final key in keys)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DoorwayMap.binLabel(key)),
                  trailing: const Icon(Icons.view_in_ar),
                  onTap: _busy ? null : () => _find(key),
                  subtitle: const Text('Find from doorway'),
                ),
              if (!_registered)
                OutlinedButton(onPressed: _busy ? null : _finishRoom, child: const Text('Finish room setup')),
            ],
          ],
        ),
      ),
    );
  }
}
