import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../consts.dart';
import '../../models/model.dart';
import '../studio_theme.dart';

/// Shared texture renderer for screen wall views.
///
/// Extracts the common Texture rendering logic used by both
/// [WallRemoteView] and [WallFullscreenView].
class WallTextureRenderer extends StatelessWidget {
  final FFI ffi;

  /// Widget shown while waiting for the texture to be ready.
  final Widget? placeholder;

  const WallTextureRenderer({
    Key? key,
    required this.ffi,
    this.placeholder,
  }) : super(key: key);

  Widget get _defaultPlaceholder => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: StudioTheme.accentCyan,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: ffi.ffiModel,
      child: Consumer<FfiModel>(
        builder: (context, ffiModel, _) {
          if (ffiModel.pi.isSet.isFalse ||
              ffiModel.waitForFirstImage.isTrue) {
            return placeholder ?? _defaultPlaceholder;
          }

          final curDisplay = ffiModel.pi.currentDisplay;
          final displays = ffiModel.pi.getCurDisplays();
          if (displays.isEmpty) return const SizedBox.shrink();

          ffi.textureModel.updateCurrentDisplay(curDisplay);
          final displayIndex =
              curDisplay == kAllDisplayValue ? 0 : curDisplay;
          final textureId = ffi.textureModel.getTextureId(displayIndex);

          return Obx(() {
            if (textureId.value == -1) {
              return placeholder ?? _defaultPlaceholder;
            }
            return FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: displays[0].width.toDouble(),
                height: displays[0].height.toDouble(),
                child: Texture(
                  textureId: textureId.value,
                  filterQuality: FilterQuality.low,
                ),
              ),
            );
          });
        },
      ),
    );
  }
}
