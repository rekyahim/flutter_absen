import 'package:flutter/material.dart';

class BackgroundWrapper extends StatelessWidget {
  final Widget child;

  const BackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/images/bg-batik.png'),
          fit: BoxFit.cover,
          // Menggunakan withValues agar tidak ada warning deprecated
          colorFilter: ColorFilter.mode(
            Colors.white.withValues(alpha: 0.06),
            BlendMode.dstATop,
          ),
        ),
      ),
      child: child,
    );
  }
}
