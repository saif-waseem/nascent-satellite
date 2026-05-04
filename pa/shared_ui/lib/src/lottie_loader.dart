import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieLoader extends StatelessWidget {
  final String? assetPath;
  final String? url;
  final double size;
  final bool repeat;

  const LottieLoader({
    super.key,
    this.assetPath,
    this.url,
    this.size = 200,
    this.repeat = true,
  });

  factory LottieLoader.loading({double size = 150}) {
    return LottieLoader(
      url: 'https://assets9.lottiefiles.com/packages/lf20_p8bfn5to.json', // Sample loading animation
      size: size,
    );
  }

  factory LottieLoader.success({double size = 150}) {
    return LottieLoader(
      url: 'https://assets9.lottiefiles.com/packages/lf20_pqnfmone.json', // Sample success animation
      size: size,
      repeat: false,
    );
  }

  factory LottieLoader.empty({double size = 200}) {
    return LottieLoader(
      url: 'https://assets9.lottiefiles.com/packages/lf20_0s6tfpaz.json', // Sample empty state
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (assetPath != null) {
      return Lottie.asset(assetPath!, width: size, height: size, repeat: repeat);
    }
    if (url != null) {
      return Lottie.network(url!, width: size, height: size, repeat: repeat);
    }
    return const SizedBox.shrink();
  }
}
