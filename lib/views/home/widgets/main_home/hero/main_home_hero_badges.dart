part of '../../../tabs/main_home_tab.dart';

class MainHomeHeroBadges extends StatelessWidget {
  final String houseName;

  const MainHomeHeroBadges({
    required this.houseName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFFF6F91), Color(0xFFD81B60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          houseName,
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}
