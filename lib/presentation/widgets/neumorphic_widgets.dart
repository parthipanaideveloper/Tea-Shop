import 'package:flutter/material.dart';

/// Core Neumorphic design tokens
class NeumorphicTheme {
  static const Color background = Color(0xFFF0F4F8);
  static const Color cardColor = Color(0xFFF0F4F8);
  static const Color lightShadow = Color(0xFFFFFFFF);
  static const Color darkShadow = Color(0xFFD1D9E6);
  
  static const Color primary = Color(0xFF3B82F6); // Modern SaaS blue
  static const Color primaryGlow = Color(0x3D3B82F6);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  
  static List<BoxShadow> outerShadows({
    double offsetValue = 6.0,
    double blurValue = 12.0,
    Color light = lightShadow,
    Color dark = darkShadow,
  }) {
    return [
      BoxShadow(
        color: light,
        offset: Offset(-offsetValue, -offsetValue),
        blurRadius: blurValue,
      ),
      BoxShadow(
        color: dark,
        offset: Offset(offsetValue, offsetValue),
        blurRadius: blurValue,
      ),
    ];
  }
}

/// A premium floating Neumorphic card with hover-lift animation
class NeumorphicCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double depth;
  final Color? borderColor;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.all(20.0),
    this.depth = 6.0,
    this.borderColor,
  });

  @override
  State<NeumorphicCard> createState() => _NeumorphicCardState();
}

class _NeumorphicCardState extends State<NeumorphicCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cardBgColor = widget.color ?? NeumorphicTheme.cardColor;
    
    // Animate shadows and scale on hover/press
    final currentDepth = _isPressed 
        ? 1.0 
        : (_isHovered ? widget.depth * 1.5 : widget.depth);
    final currentBlur = _isPressed 
        ? 2.0 
        : (_isHovered ? widget.depth * 2.5 : widget.depth * 2.0);
    final currentScale = _isPressed
        ? 0.98
        : (_isHovered ? 1.015 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: widget.onTap != null ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: currentScale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: widget.borderColor != null
                  ? Border.all(color: widget.borderColor!, width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: NeumorphicTheme.lightShadow,
                  offset: Offset(-currentDepth, -currentDepth),
                  blurRadius: currentBlur,
                ),
                BoxShadow(
                  color: NeumorphicTheme.darkShadow,
                  offset: Offset(currentDepth, currentDepth),
                  blurRadius: currentBlur,
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Neumorphic Button with click feedback and soft glow
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final Color? color;
  final bool isSelected;
  final EdgeInsetsGeometry padding;

  const NeumorphicButton({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 14.0,
    this.color,
    this.isSelected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isClicked = _isPressed || widget.isSelected;
    final buttonColor = widget.color ?? NeumorphicTheme.cardColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.isSelected
                ? Border.all(color: NeumorphicTheme.primary.withOpacity(0.5), width: 1.5)
                : null,
            gradient: isClicked
                ? LinearGradient(
                    colors: [
                      NeumorphicTheme.darkShadow.withOpacity(0.2),
                      NeumorphicTheme.lightShadow.withOpacity(0.2)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      NeumorphicTheme.lightShadow,
                      NeumorphicTheme.darkShadow.withOpacity(0.3)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: isClicked
                ? [
                    BoxShadow(
                      color: NeumorphicTheme.lightShadow.withOpacity(0.5),
                      offset: const Offset(1, 1),
                      blurRadius: 1,
                    ),
                    BoxShadow(
                      color: NeumorphicTheme.darkShadow.withOpacity(0.5),
                      offset: const Offset(-1, -1),
                      blurRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: NeumorphicTheme.lightShadow,
                      offset: _isHovered ? const Offset(-4, -4) : const Offset(-3, -3),
                      blurRadius: _isHovered ? 8 : 6,
                    ),
                    BoxShadow(
                      color: NeumorphicTheme.darkShadow,
                      offset: _isHovered ? const Offset(4, 4) : const Offset(3, 3),
                      blurRadius: _isHovered ? 8 : 6,
                    ),
                    if (widget.isSelected)
                      BoxShadow(
                        color: NeumorphicTheme.primary.withOpacity(0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Circular Neumorphic Icon Button
class NeumorphicIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;
  final double size;
  final double padding;

  const NeumorphicIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.iconColor,
    this.size = 20.0,
    this.padding = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicButton(
      onTap: onTap,
      borderRadius: 50.0,
      color: color,
      padding: EdgeInsets.all(padding),
      child: Icon(
        icon,
        size: size,
        color: iconColor ?? NeumorphicTheme.textPrimary,
      ),
    );
  }
}

/// Concave text input container
class NeumorphicTextField extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const NeumorphicTextField({
    super.key,
    required this.child,
    this.borderRadius = 14.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: NeumorphicTheme.cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: [
            NeumorphicTheme.darkShadow.withOpacity(0.15),
            NeumorphicTheme.lightShadow.withOpacity(0.9)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: NeumorphicTheme.darkShadow.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}
