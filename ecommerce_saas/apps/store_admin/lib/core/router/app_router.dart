import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/features/products/presentation/screens/low_stock_screen.dart';
import 'package:store_admin/features/auth/presentation/screens/activation_screen.dart';
import 'package:store_admin/features/profile/presentation/screens/store_profile_setup_screen.dart';
import 'package:store_admin/features/products/presentation/screens/product_list_screen.dart';
import 'package:store_admin/features/products/presentation/screens/product_form_screen.dart';
import 'package:store_admin/features/analytics/presentation/screens/admin_dashboard_screen.dart';
import 'package:store_admin/features/orders/presentation/screens/admin_orders_screen.dart';
import 'package:store_admin/features/loyalty/presentation/screens/loyalty_settings_screen.dart';
import 'package:store_admin/features/customers/presentation/screens/admin_customers_screen.dart';
import 'package:store_admin/features/settings/presentation/screens/admin_settings_screen.dart';
import 'package:store_admin/features/coupons/presentation/screens/coupon_list_screen.dart';
import 'package:store_admin/features/coupons/presentation/screens/coupon_form_screen.dart';
import 'package:store_admin/features/profile/presentation/screens/profile_screen.dart';
import 'package:store_admin/features/products/presentation/screens/admin_categories_screen.dart';
import 'package:store_admin/features/marketing/presentation/screens/marketing_screen.dart';
import 'package:shared_models/shared_models.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentTenantAuthProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final status = authState.status;

      // 1. Initial/Verifying state: Stay put (or show splash)
      if (status == TenantAuthStatus.initial || status == TenantAuthStatus.verifying) {
        return null; 
      }

      final location = state.matchedLocation;
      final isAtRoot = location == '/';
      final isAtSetup = location == '/setup-profile';

      // 2. Unauthenticated: Must go to '/' (Activation)
      if (status == TenantAuthStatus.unauthenticated) {
        if (!isAtRoot && !isAtSetup) return '/';
        return null;
      }

      // 3. Authenticated: If at root, go to dashboard
      if (status == TenantAuthStatus.authenticated) {
        if (isAtRoot) return '/dashboard';
        return null;
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
        path: '/setup-profile',
        builder: (context, state) => const StoreProfileSetupScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const AdminCategoriesScreen(),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductListScreen(),
      ),
      GoRoute(
        path: '/product-form',
        builder: (context, state) {
          final product = state.extra as ProductModel?;
          return ProductFormScreen(product: product);
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const AdminOrdersScreen(),
      ),
      GoRoute(
        path: '/loyalty-settings',
        builder: (context, state) => const LoyaltySettingsScreen(),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const AdminCustomersScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const AdminSettingsScreen(),
      ),
      GoRoute(
        path: '/coupons',
        builder: (context, state) => const CouponListScreen(),
      ),
      GoRoute(
        path: '/coupons/add',
        builder: (context, state) => const CouponFormScreen(),
      ),
      GoRoute(
        path: '/marketing',
        builder: (context, state) => const MarketingScreen(),
      ),
      GoRoute(
        path: '/low-stock',
        builder: (context, state) => const LowStockScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
