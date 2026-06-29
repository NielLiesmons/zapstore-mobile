import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart'; // Comment, Utils, AddressData, etc.
import 'package:zapstore/screens/home_screen.dart';
import 'package:zapstore/screens/app_detail_screen.dart';
import 'package:zapstore/screens/app_stacks_screen.dart';
import 'package:zapstore/screens/app_stack_screen.dart';
import 'package:zapstore/screens/forum_post_screen.dart';
import 'package:zapstore/screens/inbox_screen.dart';
import 'package:zapstore/screens/user_screen.dart';
import 'package:zapstore/screens/updates_screen.dart';
import 'package:zapstore/screens/profiles_screen.dart';
import 'package:zapstore/services/package_manager/package_manager.dart';
import 'package:zapstore/services/updates_service.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

typedef _ResolvedRoute = ({String identifier, String? author});

/// No animation for root-level route replacements (e.g. initial home load).
CustomTransitionPage<void> _noTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// Slide-from-right for all push navigations (detail screens, Updates, Profile).
CustomTransitionPage<void> _slideTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        )),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
  );
}

_ResolvedRoute _resolveNaddrRouteId(String rawId) {
  if (rawId.startsWith('naddr1')) {
    try {
      final decoded = Utils.decodeShareableIdentifier(rawId);
      if (decoded is AddressData) {
        return (identifier: decoded.identifier, author: decoded.author);
      }
    } catch (_) {}
  }
  return (identifier: rawId, author: null);
}

GoRoute _appDetailRoute() {
  return GoRoute(
    path: 'app/:id',
    pageBuilder: (context, state) {
      final rawId = state.pathParameters['id']!;
      final resolved = _resolveNaddrRouteId(rawId);
      return _slideTransitionPage(
        state: state,
        child: AppDetailScreen(
          appId: resolved.identifier,
          authorPubkey: resolved.author,
        ),
      );
    },
  );
}

GoRoute _stackDetailRoute() {
  return GoRoute(
    path: 'stack/:id',
    pageBuilder: (context, state) {
      final rawId = state.pathParameters['id']!;
      final resolved = _resolveNaddrRouteId(rawId);
      return _slideTransitionPage(
        state: state,
        child: AppStackScreen(
          stackId: resolved.identifier,
          authorPubkey: resolved.author,
        ),
      );
    },
  );
}

GoRoute _forumPostRoute() {
  return GoRoute(
    path: 'forum/:id',
    pageBuilder: (context, state) {
      final postId = state.pathParameters['id']!;
      return _slideTransitionPage(
        state: state,
        child: ForumPostScreen(postId: postId),
      );
    },
  );
}

GoRoute _allStacksRoute() {
  return GoRoute(
    path: 'stacks',
    pageBuilder: (context, state) => _slideTransitionPage(
      state: state,
      child: const AppStacksScreen(),
    ),
  );
}

GoRoute _userRoute() {
  return GoRoute(
    path: 'user/:pubkey',
    pageBuilder: (context, state) {
      final pubkey = state.pathParameters['pubkey']!;
      return _slideTransitionPage(
        state: state,
        child: UserScreen(pubkey: pubkey),
      );
    },
  );
}

GoRoute _inboxRoute() {
  return GoRoute(
    path: 'inbox',
    pageBuilder: (context, state) => _slideTransitionPage(
      state: state,
      child: const InboxScreen(),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  String? previousPath;

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    onException: (context, state, router) {
      router.go('/');
    },
    routes: [
      // ── Home (persists as the base route) ──────────────────────────────
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _noTransitionPage(
          state: state,
          child: const HomeScreen(),
        ),
        routes: [
          _appDetailRoute(),
          _stackDetailRoute(),
          _allStacksRoute(),
          _userRoute(),
          _forumPostRoute(),
          _inboxRoute(),
        ],
      ),

      // ── Community (legacy — home feed switcher replaces this screen) ───
      GoRoute(
        path: '/community',
        redirect: (context, state) => '/',
      ),

      // ── Updates (slides in from right) ─────────────────────────────────
      GoRoute(
        path: '/updates',
        pageBuilder: (context, state) => _slideTransitionPage(
          state: state,
          child: const UpdatesScreen(),
        ),
        routes: [
          _appDetailRoute(),
          _stackDetailRoute(),
          _allStacksRoute(),
          _userRoute(),
          _inboxRoute(),
        ],
      ),

      // ── Profile / Settings (slides in from right) ───────────────────────
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => _slideTransitionPage(
          state: state,
          child: const ProfilesScreen(),
        ),
        routes: [
          _appDetailRoute(),
          _stackDetailRoute(),
          _allStacksRoute(),
          _userRoute(),
          _inboxRoute(),
        ],
      ),
    ],
  );

  void onRouteChange() {
    final currentPath = router.routerDelegate.currentConfiguration.uri.path;
    final isUpdatesRoute = currentPath.startsWith('/updates');
    final wasUpdatesRoute = previousPath?.startsWith('/updates') ?? false;
    previousPath = currentPath;

    Future.microtask(() {
      unawaited(
        ref.read(packageManagerProvider.notifier).syncInstalledPackages(),
      );

      if (isUpdatesRoute && !wasUpdatesRoute) {
        ref.read(packageManagerProvider.notifier).clearCompletedOperations();
        unawaited(
          ref.read(updatePollerProvider.notifier).refreshFromLocal(),
        );
      }

      if (wasUpdatesRoute && !isUpdatesRoute) {
        ref.read(packageManagerProvider.notifier).clearCompletedOperations();
      }
    });
  }

  router.routerDelegate.addListener(onRouteChange);
  ref.onDispose(() => router.routerDelegate.removeListener(onRouteChange));

  return router;
});
