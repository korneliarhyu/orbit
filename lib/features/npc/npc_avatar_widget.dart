
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'npc_appearance.dart';

class NpcAvatarWidget extends StatefulWidget {
  final NpcAppearance appearance;
  final double size;

  const NpcAvatarWidget({
    super.key,
    required this.appearance,
    this.size = 250,
  });

  @override
  State<NpcAvatarWidget> createState() =>
      _NpcAvatarWidgetState();
}

class _NpcAvatarWidgetState
    extends State<NpcAvatarWidget> {

  // Current MVP only supports FRONT.
  static const String _assetRoot =
      'lib/core/assets/npc/front';

  late Future<List<String>> _layersFuture;

  @override
  void initState() {
    super.initState();
    _layersFuture = _loadLayers(widget.appearance);
  }

  @override
  void didUpdateWidget(
      covariant NpcAvatarWidget oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.appearance != widget.appearance) {
      _layersFuture = _loadLayers(widget.appearance);
    }
  }

  // ---------------------------------------------
  // ASSET HELPERS
  // ---------------------------------------------

  String _id(int value) =>
      value.toString().padLeft(2, '0');

  String _path(String folder, String filename) {
    return '$_assetRoot/$folder/$filename.png';
  }

  Future<List<String>> _loadLayers(
      NpcAppearance appearance,
      ) async {
    final manifest =
    await AssetManifest.loadFromAssetBundle(
      rootBundle,
    );

    final assets = manifest.listAssets().toSet();

    // Required asset: throw a clear error if missing.
    String requiredAsset(
        String folder,
        String filename,
        ) {
      final path = _path(folder, filename);

      if (!assets.contains(path)) {
        throw StateError(
          'NPC asset not found:\n$path',
        );
      }

      return path;
    }

    // Optional asset: return null when unavailable.
    String? optionalAsset(
        String folder,
        String filename,
        ) {
      final path = _path(folder, filename);

      return assets.contains(path) ? path : null;
    }

    // ---------------------------------------------
    // 1. BASE SKIN
    // ---------------------------------------------

    final skin = requiredAsset(
      'base',
      'base_skin_${_id(appearance.skinTone)}',
    );

    // ---------------------------------------------
    // 2. FACE FEATURES
    // ---------------------------------------------

    final eyes = requiredAsset(
      'eyes',
      'eyes_${_id(appearance.eyes)}',
    );

    final eyebrows = requiredAsset(
      'eyebrows',
      'eyebrows_${_id(appearance.eyebrows)}',
    );

    final nose = requiredAsset(
      'noses',
      'noses_${_id(appearance.nose)}',
    );

    final mouth = requiredAsset(
      'mouths',
      'mouths_${_id(appearance.mouth)}',
    );

    // ---------------------------------------------
    // 3. HAIR FRONT (REQUIRED)
    // ---------------------------------------------

    final hairFront = requiredAsset(
      'hair_front',
      'hair_front_${_id(appearance.hairFront)}',
    );

    // ---------------------------------------------
    // 4. HAIR BACK (OPTIONAL)
    // ---------------------------------------------

    String? hairBack;

    if (appearance.hairBack != null &&
        appearance.hairBack! > 0) {
      hairBack = optionalAsset(
        'hair_back',
        'hair_back_${_id(appearance.hairBack!)}',
      );
    }

    // ---------------------------------------------
    // 5. TATTOO (OPTIONAL)
    // ---------------------------------------------

    String? tattoo;

    if (appearance.tattoo != null &&
        appearance.tattoo! > 0) {
      tattoo = optionalAsset(
        'tattoos',
        'tattoo_${_id(appearance.tattoo!)}',
      );
    }

    // ---------------------------------------------
    // 6. CAREER-BASED OUTFIT
    // ---------------------------------------------

    // Example: hoodie, lab_coat, blazer.
    final outfitName = appearance.outfit
        .replaceFirst(RegExp(r'\.png$'), '');

    final careerOutfit =
        optionalAsset('outfits', outfitName) ??
            optionalAsset('outfits', 'outfit_$outfitName');

    // Fallback to existing casual assets.
    // The same seed always selects the same outfit.
    final casualOutfits = assets
        .where(
          (path) =>
      path.startsWith(
        '$_assetRoot/outfits/outfit_casual_',
      ) &&
          path.toLowerCase().endsWith('.png'),
    )
        .toList()
      ..sort();

    String? outfit = careerOutfit;

    if (outfit == null && casualOutfits.isNotEmpty) {
      final index =
          appearance.seed % casualOutfits.length;

      outfit = casualOutfits[index];
    }

    // ---------------------------------------------
    // 7. FINAL LAYER ORDER
    // Back -> Front
    // ---------------------------------------------

    return [
      // Behind the character's head.
      if (hairBack != null) hairBack,

      // Skin and body.
      skin,

      // Tattoo is drawn on skin.
      if (tattoo != null) tattoo,

      // Outfit covers skin and tattoos.
      if (outfit != null) outfit,

      // Universal facial features.
      eyes,
      eyebrows,
      nose,
      mouth,

      // Main hairstyle and bangs.
      hairFront,
    ];
  }

  // ---------------------------------------------
  // AVATAR RENDERER
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<List<String>>(
        future: _layersFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            );
          }

          final layers = snapshot.data!;

          return RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                for (final path in layers)
                  Image.asset(
                    path,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    gaplessPlayback: true,
                    filterQuality:
                    FilterQuality.high,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
