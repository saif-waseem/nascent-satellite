import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

class BuyerReviewsDialog extends StatefulWidget {
  const BuyerReviewsDialog(this.tenant, {super.key});
  final String tenant;
  @override
  State<BuyerReviewsDialog> createState() => _BuyerReviewsState();
}

class _BuyerReviewsState extends State<BuyerReviewsDialog> {
  final email = TextEditingController(), password = TextEditingController();
  String? error;
  List<dynamic>? requests;
  bool busy = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run(String action, {String? phone}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      const name = 'buyer-review';
      final app = Firebase.apps.any((app) => app.name == name)
          ? Firebase.app(name)
          : await Firebase.initializeApp(
              name: name,
              options: Firebase.app().options,
            );
      final auth = FirebaseAuth.instanceFor(app: app);
      final u = (await auth.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      )).user!;
      final token = (await u.getIdToken())!;
      if (action != 'reviews')
        await BuyerAccountApi.call(token, action, widget.tenant, {
          'phone': phone,
        });
      final result = await BuyerAccountApi.call(
        token,
        'reviews',
        widget.tenant,
        {},
      );
      if (mounted) setState(() => requests = result['requests'] as List);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('طلبات حذف الحسابات القديمة'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (requests == null) ...[
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'بريد مسؤول هذا المتجر',
                ),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
              ),
              FilledButton(
                onPressed: busy ? null : () => run('reviews'),
                child: const Text('عرض الطلبات'),
              ),
            ] else ...[
              const Text(
                'تحقّق من صاحب رقم الهاتف عبر وسيلة الاتصال المسجّلة قبل الموافقة. تبدأ مهلة العشرة أيام من الموافقة.',
              ),
              if (requests!.isEmpty) const Text('لا توجد طلبات قيد المراجعة'),
              for (final r in requests!)
                ListTile(
                  title: Text(r['phone']),
                  subtitle: Text(r['email']),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'رفض الطلب',
                        icon: const Icon(Icons.close),
                        onPressed: busy
                            ? null
                            : () => run('reject', phone: r['phone']),
                      ),
                      IconButton(
                        tooltip: 'تأكيد ملكية الحساب',
                        icon: const Icon(Icons.check),
                        onPressed: busy
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(
                                      'تأكيد هوية صاحب ${r['phone']}؟',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('إلغاء'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('تحققت من الهوية'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true && mounted)
                                  await run('approve', phone: r['phone']);
                              },
                      ),
                    ],
                  ),
                ),
            ],
            if (error != null) Text(error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
    ],
  );
}
