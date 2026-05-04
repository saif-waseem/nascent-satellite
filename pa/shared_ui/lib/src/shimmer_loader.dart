import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }

  static Widget productCard() {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoader(width: 160, height: 160, borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 8),
          const ShimmerLoader(width: 120, height: 16),
          const SizedBox(height: 4),
          const ShimmerLoader(width: 80, height: 14),
        ],
      ),
    );
  }

  static Widget listTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ShimmerLoader(width: 50, height: 50, borderRadius: BorderRadius.circular(8)),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoader(width: double.infinity, height: 16),
                SizedBox(height: 8),
                ShimmerLoader(width: 150, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
