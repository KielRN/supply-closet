import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:camera/camera.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/supply_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/gamification_service.dart';

/// Three-step tagging flow: identify (barcode or pick from catalog) → locate
/// (shelf/bin) → confirm (preview + tag).
class TagSupplyScreen extends StatefulWidget {
  const TagSupplyScreen({super.key});

  @override
  State<TagSupplyScreen> createState() => _TagSupplyScreenState();
}

class _TagSupplyScreenState extends State<TagSupplyScreen> {
  int _step = 0;

  // Step 1 state
  String? _supplyName;
  String? _supplyCategory;
  String? _barcode;
  String? _supplySize;

  // Step 2 state
  final _shelfController = TextEditingController();
  final _binController = TextEditingController();

  bool _isSubmitting = false;
  bool _isFirstTagOnUnit = false;

  @override
  void dispose() {
    _shelfController.dispose();
    _binController.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 2));
  void _back() => setState(() => _step = (_step - 1).clamp(0, 2));

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final game = context.read<GamificationProvider>();
    final profile = auth.profile;
    if (profile == null ||
        profile.facilityId == null ||
        profile.unitId == null) {
      _showError('Set your facility and unit in your profile first.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final fs = FirestoreService();
      // Default room "main" — phase 2 will support multiple rooms per unit.
      const roomId = 'main';

      final shelf = _shelfController.text.trim();
      final binStr = _binController.text.trim();
      final bin = int.tryParse(binStr);

      await fs.tagSupply(
        facilityId: profile.facilityId!,
        unitId: profile.unitId!,
        roomId: roomId,
        supplyName: _supplyName ?? 'Untitled',
        barcode: _barcode,
        category: _supplyCategory,
        location: SupplyLocation(
          shelf: shelf.isEmpty ? null : shelf,
          bin: bin,
          x: 0, // populated by AR session if used
          y: 0,
          z: 0,
        ),
        userId: profile.uid,
      );

      // Award XP via the gamification provider
      await game.recordAction(
        profile: profile,
        action: GameAction.tagNew,
        isFirstTagOnUnit: _isFirstTagOnUnit,
        isNightShift: _isNightShift(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tagged ${_supplyName ?? "supply"}!'),
            backgroundColor: SupplyClosetColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Failed to tag: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _isNightShift() {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 7;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: SupplyClosetColors.coral,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag a Supply'),
        leading: _step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _back,
              ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: _step),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCurrentStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _IdentifyStep(
          key: const ValueKey('identify'),
          onIdentified: (name, category, size, barcode) {
            setState(() {
              _supplyName = name;
              _supplyCategory = category;
              _supplySize = size;
              _barcode = barcode;
            });
            _next();
          },
        );
      case 1:
        return _LocateStep(
          key: const ValueKey('locate'),
          shelfController: _shelfController,
          binController: _binController,
          onContinue: _next,
        );
      case 2:
      default:
        return _ConfirmStep(
          key: const ValueKey('confirm'),
          name: _supplyName ?? '',
          size: _supplySize,
          category: _supplyCategory,
          barcode: _barcode,
          shelf: _shelfController.text,
          bin: _binController.text,
          isSubmitting: _isSubmitting,
          onSubmit: _submit,
        );
    }
  }
}

// ─── Step indicator ────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = ['Identify', 'Locate', 'Confirm'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == currentStep;
          final isDone = i < currentStep;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive || isDone
                          ? SupplyClosetColors.teal
                          : SupplyClosetColors.warmWhite,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? SupplyClosetColors.teal
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Step 1: Identify ──────────────────────────────────────────────

class _IdentifyStep extends StatefulWidget {
  final void Function(String name, String? category, String? size,
      String? barcode) onIdentified;

  const _IdentifyStep({super.key, required this.onIdentified});

  @override
  State<_IdentifyStep> createState() => _IdentifyStepState();
}

class _IdentifyStepState extends State<_IdentifyStep> {
  CameraController? _camera;
  BarcodeScanner? _scanner;
  bool _isScanning = false;
  bool _showManual = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _showManual = true);
        return;
      }
      _camera = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _camera!.initialize();
      _scanner = BarcodeScanner();
      _startScanning();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _showManual = true);
    }
  }

  void _startScanning() {
    if (_camera == null || !_camera!.value.isInitialized) return;
    _camera!.startImageStream((image) async {
      if (_isScanning) return;
      _isScanning = true;
      // Note: real implementation needs InputImage conversion from CameraImage
      // For brevity we skip the full barcode pipeline here — see SETUP.md
      _isScanning = false;
    });
  }

  @override
  void dispose() {
    _camera?.dispose();
    _scanner?.close();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showManual) {
      return _buildManualSearch();
    }
    if (_camera == null || !_camera!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(_camera!)),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: SupplyClosetColors.teal, width: 4),
          ),
          margin: const EdgeInsets.all(40),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Point at a barcode',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _showManual = true),
            icon: const Icon(Icons.search),
            label: const Text('Search catalog instead'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualSearch() {
    // For phase 1, hand-typed entry. Phase 2: load seed_supplies.csv into a
    // searchable typeahead.
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Supply name',
              hintText: 'e.g. Foley Catheter 16 Fr',
              prefixIcon: Icon(Icons.medical_services_outlined),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                widget.onIdentified(v.trim(), null, null, null);
              }
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final v = _searchController.text.trim();
              if (v.isNotEmpty) {
                widget.onIdentified(v, null, null, null);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Continue'),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showManual = false),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan barcode instead'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Locate ────────────────────────────────────────────────

class _LocateStep extends StatelessWidget {
  final TextEditingController shelfController;
  final TextEditingController binController;
  final VoidCallback onContinue;

  const _LocateStep({
    super.key,
    required this.shelfController,
    required this.binController,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where is it?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Tag the shelf and bin so the next nurse can find it fast.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: shelfController,
            decoration: const InputDecoration(
              labelText: 'Shelf',
              hintText: 'A, B, C, Top, Bottom...',
              prefixIcon: Icon(Icons.shelves),
            ),
            textCapitalization: TextCapitalization.characters,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: binController,
            decoration: const InputDecoration(
              labelText: 'Bin number (optional)',
              hintText: '1, 2, 3...',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          Card(
            color: SupplyClosetColors.warmWhite,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: SupplyClosetColors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Stand in front of the bin while tagging — '
                      'we use your phone to refine the location for AR.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Confirm ───────────────────────────────────────────────

class _ConfirmStep extends StatelessWidget {
  final String name;
  final String? size;
  final String? category;
  final String? barcode;
  final String shelf;
  final String bin;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _ConfirmStep({
    super.key,
    required this.name,
    this.size,
    this.category,
    this.barcode,
    required this.shelf,
    required this.bin,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Confirm tag',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: SupplyClosetColors.tealLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medical_services,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600)),
                            if (size != null)
                              Text(size!,
                                  style: TextStyle(
                                      color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _kv('Shelf', shelf.isEmpty ? '—' : shelf),
                  _kv('Bin', bin.isEmpty ? '—' : bin),
                  if (barcode != null) _kv('Barcode', barcode!),
                  if (category != null) _kv('Category', category!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SupplyClosetColors.tealLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, color: SupplyClosetColors.teal),
                const SizedBox(width: 8),
                Text(
                  '+${AppConstants.pointsTagNew} XP for tagging',
                  style: TextStyle(
                      color: SupplyClosetColors.teal,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: isSubmitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Tag this supply'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(key,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
