import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../shared/providers.dart';

class GlobalSettingsScreen extends ConsumerStatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  ConsumerState<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends ConsumerState<GlobalSettingsScreen> {
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Global Settings')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: ref.watch(superAdminFirestoreServiceProvider).getGlobalSettings(),
        builder: (context, snapshot) {
          if (snapshot.hasData && _whatsappController.text.isEmpty) {
            _whatsappController.text = snapshot.data!['developerWhatsapp'] ?? '';
            _emailController.text = snapshot.data!['developerEmail'] ?? '';
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Developer Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'Developer WhatsApp',
                  hintText: '+964...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Developer Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : () async {
                  setState(() => _isLoading = true);
                  await ref.read(superAdminFirestoreServiceProvider).updateGlobalSettings({
                    'developerWhatsapp': _whatsappController.text.trim(),
                    'developerEmail': _emailController.text.trim(),
                  });
                  setState(() => _isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully')));
                  }
                },
                child: _isLoading ? const CircularProgressIndicator() : const Text('Save Settings'),
              ),
            ],
          );
        },
      ),
    );
  }
}
