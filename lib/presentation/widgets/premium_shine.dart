import 'package:flutter/material.dart';

class PremiumShineText extends StatefulWidget {
  final Widget child;
  const PremiumShineText({super.key, required this.child});

  @override
  State<PremiumShineText> createState() => _PremiumShineTextState();
}

class _PremiumShineTextState extends State<PremiumShineText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -1.0),
              end: const Alignment(2.0, 2.0),
              colors: const [
                Color(0xFF1E1B4B),
                Color(0xFF4F46E5),
                Color(0xFF818CF8),
                Color(0xFF4F46E5),
                Color(0xFF1E1B4B),
              ],
              stops: [
                0.0,
                value - 0.2,
                value,
                value + 0.2,
                1.0,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class PremiumShineCardOverlay extends StatefulWidget {
  final double borderRadius;
  const PremiumShineCardOverlay({super.key, this.borderRadius = 24});

  @override
  State<PremiumShineCardOverlay> createState() => _PremiumShineCardOverlayState();
}

class _PremiumShineCardOverlayState extends State<PremiumShineCardOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = _controller.value;
            // Sweep from -1 to 2
            final position = (value * 3) - 1.0; 
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-1.0, -1.0),
                  end: const Alignment(2.0, 2.0),
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.8),
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: [
                    0.0,
                    (position - 0.2).clamp(0.0, 1.0),
                    position.clamp(0.0, 1.0),
                    (position + 0.2).clamp(0.0, 1.0),
                    1.0,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
