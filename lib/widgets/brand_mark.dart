import 'package:copy_paste_plus/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Clipboard + Plus mark matching the product branding.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.iconSize = 28,
    this.fontSize = 18,
    this.showSubtitle,
    this.compact = false,
    this.enableGlitch = true,
  });

  final double iconSize;
  final double fontSize;
  final String? showSubtitle;
  final bool compact;
  final bool enableGlitch;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final title = _BrandTitle(
      fontSize: fontSize,
      enableGlitch: enableGlitch,
      ink: palette.ink,
      accent: palette.accent,
      pink: palette.accentPink,
      cyan: palette.cyan,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandClipboardIcon(size: iconSize),
        SizedBox(width: compact ? 8 : 10),
        if (showSubtitle == null)
          title
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              title,
              const SizedBox(height: 2),
              Text(
                showSubtitle!,
                style: TextStyle(
                  fontSize: fontSize * 0.68,
                  color: palette.muted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Title treatment inspired by fso13 `.hero-name` (letter-spacing + hover glitch).
class _BrandTitle extends StatefulWidget {
  const _BrandTitle({
    required this.fontSize,
    required this.enableGlitch,
    required this.ink,
    required this.accent,
    required this.pink,
    required this.cyan,
  });

  final double fontSize;
  final bool enableGlitch;
  final Color ink;
  final Color accent;
  final Color pink;
  final Color cyan;

  @override
  State<_BrandTitle> createState() => _BrandTitleState();
}

class _BrandTitleState extends State<_BrandTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glitch;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _glitch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _glitch.dispose();
    super.dispose();
  }

  void _setHover(bool value) {
    if (!widget.enableGlitch || _hover == value) return;
    setState(() => _hover = value);
    if (value) {
      _glitch.repeat();
    } else {
      _glitch
        ..stop()
        ..value = 0;
    }
  }

  TextStyle _base(Color color) => TextStyle(
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -0.03 * widget.fontSize,
        color: color,
      );

  Widget _label({Color? copyPasteColor, Color? plusColor}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'CopyPaste',
            style: _base(copyPasteColor ?? widget.ink),
          ),
          TextSpan(
            text: 'Plus',
            style: _base(plusColor ?? widget.accent),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mirror CSS:
    // text-shadow: 2px 0 pink, -2px 0 cyan;
    // animation: translate jitter while .is-glitch
    final content = AnimatedBuilder(
      animation: _glitch,
      builder: (context, child) {
        final t = _glitch.value;
        Offset offset = Offset.zero;
        if (_hover) {
          if (t < 0.2) {
            offset = const Offset(-1, 1);
          } else if (t < 0.4) {
            offset = const Offset(1, -1);
          } else if (t < 0.6) {
            offset = const Offset(-1, 0);
          } else if (t < 0.8) {
            offset = const Offset(1, 1);
          }
        }

        return Transform.translate(
          offset: offset,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_hover) ...[
                Transform.translate(
                  offset: const Offset(2, 0),
                  child: _label(
                    copyPasteColor: widget.pink,
                    plusColor: widget.pink,
                  ),
                ),
                Transform.translate(
                  offset: const Offset(-2, 0),
                  child: _label(
                    copyPasteColor: widget.cyan,
                    plusColor: widget.cyan,
                  ),
                ),
              ],
              _label(),
            ],
          ),
        );
      },
    );

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      cursor: SystemMouseCursors.basic,
      child: content,
    );
  }
}

class BrandClipboardIcon extends StatelessWidget {
  const BrandClipboardIcon({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final badge = size * 0.42;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.content_paste_outlined,
            size: size * 0.92,
            color: palette.accent,
          ),
          Positioned(
            right: -size * 0.06,
            bottom: -size * 0.04,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
                border: Border.all(color: palette.bg, width: size * 0.06),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                Icons.add,
                size: badge * 0.72,
                color: palette.bgDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
