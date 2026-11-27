import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ======================================================
// ORBIT - NPC AVATAR WIDGET
// Whole Portrait System
// ======================================================

class NpcAvatarWidget extends StatefulWidget {
  const NpcAvatarWidget({
    super.key,
    required this.avatarIndex,
    this.width = 250,
  });

  final int avatarIndex;
  final double width;

  @override
  State<NpcAvatarWidget> createState() => _NpcAvatarWidgetState();
}

class _NpcAvatarWidgetState extends State<NpcAvatarWidget> {
  // ====================================================
  // ASSET CONFIGURATION
  // ====================================================

  static const String _root = 'lib/core/assets/npc';

  // Cache the asset list so it only loads once.
  static Future<List<String>>? _avatarFilesFuture;

  late Future<String> _selectedAvatarFuture;

  // ====================================================
  // LIFECYCLE
  // ====================================================

  @override
  void initState() {
    super.initState();

    _selectedAvatarFuture = _resolveAvatar(widget.avatarIndex);
  }

  @override
  void didUpdateWidget(covariant NpcAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.avatarIndex != widget.avatarIndex) {
      _selectedAvatarFuture = _resolveAvatar(widget.avatarIndex);
    }
  }

  // ====================================================
  // LOAD ASSETS
  // ====================================================

  static Future<List<String>> _loadAvatarFiles() {
    return _avatarFilesFuture ??= _readAvatarFiles();
  }

  static Future<List<String>> _readAvatarFiles() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    final all = manifest.listAssets();

    final files = all.where((path) {
      // Only read assets from the NPC root.
      if (!path.startsWith('$_root/')) {
        return false;
      }

      final relative = path.substring('$_root/'.length);

      // Ignore subfolders like front/.
      if (relative.contains('/')) {
        return false;
      }

      final lower = relative.toLowerCase();

      // Only accept numbered portrait assets.
      // Examples:
      // 01.png, 02.png, 03.png, 04.webp
      return RegExp(r'^\d{2,}\.(png|webp|jpg|jpeg)$').hasMatch(lower);
    }).toList()..sort();

    if (files.isEmpty) {
      throw StateError(
        'No NPC portraits found in $_root/. '
        'Add files such as 01.png, 02.png, 03.png '
        'and register the directory in pubspec.yaml.',
      );
    }

    debugPrint('ORBIT NPC: ${files.length} portraits loaded.');

    return files;
  }

  // ====================================================
  // SELECT AVATAR
  // ====================================================

  static Future<String> _resolveAvatar(int avatarIndex) async {
    final files = await _loadAvatarFiles();

    // Wrap around when avatarIndex exceeds
    // the total available portraits.
    final index = avatarIndex % files.length;

    return files[index];
  }

  // ====================================================
  // BUILD WIDGET
  // ====================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _selectedAvatarFuture,
      builder: (context, snapshot) {
        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          );
        }

        // Loading state
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        // Display complete NPC portrait.
        return Image.asset(
          snapshot.data!,
          width: widget.width,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('ORBIT NPC IMAGE ERROR: $error');

            return const Center(
              child: Icon(
                Icons.person_outline_rounded,
                color: Colors.white54,
                size: 72,
              ),
            );
          },
        );
      },
    );
  }
}
