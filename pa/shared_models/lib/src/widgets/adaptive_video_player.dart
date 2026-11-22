import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class AdaptiveVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? previewImageUrl;
  final bool autoPlay;
  final bool looping;

  const AdaptiveVideoPlayer({
    super.key,
    required this.videoUrl,
    this.previewImageUrl,
    this.autoPlay = false,
    this.looping = false,
  });

  @override
  State<AdaptiveVideoPlayer> createState() => _AdaptiveVideoPlayerState();
}

class _AdaptiveVideoPlayerState extends State<AdaptiveVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  int _attempt=0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant AdaptiveVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    final attempt=++_attempt;
    if (widget.videoUrl.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'رابط الفيديو غير صالح أو فارغ';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }

    _disposeControllers();

    try {
      final uri = Uri.parse(widget.videoUrl.trim());
      final controller = VideoPlayerController.networkUrl(uri);
      _videoPlayerController = controller;

      // Initialize with 12 seconds timeout to prevent infinite spinning
      await controller.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('استغرق تحميل الفيديو وقتاً أطول من المتوقع');
        },
      );

      if (!mounted || attempt!=_attempt) return;

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: widget.autoPlay,
        looping: widget.looping,
        aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
        placeholder: _buildPlaceholder(),
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget(errorMessage);
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.amber.shade700,
          handleColor: Colors.amber,
          backgroundColor: Colors.grey.shade700,
          bufferedColor: Colors.white70,
        ),
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if(!mounted || attempt!=_attempt)return;
      debugPrint('AdaptiveVideoPlayer initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'تعذر تشغيل الفيديو: $e';
        });
      }
    }
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Widget _buildPlaceholder() {
    if (widget.previewImageUrl != null && widget.previewImageUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(widget.previewImageUrl!, fit: BoxFit.cover),
          Container(color: Colors.black38),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.amber, size: 48),
            const SizedBox(height: 12),
            const Text(
              'تعذر تشغيل الفيديو داخل المشغل',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              widget.videoUrl,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _initializePlayer,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.black,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(widget.videoUrl.trim());
                    if (uri != null) {
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('فتح في مشغل خارجي'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget(_errorMessage);
    }

    if (_isLoading || _chewieController == null || !_videoPlayerController!.value.isInitialized) {
      return _buildPlaceholder();
    }

    return Chewie(controller: _chewieController!);
  }
}
