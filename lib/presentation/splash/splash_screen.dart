import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Setup animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // 1 second for the entrance
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack)),
    );
    
    _rotationAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic)),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // Start animation immediately
    _controller.forward();
    
    // 2-second hold and transition
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  ImageProvider? _getLogoProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.length < 255 && File(path).existsSync()) {
      return FileImage(File(path));
    }
    try {
      String cleanBase64 = path;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
      while (cleanBase64.length % 4 != 0) {
        cleanBase64 += '=';
      }
      return MemoryImage(base64Decode(cleanBase64));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final logoProvider = _getLogoProvider(settings.shopLogoPath);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SizedBox(
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                // Radiant Aura
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.22), // Push down to top ~30% area
                          // Spinning Shop Logo
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotationAnimation.value * 3.14159 * 2, // Spin 360 degrees
                                child: Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                        blurRadius: 40,
                                        spreadRadius: 10,
                                        offset: const Offset(0, 15),
                                      ),
                                    ],
                                    image: logoProvider != null
                                        ? DecorationImage(
                                            image: logoProvider,
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: logoProvider == null
                                      ? Icon(
                                          Icons.storefront_rounded,
                                          size: 90,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Shop Name with Shimmer effect overlay
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                settings.shopName.isNotEmpty 
                                    ? settings.shopName.toUpperCase() 
                                    : 'DTS POS',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5,
                                  color: theme.colorScheme.primary,
                                  shadows: [
                                    Shadow(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              // Shimmer sweep across the text
                              Positioned.fill(
                                child: ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        theme.colorScheme.secondary.withValues(alpha: 0.9), // Bright Cyan glow
                                        Colors.white,
                                        theme.colorScheme.secondary.withValues(alpha: 0.9),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                                      // Start shimmer halfway through
                                      begin: Alignment(_controller.value * 4 - 2.5, 0),
                                      end: Alignment(_controller.value * 4 - 1.5, 0),
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.srcATop,
                                  child: Text(
                                    settings.shopName.isNotEmpty 
                                        ? settings.shopName.toUpperCase() 
                                        : 'DTS POS',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.5,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          
                          // Medium Dot Pop Animation
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (index) {
                                  // Stagger the bounce for each dot
                                  final delay = index * 0.2;
                                  double t = (_pulseController.value - delay) * 2.0;
                                  if (t < 0) t = 0;
                                  if (t > 1.0) t = 0;
                                  
                                  // Sine wave bounce
                                  final bounce = math.sin(t * math.pi);
                                  
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Transform.translate(
                                      offset: Offset(0, -bounce * 15),
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.4 + (bounce * 0.6)),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.colorScheme.primary.withValues(alpha: bounce * 0.5),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Custom Animated Pulsing Rings at the bottom
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeIn)),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final loopValue = _pulseController.value;
                            
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer expanding ring
                                Transform.scale(
                                  scale: 1.0 + (loopValue * 1.5),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.primary.withValues(alpha: (1.0 - loopValue).clamp(0.0, 1.0)),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                // Inner expanding ring
                                Transform.scale(
                                  scale: 1.0 + (((loopValue + 0.5) % 1.0) * 1.5),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.secondary.withValues(alpha: (1.0 - ((loopValue + 0.5) % 1.0)).clamp(0.0, 1.0)),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                // Center solid dot
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
