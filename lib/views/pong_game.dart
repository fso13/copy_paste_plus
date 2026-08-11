import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Arcade Pong overlay — inspired by fso13 `pong.js`.
class PongGameOverlay extends StatefulWidget {
  const PongGameOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  static Future<void> open(BuildContext context) async {
    final previousSize = await windowManager.getSize();
    await windowManager.setSize(const Size(760, 560));
    await windowManager.center();

    if (!context.mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PongGameOverlay(
          onClose: () async {
            Navigator.of(context).pop();
            await windowManager.setSize(previousSize);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<PongGameOverlay> createState() => _PongGameOverlayState();
}

class _PongGameOverlayState extends State<PongGameOverlay>
    with SingleTickerProviderStateMixin {
  static const double fieldW = 720;
  static const double fieldH = 420;
  static const double paddleW = 12;
  static const double paddleH = 72;
  static const double paddleSpeed = 6.4;
  static const double ballR = 5;

  late final AnimationController _ticker;
  late final FocusNode _focusNode;
  final _keys = <LogicalKeyboardKey>{};
  final _rng = Random();

  double _leftY = fieldH / 2 - paddleH / 2;
  double _rightY = fieldH / 2 - paddleH / 2;
  double _ballX = fieldW / 2;
  double _ballY = fieldH / 2;
  double _ballVx = 0;
  double _ballVy = 0;
  int _scoreL = 0;
  int _scoreR = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _resetMatch();
    _ticker.repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetBall([int direction = 1]) {
    _ballX = fieldW / 2;
    _ballY = fieldH / 2;
    final angle = (_rng.nextDouble() * 0.65 - 0.325) * pi;
    const speed = 5.1;
    _ballVx = cos(angle) * speed * direction;
    _ballVy = sin(angle) * speed;
  }

  void _resetMatch() {
    _scoreL = 0;
    _scoreR = 0;
    _leftY = fieldH / 2 - paddleH / 2;
    _rightY = fieldH / 2 - paddleH / 2;
    _paused = false;
    _resetBall(1);
  }

  void _clampPaddle(void Function(double) setY, double y) {
    setY(y.clamp(14, fieldH - 14 - paddleH));
  }

  bool _hitLeft() {
    return _ballX - ballR < 28 + paddleW &&
        _ballX + ballR > 28 &&
        _ballY > _leftY &&
        _ballY < _leftY + paddleH;
  }

  bool _hitRight() {
    final x = fieldW - 28 - paddleW;
    return _ballX + ballR > x &&
        _ballX - ballR < x + paddleW &&
        _ballY > _rightY &&
        _ballY < _rightY + paddleH;
  }

  void _tick() {
    if (_paused || !mounted) return;

    if (_keys.contains(LogicalKeyboardKey.arrowUp) ||
        _keys.contains(LogicalKeyboardKey.keyW)) {
      _clampPaddle((v) => _leftY = v, _leftY - paddleSpeed);
    }
    if (_keys.contains(LogicalKeyboardKey.arrowDown) ||
        _keys.contains(LogicalKeyboardKey.keyS)) {
      _clampPaddle((v) => _leftY = v, _leftY + paddleSpeed);
    }

    final target = _ballY - paddleH / 2;
    final aiError = (_rng.nextDouble() - 0.5) * 18;
    final aiSpeed = paddleSpeed * 0.78;
    final diff = target + aiError - _rightY;
    final step = (diff * 0.12).clamp(-aiSpeed, aiSpeed);
    _rightY = (_rightY + step).clamp(14, fieldH - 14 - paddleH);

    _ballX += _ballVx;
    _ballY += _ballVy;

    if (_ballY - ballR < 14 || _ballY + ballR > fieldH - 14) {
      _ballVy *= -1;
      _ballY = _ballY.clamp(14 + ballR, fieldH - 14 - ballR);
    }

    if (_ballVx < 0 && _hitLeft()) {
      _ballVx = _ballVx.abs() * 1.04;
      final offset = (_ballY - (_leftY + paddleH / 2)) / (paddleH / 2);
      _ballVy = offset * 5.2;
      _ballX = 28 + paddleW + ballR;
    }

    if (_ballVx > 0 && _hitRight()) {
      _ballVx = -_ballVx.abs() * 1.04;
      final offset = (_ballY - (_rightY + paddleH / 2)) / (paddleH / 2);
      _ballVy = offset * 5.2;
      _ballX = fieldW - 28 - paddleW - ballR;
    }

    _ballVx = _ballVx.clamp(-11, 11);
    _ballVy = _ballVy.clamp(-11, 11);

    if (_ballX < -20) {
      _scoreR += 1;
      _resetBall(1);
    } else if (_ballX > fieldW + 20) {
      _scoreL += 1;
      _resetBall(-1);
    }

    setState(() {});
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onClose();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _togglePause();
        return KeyEventResult.handled;
      }
      if ({
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyS,
      }.contains(event.logicalKey)) {
        _keys.add(event.logicalKey);
        return KeyEventResult.handled;
      }
    }
    if (event is KeyUpEvent) {
      _keys.remove(event.logicalKey);
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: min(860, MediaQuery.sizeOf(context).width - 24),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF191A21),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF44475A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: const Color(0xFF0D0E12),
                  child: Row(
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MiniDot(Color(0xFFFF5555)),
                          SizedBox(width: 6),
                          _MiniDot(Color(0xFFF1FA8C)),
                          SizedBox(width: 6),
                          _MiniDot(Color(0xFF50FA7B)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'root@copypasteplus:~ ./pong --vs-cpu',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 11,
                            color: Color(0xFFC7D0DC),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, size: 18),
                        color: const Color(0xFFF8F8F2),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: const Color(0xFF111111),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Player1',
                              style: TextStyle(
                                fontFamily: 'Menlo',
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _togglePause,
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF8BE9FD),
                              foregroundColor: const Color(0xFF111111),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Text(
                              _paused ? 'RESUME' : 'PAUSE',
                              style: const TextStyle(
                                fontFamily: 'Menlo',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'CPU',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Menlo',
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AspectRatio(
                        aspectRatio: fieldW / fieldH,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return MouseRegion(
                              onHover: (event) {
                                if (_paused) return;
                                final scale = fieldH / constraints.maxHeight;
                                setState(() {
                                  _leftY = (event.localPosition.dy * scale) -
                                      paddleH / 2;
                                  _leftY = _leftY.clamp(
                                    14,
                                    fieldH - 14 - paddleH,
                                  );
                                });
                              },
                              child: CustomPaint(
                                painter: _PongPainter(
                                  leftY: _leftY,
                                  rightY: _rightY,
                                  ballX: _ballX,
                                  ballY: _ballY,
                                  scoreL: _scoreL,
                                  scoreR: _scoreR,
                                  paused: _paused,
                                  paddleW: paddleW,
                                  paddleH: paddleH,
                                  ballR: ballR,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'W/S или ↑/↓ — ракетка · Space — пауза · Esc — выход',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 10,
                          color: Color(0xFF6272A4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniDot extends StatelessWidget {
  const _MiniDot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PongPainter extends CustomPainter {
  _PongPainter({
    required this.leftY,
    required this.rightY,
    required this.ballX,
    required this.ballY,
    required this.scoreL,
    required this.scoreR,
    required this.paused,
    required this.paddleW,
    required this.paddleH,
    required this.ballR,
  });

  final double leftY;
  final double rightY;
  final double ballX;
  final double ballY;
  final int scoreL;
  final int scoreR;
  final bool paused;
  final double paddleW;
  final double paddleH;
  final double ballR;

  static const fieldW = 720.0;
  static const fieldH = 420.0;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / fieldW;
    final sy = size.height / fieldH;
    canvas.scale(sx, sy);

    final fill = Paint()..color = Colors.black;
    canvas.drawRect(const Rect.fromLTWH(0, 0, fieldW, fieldH), fill);

    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(10, 10), const Offset(fieldW - 10, 10), line);
    canvas.drawLine(
      const Offset(10, fieldH - 10),
      const Offset(fieldW - 10, fieldH - 10),
      line,
    );

    final dash = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    for (double y = 18; y < fieldH - 18; y += 22) {
      canvas.drawLine(
        Offset(fieldW / 2, y),
        Offset(fieldW / 2, y + 10),
        dash,
      );
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void drawScore(String text, double x) {
      textPainter.text = TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.bold,
          fontFamily: 'Menlo',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 20));
    }

    drawScore('$scoreL', fieldW / 2 - 54);
    drawScore('$scoreR', fieldW / 2 + 54);
    canvas.drawRect(
      const Rect.fromLTWH(fieldW / 2 - 4, 38, 8, 8),
      Paint()..color = Colors.white,
    );

    final paddlePaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(28, leftY, paddleW, paddleH), paddlePaint);
    canvas.drawRect(
      Rect.fromLTWH(fieldW - 28 - paddleW, rightY, paddleW, paddleH),
      paddlePaint,
    );
    canvas.drawCircle(Offset(ballX, ballY), ballR, paddlePaint);

    if (paused) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, fieldW, fieldH),
        Paint()..color = const Color(0x8C000000),
      );
      textPainter.text = const TextSpan(
        text: 'PAUSE',
        style: TextStyle(
          color: Color(0xFF8BE9FD),
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontFamily: 'Menlo',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          fieldW / 2 - textPainter.width / 2,
          fieldH / 2 - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PongPainter oldDelegate) => true;
}
