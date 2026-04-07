import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:super_admin/features/shared/providers.dart';
import 'package:super_admin/features/shared/widgets/super_admin_drawer.dart';
import 'package:super_admin/core/localization/resources/app_strings.dart';

class AppUpdatesScreen extends HookConsumerWidget {
  const AppUpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatesAsync = ref.watch(appUpdatesProvider);

    final lang = 'ar'; // TODO: Get actual lang from settings if available
    
    return Scaffold(
      drawer: const SuperAdminDrawer(),
      appBar: AppBar(title: Text(AppStrings.get('app_updates', lang))),
      body: updatesAsync.when(
        data: (updates) {
          if (updates.isEmpty) {
            return const Center(child: Text('No app updates configured. Press + to add one.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: updates.length,
            itemBuilder: (context, index) {
              final update = updates[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildUpdateCard(context, ref, update.id, update.title.isNotEmpty ? update.title : update.id, updates),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUpdateDialog(context, ref, '', null),
        label: const Text('Add Package Update'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUpdateCard(BuildContext context, WidgetRef ref, String id, String title, List<AppUpdateModel> updates) {
    final update = updates.cast<AppUpdateModel?>().firstWhere((u) => u?.id == id, orElse: () => null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                if (update != null) ...[
                  if (update.isAppDisabled)
                    const Chip(
                      label: Text('DISABLED', style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.red,
                    )
                  else
                    Chip(label: Text('v${update.versionName} (${update.versionCode})')),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (update != null) ...[
              Text('URL: ${update.downloadUrl}', style: const TextStyle(fontSize: 12, color: Colors.blue)),
              const SizedBox(height: 4),
              Text('Last Updated: ${update.updatedAt.toString().split('.')[0]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ] else
              const Text('No update information set.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showUpdateDialog(context, ref, id, update),
                icon: const Icon(Icons.edit),
                label: Text(update == null ? 'Set Update' : 'Push New Update'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, WidgetRef ref, String id, AppUpdateModel? current) {
    showDialog(
      context: context,
      builder: (ctx) => _UpdateDialog(id: id, current: current),
    );
  }
}

class _UpdateDialog extends HookConsumerWidget {
  final String id;
  final AppUpdateModel? current;

  const _UpdateDialog({required this.id, this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleController = useTextEditingController(text: current?.title ?? '');
    final idController = useTextEditingController(text: current?.id ?? id);
    final codeController = useTextEditingController(text: (current?.versionCode ?? 1).toString());
    final nameController = useTextEditingController(text: current?.versionName ?? '1.0.0');
    final urlController = useTextEditingController(text: current?.downloadUrl ?? '');
    final notesController = useTextEditingController(text: current?.releaseNotes ?? '');
    final isMandatory = useState(current?.isMandatory ?? false);
    final isAppDisabled = useState(current?.isAppDisabled ?? false);

    return AlertDialog(
      title: Text(current == null ? 'Add Package Update' : 'Push New Update'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Display Title (e.g. London Store Android)'),
            ),
            TextField(
              controller: idController,
              enabled: current == null, // Only allow setting ID when creating new
              decoration: const InputDecoration(
                labelText: 'Package ID + Suffix',
                hintText: 'com.example.app_android',
                helperText: 'Must match exactly: PackageID_android or PackageID_ios',
              ),
            ),
            TextField(
              controller: codeController,
              decoration: InputDecoration(labelText: AppStrings.get('version_code', 'ar')),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: AppStrings.get('version_name', 'ar')),
            ),
            TextField(
              controller: urlController,
              decoration: InputDecoration(labelText: AppStrings.get('download_url', 'ar')),
              keyboardType: TextInputType.url,
            ),
            TextField(
              controller: notesController,
              decoration: InputDecoration(labelText: AppStrings.get('release_notes', 'ar')),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(AppStrings.get('mandatory', 'ar')),
              subtitle: const Text('Show update notification (app continues to work)'),
              value: isMandatory.value,
              onChanged: (v) => isMandatory.value = v,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('🔴 تعطيل التطبيق (Disable App)'),
              subtitle: const Text('WARNING: App will stop working for all users!'),
              value: isAppDisabled.value,
              activeThumbColor: Colors.red,
              onChanged: (v) {
                if (v) {
                  // Show confirmation dialog
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('⚠️ Disable App?'),
                      content: const Text('This will prevent ALL users from using the app. Are you sure?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () {
                            isAppDisabled.value = true;
                            Navigator.pop(ctx);
                          },
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Yes, Disable'),
                        ),
                      ],
                    ),
                  );
                } else {
                  isAppDisabled.value = false;
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final update = AppUpdateModel(
              id: idController.text.trim(),
              title: titleController.text.trim(),
              versionCode: int.tryParse(codeController.text) ?? 1,
              versionName: nameController.text,
              downloadUrl: urlController.text,
              releaseNotes: notesController.text,
              isMandatory: isMandatory.value,
              isAppDisabled: isAppDisabled.value,
              updatedAt: DateTime.now(),
            );
            await ref.read(superAdminFirestoreServiceProvider).saveAppUpdate(update);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save & Notify'),
        ),
      ],
    );
  }
}
