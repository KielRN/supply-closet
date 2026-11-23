import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

/// Pre-generated clinical & gaming avatar definition.
/// Stored in UserProfile.photoUrl as `avatar:<id>` so it works seamlessly
/// across Firestore security rules, Leaderboards, and Room Captain Hints.
class AvatarPreset {
  final String id; // e.g., "avatar:iv_sniper"
  final String title;
  final String emoji;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;

  const AvatarPreset({
    required this.id,
    required this.title,
    required this.emoji,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
  });
}

class AvatarPresets {
  static const List<AvatarPreset> all = [
    AvatarPreset(
      id: 'avatar:trauma_captain',
      title: 'Trauma Captain',
      emoji: '🦅',
      icon: Icons.military_tech_rounded,
      primaryColor: Color(0xFF0D9488),
      secondaryColor: Color(0xFF0284C7),
    ),
    AvatarPreset(
      id: 'avatar:iv_sniper',
      title: 'IV Sniper',
      emoji: '🎯',
      icon: Icons.gps_fixed_rounded,
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF047857),
    ),
    AvatarPreset(
      id: 'avatar:night_owl_rn',
      title: 'Night Shift Owl',
      emoji: '🦉',
      icon: Icons.nights_stay_rounded,
      primaryColor: Color(0xFF6366F1),
      secondaryColor: Color(0xFF312E81),
    ),
    AvatarPreset(
      id: 'avatar:code_runner',
      title: 'Code Runner',
      emoji: '⚡',
      icon: Icons.bolt_rounded,
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFD97706),
    ),
    AvatarPreset(
      id: 'avatar:icu_guardian',
      title: 'ICU Guardian',
      emoji: '🛡️',
      icon: Icons.shield_rounded,
      primaryColor: Color(0xFF0EA5E9),
      secondaryColor: Color(0xFF0369A1),
    ),
    AvatarPreset(
      id: 'avatar:scrub_ninja',
      title: 'Scrub Ninja',
      emoji: '🥷',
      icon: Icons.auto_awesome_rounded,
      primaryColor: Color(0xFF8B5CF6),
      secondaryColor: Color(0xFF4C1D95),
    ),
    AvatarPreset(
      id: 'avatar:flight_medic',
      title: 'Flight RN',
      emoji: '🚁',
      icon: Icons.flight_takeoff_rounded,
      primaryColor: Color(0xFFEC4899),
      secondaryColor: Color(0xFF9D174D),
    ),
    AvatarPreset(
      id: 'avatar:supply_sensei',
      title: 'Supply Sensei',
      emoji: '👑',
      icon: Icons.emoji_events_rounded,
      primaryColor: Color(0xFFEAB308),
      secondaryColor: Color(0xFFB45309),
    ),
  ];

  static AvatarPreset? fromPhotoUrl(String? photoUrl) {
    if (photoUrl == null || !photoUrl.startsWith('avatar:')) return null;
    for (final preset in all) {
      if (preset.id == photoUrl) return preset;
    }
    return all.first;
  }

  /// Short emoji badge for canvas HUD callouts (e.g., Captain Hints in 3D Splat)
  static String emojiFor(String? photoUrl) {
    final preset = fromPhotoUrl(photoUrl);
    if (preset != null) return preset.emoji;
    if (photoUrl != null && photoUrl.isNotEmpty) return '📸';
    return '👩‍⚕️';
  }
}

/// Universal avatar widget that renders:
/// - Pre-generated gaming/clinical avatars (`avatar:<id>`)
/// - Uploaded/camera base64 data URI photos (`data:image/...`)
/// - Network profile photos (`https://...`)
/// - Initial fallback with gradient background
class UserAvatar extends StatelessWidget {
  final String displayName;
  final String? photoUrl;
  final double radius;
  final bool isCaptain;
  final Color? borderColor;

  const UserAvatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.radius = 24,
    this.isCaptain = false,
    this.borderColor,
  });

  Uint8List? _decodeDataUri(String uri) {
    try {
      final commaIdx = uri.indexOf(',');
      if (commaIdx == -1) return null;
      return base64Decode(uri.substring(commaIdx + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = AvatarPresets.fromPhotoUrl(photoUrl);
    final isDataUri = photoUrl != null && photoUrl!.startsWith('data:image/');
    final isHttp = photoUrl != null &&
        (photoUrl!.startsWith('http://') || photoUrl!.startsWith('https://'));

    Widget avatarContent;

    if (preset != null) {
      avatarContent = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [preset.primaryColor, preset.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: borderColor ??
                (isCaptain ? SupplyClosetColors.warning : Colors.white),
            width: isCaptain ? 2.5 : 1.8,
          ),
        ),
        child: Center(
          child: Icon(
            preset.icon,
            color: Colors.white,
            size: radius * 1.05,
          ),
        ),
      );
    } else if (isDataUri) {
      final bytes = _decodeDataUri(photoUrl!);
      avatarContent = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ??
                (isCaptain ? SupplyClosetColors.warning : Colors.white),
            width: isCaptain ? 2.5 : 1.8,
          ),
          image: bytes != null
              ? DecorationImage(
                  image: MemoryImage(bytes),
                  fit: BoxFit.cover,
                )
              : null,
          color: SupplyClosetColors.teal,
        ),
        child: bytes == null ? _buildInitial() : null,
      );
    } else if (isHttp) {
      avatarContent = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ??
                (isCaptain ? SupplyClosetColors.warning : Colors.white),
            width: isCaptain ? 2.5 : 1.8,
          ),
          image: DecorationImage(
            image: NetworkImage(photoUrl!),
            fit: BoxFit.cover,
          ),
          color: SupplyClosetColors.teal,
        ),
      );
    } else {
      avatarContent = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [SupplyClosetColors.teal, SupplyClosetColors.tealDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: borderColor ??
                (isCaptain ? SupplyClosetColors.warning : Colors.white),
            width: isCaptain ? 2.5 : 1.8,
          ),
        ),
        child: _buildInitial(),
      );
    }

    if (!isCaptain) return avatarContent;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarContent,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: SupplyClosetColors.warning,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF020617), width: 1.5),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              size: radius * 0.55,
              color: const Color(0xFF020617),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitial() {
    final initial =
        displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : 'N';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Interactive Bottom Sheet for customizing Display Name, choosing a
/// Pre-Generated Avatar, or snapping/uploading a custom profile photo.
class ProfileIdentitySheet extends StatefulWidget {
  const ProfileIdentitySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileIdentitySheet(),
    );
  }

  @override
  State<ProfileIdentitySheet> createState() => _ProfileIdentitySheetState();
}

class _ProfileIdentitySheetState extends State<ProfileIdentitySheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _customUrlCtrl;
  String? _selectedPhotoUrl;
  bool _showUrlInput = false;
  bool _isSaving = false;

  CameraController? _camera;
  bool _cameraOpen = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _nameCtrl = TextEditingController(text: profile?.displayName ?? '');
    _selectedPhotoUrl = profile?.photoUrl ?? AvatarPresets.all.first.id;
    _customUrlCtrl = TextEditingController(
      text: (_selectedPhotoUrl != null &&
              (_selectedPhotoUrl!.startsWith('http://') ||
                  _selectedPhotoUrl!.startsWith('https://')))
          ? _selectedPhotoUrl
          : '',
    );
  }

  @override
  void dispose() {
    _camera?.dispose();
    _nameCtrl.dispose();
    _customUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSelfieCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera detected on this device.')),
          );
        }
        return;
      }
      // Prefer front camera for profile photo, fallback to first camera
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await _camera!.initialize();
      if (mounted) {
        setState(() => _cameraOpen = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open camera: $e')),
        );
      }
    }
  }

  Future<void> _snapProfilePhoto() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    try {
      final xfile = await _camera!.takePicture();
      final bytes = await xfile.readAsBytes();
      final b64 = base64Encode(bytes);
      await _camera?.dispose();
      _camera = null;
      if (mounted) {
        setState(() {
          _cameraOpen = false;
          _selectedPhotoUrl = 'data:image/jpeg;base64,$b64';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e')),
        );
      }
    }
  }

  Future<void> _saveIdentity() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a display name.'),
          backgroundColor: SupplyClosetColors.coral,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<AuthProvider>().updateProfileIdentity(
            displayName: name,
            photoUrl: _selectedPhotoUrl,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile display name & avatar updated!'),
            backgroundColor: SupplyClosetColors.successDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: SupplyClosetColors.coral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(top: 48, bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: SupplyClosetColors.tealLight, width: 2),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                UserAvatar(
                  displayName:
                      _nameCtrl.text.isEmpty ? 'Nurse' : _nameCtrl.text,
                  photoUrl: _selectedPhotoUrl,
                  radius: 28,
                  isCaptain: true,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customize Display Name & Avatar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Shown on Leaderboards, Room Captain Medals & Spatial Room Hints.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Display Name Input
            const Text(
              'DISPLAY NAME (VISIBLE TO OTHER NURSES)',
              style: TextStyle(
                color: SupplyClosetColors.tealLight,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              maxLength: 32,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'e.g., Nurse Maya R., RN or TraumaHawk',
                hintStyle: const TextStyle(color: Colors.white38),
                counterStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF020617),
                prefixIcon: const Icon(Icons.badge_outlined,
                    color: SupplyClosetColors.tealLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Pre-Generated Clinical / Gaming Avatars Grid
            const Text(
              'CHOOSE A PRE-GENERATED AVATAR',
              style: TextStyle(
                color: SupplyClosetColors.tealLight,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: AvatarPresets.all.length,
              itemBuilder: (context, index) {
                final preset = AvatarPresets.all[index];
                final selected = _selectedPhotoUrl == preset.id;
                return InkWell(
                  onTap: () => setState(() => _selectedPhotoUrl = preset.id),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selected
                          ? preset.primaryColor.withValues(alpha: 0.25)
                          : const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? SupplyClosetColors.warning
                            : Colors.white24,
                        width: selected ? 2.2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        UserAvatar(
                          displayName: preset.title,
                          photoUrl: preset.id,
                          radius: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preset.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? SupplyClosetColors.warning
                                : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Upload / Snap Custom Profile Picture Section
            const Text(
              'OR UPLOAD / SNAP YOUR OWN PROFILE PICTURE',
              style: TextStyle(
                color: SupplyClosetColors.tealLight,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),

            if (_cameraOpen &&
                _camera != null &&
                _camera!.value.isInitialized) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 210,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_camera!),
                      Positioned(
                        bottom: 12,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _snapProfilePhoto,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SupplyClosetColors.warning,
                                  foregroundColor: const Color(0xFF020617),
                                ),
                                icon: const Icon(Icons.camera_alt_rounded),
                                label: const Text(
                                  'SNAP PHOTO',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () async {
                                await _camera?.dispose();
                                _camera = null;
                                setState(() => _cameraOpen = false);
                              },
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openSelfieCamera,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                            color: SupplyClosetColors.tealLight),
                        minimumSize: const Size(0, 46),
                      ),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text(
                        'Take Photo',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _showUrlInput = !_showUrlInput),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        minimumSize: const Size(0, 46),
                      ),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text(
                        'Image URL',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (_showUrlInput) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customUrlCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (val) {
                  if (val.trim().startsWith('http')) {
                    setState(() => _selectedPhotoUrl = val.trim());
                  }
                },
                decoration: InputDecoration(
                  hintText: 'https://example.com/my-photo.jpg',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF020617),
                  prefixIcon: const Icon(Icons.image_outlined,
                      color: SupplyClosetColors.tealLight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveIdentity,
              style: ElevatedButton.styleFrom(
                backgroundColor: SupplyClosetColors.successDark,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isSaving ? 'SAVING PROFILE...' : 'SAVE DISPLAY NAME & AVATAR',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
