import '../widgets/buyer_account_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:user_app/features/shared/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = true;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('login', lang))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.phone_android_outlined, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: AppStrings.get('phone', lang),
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: AppStrings.get('password', lang),
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                obscureText: !_isPasswordVisible,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.get('verify_code_mock', lang),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  ),
                  Text(AppStrings.get('remember_me', lang)),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final phone = _phoneController.text.trim();
                  final password = _passwordController.text.trim();
                  if (phone.isEmpty || password.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppStrings.get('fill_fields', lang)))
                    );
                  } else if (phone.length < 8) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppStrings.get('phone_short_error', lang)))
                    );
                  } else {
                    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                    try {
                      await ref.read(userActionsProvider).login(phone, password, rememberMe: _rememberMe);
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading
                        context.go('/home');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading
                        String msg = e.toString();
                        if (msg.contains('ACCOUNT_NOT_FOUND')) {
                          msg = AppStrings.get('no_account_error', lang);
                        } else if (msg.contains('WRONG_PASSWORD')) {
                          msg = AppStrings.get('wrong_password_error', lang);
                        } else if (msg.contains('Exception: ')) {
                          msg = msg.split('Exception: ').last;
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                      }
                    }
                  }
                },
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(AppStrings.get('login', lang)),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed:()=>showDialog(context:context,builder:(_)=>const BuyerAccountDialog(restore:true)),child:const Text('استعادة حسابي المحذوف')),
              TextButton(
                onPressed: () => context.push('/register'),
                child: Text(AppStrings.get('new_user_register', lang)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // Clear any existing user state for guest mode
                  ref.read(userActionsProvider).logout();
                  context.go('/home');
                },
                child: Text(AppStrings.get('guest_mode', lang), style: const TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
