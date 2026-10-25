import 'package:flutter/material.dart';
import '../core/session_controller.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key, required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F4EC),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 1),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Wordmark(),
                const SizedBox(height: 36),
                const _WelcomeIllustration(),
                const SizedBox(height: 35),
                const Text(
                  'A little more joy\nat your table.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 31,
                    height: 1.13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: ValoraColors.ink,
                  ),
                ),
                const SizedBox(height: 13),
                const Text(
                  'Thoughtful food planning, shaped around\nyou and your everyday life.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: ValoraColors.muted,
                  ),
                ),
                const SizedBox(height: 31),
                if (session.authError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      session.authError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: session.signingIn
                        ? null
                        : () => _signIn(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: ValoraColors.forest,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: session.signingIn
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _GoogleMark(),
                              SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Continue with Google',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 17),
                const Text(
                  'Start your Valora space with one secure sign-in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: ValoraColors.muted),
                ),
                const SizedBox(height: 28),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: ValoraColors.forest,
                    ),
                    SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Sign in securely. Review your food preferences anytime.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: ValoraColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _signIn(BuildContext context) async {
    try {
      await session.signInWithGoogle();
    } catch (_) {
      if (!context.mounted) return;
      toast(
        context,
        'Could not start Google sign-in. Check your connection and try again.',
      );
    }
  }
}

class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 232,
    height: 214,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 190,
          height: 190,
          decoration: const BoxDecoration(
            color: Color(0xFFE5EFE2),
            shape: BoxShape.circle,
          ),
        ),
        Positioned(
          right: 13,
          top: 25,
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFEBCB87),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wb_sunny_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
        ),
        Container(
          width: 138,
          height: 138,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD8E4D5), width: 7),
            boxShadow: const [
              BoxShadow(
                color: Color(0x171D2923),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.ramen_dining_rounded,
            color: ValoraColors.forest,
            size: 69,
          ),
        ),
        const Positioned(
          left: 14,
          bottom: 27,
          child: _FloatingLeaf(
            icon: Icons.eco_rounded,
            color: Color(0xFF84A989),
            angle: -0.45,
          ),
        ),
        const Positioned(
          right: 17,
          bottom: 19,
          child: _FloatingLeaf(
            icon: Icons.spa_rounded,
            color: Color(0xFFC58F67),
            angle: 0.4,
          ),
        ),
        const Positioned(
          left: 31,
          top: 28,
          child: Icon(Icons.circle, size: 9, color: Color(0xFFE9B5A4)),
        ),
      ],
    ),
  );
}

class _FloatingLeaf extends StatelessWidget {
  const _FloatingLeaf({
    required this.icon,
    required this.color,
    required this.angle,
  });
  final IconData icon;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Icon(icon, size: 37, color: color),
  );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 27,
    height: 27,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: const Text(
      'G',
      style: TextStyle(
        fontFamily: 'Arial',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4285F4),
      ),
    ),
  );
}
