import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _passwordController;
  late TextEditingController _governorateController;
  late TextEditingController _locationController;
  late TextEditingController _landmarkController;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider).value;
    _nameController = TextEditingController(text: user?.name);
    _passwordController = TextEditingController(text: user?.password);
    
    final savedAddress = user?.address ?? '';
    if (savedAddress.contains(' - ')) {
      final parts = savedAddress.split(' - ');
      _governorateController = TextEditingController(text: parts[0]);
      _locationController = TextEditingController(text: parts.sublist(1).join(' - '));
    } else {
      _governorateController = TextEditingController();
      _locationController = TextEditingController(text: savedAddress);
    }
    _landmarkController = TextEditingController(text: user?.landmark);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _governorateController.dispose();
    _locationController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final fullAddress = '${_governorateController.text} - ${_locationController.text}';
      await ref.read(userActionsProvider).updateUserProfile(
        name: _nameController.text.trim(),
        password: _passwordController.text.trim(),
        address: fullAddress,
        landmark: _landmarkController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('my_profile_title', lang)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppStrings.get('name_label', lang),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? AppStrings.get('fill_fields', lang) : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: AppStrings.get('governorate', lang),
                  prefixIcon: const Icon(Icons.map_outlined),
                  border: const OutlineInputBorder(),
                ),
                initialValue: _governorateController.text.isEmpty ? null : _governorateController.text,
                items: [
                  'Baghdad', 'Basra', 'Nineveh', 'Erbil', 'Anbar', 'Najaf', 'Karbala', 'Duhok', 'Kirkuk', 
                  'Maysan', 'Muthanna', 'Qadisiyah', 'Salah_al-Din', 'Sulaymaniyah', 'Wasit', 'Dhi_Qar', 'Babil', 'Diyala'
                ].map((g) {
                  final key = 'gov_${g.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_')}';
                  return DropdownMenuItem(
                    value: g, 
                    child: Text(AppStrings.get(key, lang))
                  );
                }).toList(),
                onChanged: (v) => setState(() => _governorateController.text = v ?? ''),
                validator: (v) => (v == null || v.isEmpty) ? AppStrings.get('fill_fields', lang) : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: AppStrings.get('location_details', lang),
                  hintText: 'Street, Neighborhood, etc.',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.length < 3) ? 'Too short' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _landmarkController,
                decoration: InputDecoration(
                  labelText: AppStrings.get('landmark', lang),
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: AppStrings.get('password_label', lang),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Password too short' : null,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppStrings.get('submit', lang)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
