import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// A container with glassmorphism effect (blur, semi-transparent background, gradient border).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? color;
  final List<Color>? gradientColors;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.width = double.infinity,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20,
    this.blur = 15,
    this.opacity = 0.1,
    this.color, // If provided, overrides gradientColors
    this.gradientColors,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultGradientColors = isDark
        ? [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)]
        : [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.5)];

    final defaultBorderColor = isDark
        ? Colors.white.withOpacity(0.2)
        : Colors.white.withOpacity(0.6);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: width,
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color:
                  color?.withOpacity(opacity) ??
                  (isDark ? Colors.white : Colors.black).withOpacity(opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border:
                  border ?? Border.all(color: defaultBorderColor, width: 1.5),
              gradient: color == null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors ?? defaultGradientColors,
                    )
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A button with glassmorphism styling.
class GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Widget? icon;
  final double width;
  final double height;
  final double borderRadius;
  final List<Color>? gradientColors;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.width = double.infinity,
    this.height = 56,
    this.borderRadius = 16,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultGradientColors = isDark
        ? [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)]
        : [
            AppTheme.narutoOrange.withOpacity(0.9),
            AppTheme.narutoOrange.withOpacity(0.7),
          ];

    final borderColor = isDark
        ? Colors.white.withOpacity(0.2)
        : Colors.white.withOpacity(0.4);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color:
                (gradientColors?.first ??
                        (isDark ? Colors.white : AppTheme.narutoOrange))
                    .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor, width: 1.5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors ?? defaultGradientColors,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[icon!, const SizedBox(width: 8)],
                      Text(
                        text,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrapper that provides the global background gradient and handles the Stack
class GlassScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final PreferredSizeWidget? appBar;
  final bool extendBody;

  const GlassScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.appBar,
    this.extendBody = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: extendBody,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      backgroundColor:
          Colors.transparent, // Important for the background to show through
      body: Stack(
        children: [
          // Plain Background
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.glassGradient
                  : AppTheme.glassGradientLight,
            ),
          ),

          // Main Body Content
          SafeArea(child: body),

          if (bottomNavigationBar != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: bottomNavigationBar!,
            ),
        ],
      ),
    );
  }
}

/// A glass-styled AppBar that implements PreferredSizeWidget
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppTheme.glassBackgroundDark.withOpacity(0.7)
        : AppTheme.glassBackgroundWhite.withOpacity(0.7);

    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor, // Semi-transparent background
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: AppBar(
            title: Text(
              title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            centerTitle: centerTitle,
            backgroundColor:
                Colors.transparent, // Transparent to show container decoration
            elevation: 0,
            leading: leading,
            actions: actions,
            iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
            actionsIconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}
