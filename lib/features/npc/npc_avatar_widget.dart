import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'npc_appearance.dart';

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

enum _Part { outfit, face, nose, eyes, mouth, hair }

class _Layer {
  const _Layer(this.part, this.path);

  final _Part part;
  final String path;
}

class _NpcAvatarWidgetState extends State<NpcAvatarWidget> {
  static const String _root = 'lib/core/assets/npc/front';
  static const double _canvasW = 1122;
  static const double _canvasH = 1402;
  static Future<Map<String, List<String>>>? _catalogFuture;
  late Future<List<_Layer>> _layersFuture;

  @override
  void initState() {
    super.initState();
    _layersFuture = _resolve(widget.appearance);
  }

  @override
  void didUpdateWidget(covariant NpcAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearance != widget.appearance) {
      _layersFuture = _resolve(widget.appearance);
    }
  }

  static Future<Map<String, List<String>>> _catalog() =>
      _catalogFuture ??= _loadCatalog();

  static Future<Map<String, List<String>>> _loadCatalog() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final all = manifest.listAssets();
    final result = <String, List<String>>{};


    for (final folder in const ['faces', 'eyes', 'hair', 'mouth', 'noses', 'outfits',]) {
      final prefix = '$_root/$folder/';
      final files = all.where((path) {
        if (!path.startsWith(prefix)) return false;
        final name = path.substring(prefix.length);
        if (name.contains('/')) return false;
        final lower = name.toLowerCase();
        return lower.endsWith('.png') || lower.endsWith('.webp');
      }).toList()..sort();
      result[folder] = files;
    }
    return result;
  }

  static String? _pick(
      Map<String, List<String>> catalog,
      String folder,
      int selection, {
        bool optional = false,
      }) {
    final paths = catalog[folder] ?? const <String>[];
    if (paths.isEmpty) {
      if (optional) return null;
      throw StateError('No NPC assets found in $_root/$folder/');
    }
    return paths[(selection - 1) % paths.length];
  }

  static String _pickOutfit(
      Map<String, List<String>> catalog,
      NpcAppearance appearance,
      ) {
    final paths = catalog['outfits'] ?? const <String>[];
    if (paths.isEmpty) {
      throw StateError('No NPC outfit assets found in $_root/outfits/');
    }

    final style = appearance.outfit
        .toLowerCase()
        .trim()
        .replaceFirst(RegExp(r'\.(png|webp)$'), '');

    for (final path in paths) {
      final fileName = path.split('/').last.toLowerCase();
      if (fileName == '$style.png' ||
          fileName == '$style.webp' ||
          fileName == 'outfit_$style.png' ||
          fileName == 'outfit_$style.webp') {
        return path;
      }
    }
    return paths[(appearance.outfitVariant - 1) % paths.length];
  }


  static Future<List<_Layer>> _resolve(
      NpcAppearance appearance,
      ) async {
    final catalog = await _catalog();

    final outfit = _pickOutfit(
      catalog,
      appearance,
    );

    final face = _pick(
      catalog,
      'faces',
      appearance.face,
    )!;

    final nose = _pick(
      catalog,
      'noses',
      appearance.nose,
      optional: true,
    );

    final eyes = _pick(
      catalog,
      'eyes',
      appearance.eyes,
    )!;

    // NEW: Mouth asset
    // Uses the same stable seed as the NPC.
    final mouth = _pick(
      catalog,
      'mouth',
      appearance.seed,
      optional: true,
    );

    final hair = _pick(
      catalog,
      'hair',
      appearance.hair,
    )!;

    // Back to front rendering order.
    return [
      _Layer(_Part.outfit, outfit),
      _Layer(_Part.face, face),

      if (nose != null)
        _Layer(_Part.nose, nose),

      _Layer(_Part.eyes, eyes),

      if (mouth != null)
        _Layer(_Part.mouth, mouth),

      _Layer(_Part.hair, hair),
    ];
  }


  Widget _drawLayer(_Layer layer) {
    final image = Image.asset(
      layer.path,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );

    // ==================================================
    // CALIBRATION
    // Face is the main anchor.
    // ==================================================
    const double faceShiftY = 0.0;
    const double outfitShiftY = 200.0;
    const double eyesShiftY = 100.0;
    const double noseShiftY = 150.0;

    // Rambut tetap agak naik dan sedikit diperkecil
    const double hairScale = 0.95;
    const double hairShiftY = -18.0;

    // ==================================================
    // OUTFIT
    // ==================================================
    if (layer.part == _Part.outfit) {
      return Positioned(
        left: 0,
        top: outfitShiftY,
        width: _canvasW,
        height: _canvasH,
        child: image,
      );
    }

    // ==================================================
    // FACE (ANCHOR)
    // ==================================================
    if (layer.part == _Part.face) {
      return Positioned(
        left: 0,
        top: faceShiftY,
        width: _canvasW,
        height: _canvasH,
        child: image,
      );
    }

    // ==================================================
    // EYES
    // ==================================================
    if (layer.part == _Part.eyes) {
      return Positioned(
        left: 0,
        top: faceShiftY + eyesShiftY,
        width: _canvasW,
        height: _canvasH,
        child: image,
      );
    }

    // ==================================================
    // NOSE
    // ==================================================
    if (layer.part == _Part.nose) {
      return Positioned(
        left: 0,
        top: faceShiftY + noseShiftY,
        width: _canvasW,
        height: _canvasH,
        child: image,
      );
    }

    // ==================================================
    // MOUTH — SCALE WITHOUT LOSING POSITION
    // ==================================================
    if (layer.part == _Part.mouth) {

      // Ukuran bibir
      const double mouthScale = 0.38;

      // Posisi bibir tetap seperti sebelumnya
      const double mouthShiftX = 0.0;
      const double mouthShiftY = 110.0;

      // Titik anchor bibir pada canvas 1122x1402
      const double mouthAnchorX = 561.0;
      const double mouthAnchorY = 850.0;

      final mouthAlignment = Alignment(
        (2 * mouthAnchorX / _canvasW) - 1,
        (2 * mouthAnchorY / _canvasH) - 1,
      );

      return Positioned.fill(
        child: Transform.translate(
          offset: const Offset(
            mouthShiftX,
            mouthShiftY,
          ),
          child: Transform.scale(
            scale: mouthScale,
            alignment: mouthAlignment,
            child: image,
          ),
        ),
      );
    }

    // ==================================================
    // HAIR
    // ==================================================
    if (layer.part == _Part.hair) {
      final hairWidth = _canvasW * hairScale;
      final hairHeight = _canvasH * hairScale;

      return Positioned(
        left: (_canvasW - hairWidth) / 2,
        top: faceShiftY + hairShiftY,
        width: hairWidth,
        height: hairHeight,
        child: image,
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * (_canvasH / _canvasW),
      child: FutureBuilder<List<_Layer>>(
        future: _layersFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return RepaintBoundary(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _canvasW,
                height: _canvasH,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [for (final layer in snapshot.data!) _drawLayer(layer)],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
