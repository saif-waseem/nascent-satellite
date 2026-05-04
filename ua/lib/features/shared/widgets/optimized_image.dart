import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class OptimizedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double? memCacheWidth;
  final double? memCacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth = 300, // Default for grid/list items
    this.memCacheHeight,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    if (imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth?.toInt(),
        memCacheHeight: memCacheHeight?.toInt(),
        placeholder: (context, url) => placeholder ?? _buildShimmer(),
        errorWidget: (context, url, error) => errorWidget ?? _buildError(),
      );
    }

    // Handle Icon data if passed as string code
    final iconCode = int.tryParse(imageUrl!) ?? 58900;
    return Center(
      child: Icon(
        IconData(iconCode, fontFamily: 'MaterialIcons'),
        size: (width ?? 40) * 0.8,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        color: Colors.white,
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      color: Colors.grey[100],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      color: Colors.grey[100],
      child: Icon(Icons.image_outlined, color: Colors.grey[300], size: 30),
    );
  }
}
