import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'npc_appearance.dart';

/// Layered portrait for the front-facing NPC PNG assets.
///
/// All layers share one 1054 x 1255 design space, but each PNG keeps its own
/// intrinsic aspect ratio. The finished portrait is scaled as a single image.
/// This prevents thin eyes / eyebrows and square nose PNGs from stretching to
/// the entire avatar container.
class NpcAvatarWidget extends StatefulWidget {
  const NpcAvatarWidget({
    super.key,
    required this.appearance,
    this.size = 250,
  });

  final NpcAppearance appearance;
  final double size;

  @override
  State<NpcAvatarWidget> createState() => _NpcAvatarWidgetState();
}

class _NpcAvatarWidgetState extends State<NpcAvatarWidget> {
  static const String _assetRoot = 'lib/core/assets/npc/front';

  static const double _designWidth = 1054;
  static const double _designHeight = 1255;

  // Asset sizes verified against the PNGs in front.rar. Never treat every
  // feature as having the same natural ratio.
  static const List<Size> _hairFrontSizes = [
    Size(866, 883),
    Size(915, 933),
    Size(934, 905),
    Size(883, 1200),
    Size(849, 1190),
  ];

  static const List<Size> _eyeSizes = [
    Size(1526, 228),
    Size(1584, 208),
    Size(1526, 253),
    Size(1630, 197),
    Size(1496, 235),
  ];

  static const List<Size> _mouthSizes = [
    Size(332, 143),
    Size(346, 128),
    Size(313, 176),
    Size(312, 133),
    Size(317, 167),
  ];

  static const List<Size> _outfitSizes = [
    Size(653, 645),
    Size(653, 645),
    Size(550, 569),
    Size(1254, 1254),
    Size(1120, 1405),
  ];

  // Share the manifest lookup across all cards, instead of reloading it for
  // every visible/background NPC on every swipe.
  static Future<Set<String>>? _assetManifestFuture;
  late Future<List<String>> _layersFuture;

  @override
  void initState() {
    super.initState();
    _layersFuture = _loadLayers(widget.appearance);
  }

  @override
  void didUpdateWidget(covariant NpcAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearance != widget.appearance) {
      _layersFuture = _loadLayers(widget.appearance);
    }
  }

  static Future<Set<String>> _availableAssets() {
    return _assetManifestFuture ??=
        AssetManifest.loadFromAssetBundle(rootBundle).then(
              (manifest) => manifest.listAssets().toSet(),
        );
  }

  String _id(int value) => value.toString().padLeft(2, '0');

  String _path(String folder, String filename) =>
      '$_assetRoot/$folder/$filename.png';

  Future<List<String>> _loadLayers(NpcAppearance appearance) async {
    final assets = await _availableAssets();

    String requiredAsset(String folder, String name) {
      final path = _path(folder, name);
      if (!assets.contains(path)) {
        throw StateError('NPC asset not found: $path');
      }
      return path;
    }

    String? optionalAsset(String folder, String name) {
      final path = _path(folder, name);
      return assets.contains(path) ? path : null;
    }

    final skin = requiredAsset(
      'base',
      'base_skin_${_id(appearance.skinTone)}',
    );
    final eyes = requiredAsset('eyes', 'eyes_${_id(appearance.eyes)}');
    final eyebrows = requiredAsset(
      'eyebrows',
      'eyebrows_${_id(appearance.eyebrows)}',
    );
    final nose = requiredAsset('noses', 'noses_${_id(appearance.nose)}');
    final mouth = requiredAsset('mouths', 'mouths_${_id(appearance.mouth)}');
    final hairFront = requiredAsset(
      'hair_front',
      'hair_front_${_id(appearance.hairFront)}',
    );

    // All 5 front hairs have matching back layers. Also supports older saved
    // NPCs whose hairBack was null because the original generator disabled it.
    final hairBackNumber = appearance.hairBack ?? appearance.hairFront;
    final hairBack = optionalAsset(
      'hair_back',
      'hair_back_${_id(hairBackNumber)}',
    );

    final tattoo = appearance.tattoo == null
        ? null
        : optionalAsset('tattoos', 'tattoo_${_id(appearance.tattoo!)}');

    // Real career-specific PNGs win if they're ever added to this asset folder.
    final outfitName = appearance.outfit.replaceFirst(RegExp(r'\.png$'), '');
    String? outfit = optionalAsset('outfits', outfitName) ??
        optionalAsset('outfits', 'outfit_$outfitName');

    if (outfit == null) {
      // These semantic names are currently generated, but only 5 casual PNGs
      // actually exist. Match available styles as closely as possible.
      final List<int> choices = switch (outfitName) {
        'hoodie' => [4, 5],
        'graphic_tee' => [1, 2],
        'oxford_shirt' => [3],
        'knit_sweater' => [4, 5],
        _ => [1, 2, 3, 4, 5],
      };
      final pick = choices[appearance.seed % choices.length];
      outfit = optionalAsset('outfits', 'outfit_casual_${_id(pick)}');
    }

    // Back -> front. Outfit overlays shoulders, facial features overlay face,
    // and the front hairstyle overlays the forehead / temples.
    return [
      if (hairBack != null) hairBack,
      skin,
      if (tattoo != null) tattoo,
      if (outfit != null) outfit,
      nose,
      eyes,
      eyebrows,
      mouth,
      hairFront,
    ];
  }

  int _assetIndex(String path) {
    final fileName = path.split('/').last;
    final match = RegExp(r'_(\d+)\.png$').firstMatch(fileName);
    return int.tryParse(match?.group(1) ?? '') ?? 1;
  }

  // A layer is positioned on the common design canvas, not relative to the
  // screen or the size passed by DiscoverScreen.
  Widget _positionedLayer(String path) {
    final index = _assetIndex(path).clamp(1, 5).toInt() - 1;

    double left;
    double top;
    double width;
    Size naturalSize;

    if (path.contains('/hair_back/')) {
      left = -34;
      top = -10;
      width = 1122;
      naturalSize = const Size(1122, 1402);
    } else if (path.contains('/base/')) {
      return const SizedBox.shrink(); // handled below by _baseLayer
    } else if (path.contains('/outfits/')) {
      width = index < 3 ? 1020 : 960;
      left = (_designWidth - width) / 2;
      top = 825;
      naturalSize = _outfitSizes[index];
    } else if (path.contains('/noses/')) {
      width = 250;
      left = (_designWidth - width) / 2;
      top = 370;
      naturalSize = const Size(1254, 1254);
    } else if (path.contains('/eyes/')) {
      left = 310;
      top = 435;
      width = 434;
      naturalSize = _eyeSizes[index];
    } else if (path.contains('/eyebrows/')) {
      left = 306;
      top = 312;
      width = 442;
      naturalSize = const Size(2172, 724);
    } else if (path.contains('/mouths/')) {
      width = 190;
      left = (_designWidth - width) / 2;
      top = 656;
      naturalSize = _mouthSizes[index];
    } else if (path.contains('/hair_front/')) {
      left = 55;
      top = -40;
      width = 944;
      naturalSize = _hairFrontSizes[index];
    } else if (path.contains('/tattoos/')) {
      left = 385;
      top = 745;
      width = 284;
      naturalSize = const Size(284, 284);
    } else {
      return const SizedBox.shrink();
    }

    final height = width * naturalSize.height / naturalSize.width;
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
  }

  Widget _baseLayer(String path) {
    return Positioned(
      left: 0,
      top: 0,
      width: _designWidth,
      height: _designHeight,
      child: ClipPath(
        clipper: const _NeckAndFaceClipper(),
        child: Image.asset(
          path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
      ),
    );
  }

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
              child: Text(
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          return RepaintBoundary(
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: _designWidth,
                  height: _designHeight,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      for (final path in snapshot.data!)
                        if (path.contains('/base/'))
                          _baseLayer(path)
                        else
                          _positionedLayer(path),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Prevent the skin PNG's illustrated bare shoulders from showing outside the
/// actual outfit. The full face and neck remain intact; only the lower outside
/// shoulder area is clipped. Coordinates use the fixed 1054x1255 canvas.
class _NeckAndFaceClipper extends CustomClipper<Path> {
  const _NeckAndFaceClipper();

  @override
  Path getClip(Size size) {
    final sx = size.width / 1054;
    final sy = size.height / 1255;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 840 * sy)
      ..lineTo(790 * sx, 840 * sy)
      ..lineTo(740 * sx, 880 * sy)
      ..lineTo(680 * sx, 930 * sy)
      ..lineTo(660 * sx, 1050 * sy)
      ..lineTo(650 * sx, size.height)
      ..lineTo(404 * sx, size.height)
      ..lineTo(394 * sx, 1050 * sy)
      ..lineTo(374 * sx, 930 * sy)
      ..lineTo(314 * sx, 880 * sy)
      ..lineTo(264 * sx, 840 * sy)
      ..lineTo(0, 840 * sy)
      ..close();
  }

  @override
  bool shouldReclip(covariant _NeckAndFaceClipper oldClipper) => false;
}
