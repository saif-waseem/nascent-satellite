import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

class DesktopActionsWrapper extends ConsumerWidget {
  final Widget child;

  const DesktopActionsWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only apply hotkeys on desktop platforms
    if (Theme.of(context).platform != TargetPlatform.windows && 
        Theme.of(context).platform != TargetPlatform.linux && 
        Theme.of(context).platform != TargetPlatform.macOS) {
      return child;
    }

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const NewItemIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (intent) {
              final location = GoRouterState.of(context).uri.toString();
              if (location != '/products') {
                 context.push('/products');
              }
              return null;
            },
          ),
          NewItemIntent: CallbackAction<NewItemIntent>(
             onInvoke: (intent) {
               final location = GoRouterState.of(context).uri.toString();
               if (location == '/products') {
                  context.push('/product-form');
               } else if (location == '/coupons') {
                  context.push('/coupons/add');
               }
               return null;
             },
          ),
        },
        child: child,
      ),
    );
  }
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class NewItemIntent extends Intent {
  const NewItemIntent();
}
