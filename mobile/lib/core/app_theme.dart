import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Palette ───────────────────────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF3A0CA3);
  static const accent = Color(0xFF00C896);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const surface = Colors.white;
  static const bg = Color(0xFFF2F3FF);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const timerGreen = Color(0xFF10B981);
  static const timerOrange = Color(0xFFF59E0B);
  static const timerRed = Color(0xFFEF4444);

  static const Gradient primary_ = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C73FF), Color(0xFF3A0CA3)],
  );
  static const Gradient accent_ = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C896), Color(0xFF0077B6)],
  );
  static const Gradient dark_ = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
  );
  static const Gradient indigo_ = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF1E1B4B)],
  );

  // Podium
  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFC0C0C0);
  static const bronze = Color(0xFFCD7F32);
}

// ── Shadow helpers ─────────────────────────────────────────────────────────
class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get button => [
        BoxShadow(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.38),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];
}

// ── Theme ─────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: null,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1B4B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
          shadowColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.danger, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: Color(0xFFADB5BD), fontSize: 14),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIconColor: AppColors.primary,
          counterStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          selectedColor: AppColors.primary.withValues(alpha: 0.12),
          checkmarkColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          side: BorderSide(color: Colors.grey.shade300),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
          thumbColor: Colors.white,
          overlayColor: AppColors.primary.withValues(alpha: 0.12),
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 10,
            elevation: 4,
          ),
          trackHeight: 4,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? Colors.white : Colors.grey.shade400),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.primary
                  : Colors.grey.shade200),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEF0F6),
          thickness: 1,
          space: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentTextStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        ),
      );
}

// ── Gradient AppBar ────────────────────────────────────────────────────────
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Gradient gradient;

  const GradientAppBar({
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.gradient = AppColors.indigo_,
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: gradient),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final IconData? icon;
  final double height;

  const GradientButton({
    required this.label,
    this.onPressed,
    this.gradient,
    this.icon,
    this.height = 56,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: disabled
              ? const LinearGradient(colors: [Color(0xFFCBCBCB), Color(0xFFADADAD)])
              : (gradient ?? AppColors.primary_),
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled ? [] : AppShadows.button,
        ),
        child: MaterialButton(
          onPressed: onPressed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: Colors.white),
                const SizedBox(width: 10),
              ],
              Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colored rounded icon box (iOS settings style)
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBox({
    required this.icon,
    required this.color,
    this.size = 36,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    );
  }
}

/// Section header label with accent bar
class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Small status badge
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({required this.label, required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

/// Circular avatar with online dot
class OnlineAvatar extends StatelessWidget {
  final String photoURL;
  final double radius;
  final bool isOnline;

  const OnlineAvatar({
    required this.photoURL,
    this.radius = 22,
    this.isOnline = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 2),
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage: photoURL.isNotEmpty
                ? NetworkImage(photoURL) as ImageProvider
                : const AssetImage('assets/images/default_profile_image.png'),
          ),
        ),
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: radius * 0.52,
            height: radius * 0.52,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.accent : Colors.grey.shade400,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Confirm dialog helper — returns true if user pressed the confirm button.
class ConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String content,
    String confirmLabel = '확인',
    String cancelLabel = '취소',
    Color confirmColor = AppColors.danger,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelLabel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// SnackBar helper — color and message. Behavior/shape come from AppTheme.
class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    Color backgroundColor = AppColors.danger,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
    ));
  }
}

/// Avatar that falls back to the first-letter initial when photoURL is empty
/// or fails to load.
class UserAvatar extends StatelessWidget {
  final String photoURL;
  final String name;
  final double radius;
  final bool lightBg;

  const UserAvatar({
    required this.photoURL,
    required this.name,
    required this.radius,
    this.lightBg = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bg = lightBg
        ? Colors.white.withValues(alpha: 0.3)
        : AppColors.primary.withValues(alpha: 0.15);
    final fg = lightBg ? Colors.white : AppColors.primary;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: SizedBox.expand(
          child: photoURL.isNotEmpty
              ? Image.network(
                  photoURL,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(initial,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          fontSize: radius * 0.75,
                        )),
                  ),
                )
              : Center(
                  child: Text(initial,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: radius * 0.75,
                      )),
                ),
        ),
      ),
    );
  }
}

/// Pill-shaped value badge (for sliders etc.)
class ValuePill extends StatelessWidget {
  final String text;
  final Color? color;
  const ValuePill(this.text, {this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}
