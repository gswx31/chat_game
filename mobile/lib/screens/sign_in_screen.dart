import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../core/router.dart';
import '../services/auth_service.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _signIn(Future<dynamic> Function() action) async {
    setState(() => _loading = true);
    try {
      final user = await action();
      if (user != null && mounted) context.go(Routes.dashboard);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 실패: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.dark_),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // Logo
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 8,
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/images/logo.png',
                            fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Chat Game',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '친구들과 실시간 퀴즈 배틀!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(flex: 3),

                    // Google
                    _SocialButton(
                      label: '구글로 로그인',
                      iconPath: 'assets/images/google_logo.png',
                      bgColor: Colors.white,
                      textColor: Colors.black87,
                      onPressed: _loading
                          ? null
                          : () => _signIn(AuthService.instance.signInWithGoogle),
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                            child: Divider(color: Colors.white.withOpacity(0.2))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('또는',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 13)),
                        ),
                        Expanded(
                            child: Divider(color: Colors.white.withOpacity(0.2))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_loading)
                      const SizedBox(
                        height: 40,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    else
                      TextButton(
                        onPressed: () =>
                            _signIn(AuthService.instance.signInAnonymously),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.6),
                        ),
                        child: const Text(
                          '게스트로 계속하기  →',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String iconPath;
  final Color bgColor;
  final Color textColor;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.label,
    required this.iconPath,
    required this.bgColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null ? bgColor.withOpacity(0.5) : bgColor,
          foregroundColor: textColor,
          elevation: onPressed == null ? 0 : 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(iconPath, height: 22),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor)),
          ],
        ),
      ),
    );
  }
}
