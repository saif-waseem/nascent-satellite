import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

const int CURRENT_VERSION_CODE = 1; // Increment this with each release

class CheckUpdateWrapper extends HookConsumerWidget {
  final Widget child;
  const CheckUpdateWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return child; // No updates check for web yet

    // Determine which app ID to check for
    String appId = 'store_admin_android';
    if (defaultTargetPlatform == TargetPlatform.iOS) appId = 'store_admin_ios';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('app_updates').doc(appId).get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (kDebugMode) debugPrint('CheckUpdateWrapper: suppression of error: ${snapshot.error}');
          return child;
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return child;
        }

        try {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return child;
          
          final update = AppUpdateModel.fromJson(data);

          // Priority 1: If app is manually disabled by Super Admin, show disabled screen
          if (update.isAppDisabled) {
            return _AppDisabledScreen(update: update);
          }

          // Priority 2: If update available, show banner but allow app to run
          if (update.versionCode > CURRENT_VERSION_CODE && update.isMandatory) {
            return _WithUpdateBanner(update: update, child: child);
          }

          // Otherwise, run normally
          return child;
        } catch (e) {
          // On any error, allow app to run
          debugPrint('Error checking for updates: $e');
          return child;
        }
      },
    );
  }
}

// Screen shown when app is manually disabled by Super Admin
class _AppDisabledScreen extends StatelessWidget {
  final AppUpdateModel update;
  const _AppDisabledScreen({required this.update});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 100, color: Colors.deepPurple),
            const SizedBox(height: 32),
            const Text(
              'Admin App Disabled',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'برنامج الادمن معطل مؤقتاً',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              update.releaseNotes.isNotEmpty 
                ? update.releaseNotes 
                : 'The admin application has been temporarily disabled.\nPlease contact Super Admin for more information.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            if (update.downloadUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _launchURL(update.downloadUrl),
                  icon: const Icon(Icons.download),
                  label: const Text('Download New Version'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// Widget that shows update banner at top but allows app to continue running
class _WithUpdateBanner extends StatefulWidget {
  final Widget child;
  final AppUpdateModel update;
  const _WithUpdateBanner({required this.child, required this.update});

  @override
  State<_WithUpdateBanner> createState() => _WithUpdateBannerState();
}

class _WithUpdateBannerState extends State<_WithUpdateBanner> {
  bool _bannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_bannerDismissed) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Material(
              color: Colors.deepPurple,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.system_update, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Admin Update v${widget.update.versionName} Available',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const Text(
                            'تحديث متاح للادمن',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _launchURL(widget.update.downloadUrl),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: const Text('Download', style: TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _bannerDismissed = true),
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
