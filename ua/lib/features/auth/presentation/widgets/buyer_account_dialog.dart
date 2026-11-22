import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../shared/providers.dart';

Future<User> verifiedBuyer(
  String email,
  String password, {
  bool create = false,
}) async {
  final auth = FirebaseAuth.instance;
  UserCredential credential;
  if (create) {
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  } else {
    credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  final u = credential.user!;
  if (!u.emailVerified) {
    await u.sendEmailVerification();
    throw StateError('أرسلنا رابط تأكيد إلى بريدك. افتحه ثم أعد المحاولة.');
  }
  return u;
}

class BuyerAccountDialog extends ConsumerStatefulWidget {
  const BuyerAccountDialog({super.key, this.phone, this.restore = false});
  final String? phone;
  final bool restore;
  @override
  ConsumerState<BuyerAccountDialog> createState() => _BuyerAccountDialogState();
}

class _BuyerAccountDialogState extends ConsumerState<BuyerAccountDialog> {
  final email = TextEditingController(),
      password = TextEditingController(),
      oldPassword = TextEditingController(),
      phone = TextEditingController();
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    phone.text = widget.phone ?? '';
    email.text = FirebaseAuth.instance.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    for (final c in [email, password, oldPassword, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final tenant = await ref.read(resolvedTenantIdProvider.future);
      final u = await verifiedBuyer(
        email.text.trim(),
        password.text,
        create: !widget.restore,
      );
      final data = await BuyerAccountApi.call(
        (await u.getIdToken())!,
        widget.restore ? 'restore' : 'delete',
        tenant,
        {'phone': phone.text.trim(), 'password': oldPassword.text},
      );
      if (!mounted) return;
      final text = widget.restore
          ? 'تمت الاستعادة. يمكنك تسجيل الدخول الآن.'
          : data['review'] == true
          ? 'أُرسل الطلب إلى أدمن متجرك. تبدأ المهلة بعد الموافقة.'
          : 'تم تعليق حسابك. آخر موعد للاستعادة: ${DateTime.parse(data['deadline']).toLocal()}';
      if (!widget.restore && data['review'] != true)
        await ref.read(userActionsProvider).logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.restore ? 'استعادة حسابي' : 'حذف حسابي'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.restore
                ? 'أدخل البريد المؤكّد ورقم الحساب خلال الأيام العشرة.'
                : 'سيُعلّق حسابك عشرة أيام ثم تُحذف بيانات الملف. تحتفظ المتاجر بسجل الطلبات بعد إزالة بيانات الاتصال. الحسابات القديمة تخضع لمراجعة الأدمن.',
          ),
          TextField(
            controller: phone,
            enabled: widget.phone == null,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم الحساب المسجّل'),
          ),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
          ),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'كلمة مرور الهوية البريدية',
            ),
          ),
          if (!widget.restore)
            TextField(
              controller: oldPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة مرور المتجر للحساب القديم فقط',
              ),
            ),
          if (message != null) Text(message!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(widget.restore ? 'استعادة' : 'تأكيد طلب الحذف'),
      ),
    ],
  );
}
