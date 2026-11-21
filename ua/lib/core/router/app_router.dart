import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/features/home/presentation/screens/home_screen.dart';
import 'package:user_app/features/loyalty/presentation/screens/loyalty_screen.dart';
import 'package:user_app/features/loyalty/presentation/screens/profile_edit_screen.dart';
import 'package:user_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:user_app/features/orders/presentation/screens/order_details_screen.dart';
import 'package:user_app/features/products/presentation/screens/product_details_screen.dart';
import 'package:user_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:user_app/features/cart/presentation/screens/shared_cart_preview_screen.dart';
import 'package:user_app/features/auth/presentation/screens/login_screen.dart';
import 'package:user_app/features/auth/presentation/screens/register_screen.dart';
import 'package:user_app/features/main_layout/presentation/screens/main_info_screen.dart';
import 'package:user_app/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:user_app/features/products/presentation/screens/favorites_screen.dart';
import 'package:user_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:shared_models/shared_models.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/home',
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainInfoScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'product/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return ProductDetailsScreen(
                        product: ProductModel(
                          id: id, 
                          name: '', 
                          category: '', 
                          price: 0, 
                          description: '', 
                          tenantId: '',
                          images: state.uri.queryParameters['img'] != null ? [state.uri.queryParameters['img']!] : [],
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'product-details',
                    builder: (context, state) {
                      ProductModel? product;
                      if (state.extra is ProductModel) {
                        product = state.extra as ProductModel;
                      } else if (state.extra is Map<String, dynamic>) {
                        product = ProductModel.fromJson(state.extra as Map<String, dynamic>);
                      }
                      return ProductDetailsScreen(product: product);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/loyalty',
                builder: (context, state) => const LoyaltyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/product-details',
        builder: (context, state) {
          ProductModel? product;
          if (state.extra is ProductModel) {
            product = state.extra as ProductModel;
          } else if (state.extra is Map<String, dynamic>) {
            product = ProductModel.fromJson(state.extra as Map<String, dynamic>);
          }
          return ProductDetailsScreen(product: product);
        },
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/share/:id',
        builder: (context, state) => SharedCartPreviewScreen(
          shareId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(referral: state.uri.queryParameters['ref'] ?? ''),
      ),
      GoRoute(
        path: '/order-details/:orderId',
        builder: (context, state) {
          return OrderDetailsScreen(orderId: state.pathParameters['orderId'] ?? 'ID');
        },
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/profile-edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/product-details',
        redirect: (context, state) => '/home/product-details',
      ),
      GoRoute(
        path: '/product/:id',
        redirect: (context, state) => '/home/product/${state.pathParameters['id']}',
      ),
    ],
  );
});
