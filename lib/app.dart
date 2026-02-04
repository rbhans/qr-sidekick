import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/scan/scan_screen.dart';
import 'presentation/screens/equipment/equipment_screen.dart';
import 'presentation/screens/admin/admin_screen.dart';
import 'presentation/screens/admin/stations_screen.dart';
import 'presentation/screens/admin/station_form_screen.dart';
import 'presentation/screens/admin/equipment_configs_screen.dart';
import 'presentation/screens/admin/equipment_form_screen.dart';
import 'presentation/screens/admin/qr_code_screen.dart';
import 'presentation/screens/settings/account_screen.dart';

/// Main app widget
class QRSidekickApp extends ConsumerWidget {
  const QRSidekickApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'QR Sidekick',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/forgot-password');

      // Don't redirect while loading
      if (isLoading && authState.user != null) {
        return null;
      }

      // Redirect to login if not authenticated
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Redirect to scanner (home) if authenticated and on auth route
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Account settings
      GoRoute(
        path: '/account',
        name: 'account',
        builder: (context, state) => const AccountScreen(),
      ),

      // Main app - Scanner is home
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const ScanScreen(),
      ),

      // Equipment detail view (after scanning)
      GoRoute(
        path: '/equipment/:qrId',
        name: 'equipment',
        builder: (context, state) {
          final qrId = state.pathParameters['qrId']!;
          return EquipmentScreen(qrId: qrId);
        },
      ),

      // Admin dashboard
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminScreen(),
      ),

      // Admin - Stations
      GoRoute(
        path: '/admin/stations',
        name: 'stations',
        builder: (context, state) => const StationsScreen(),
      ),
      GoRoute(
        path: '/admin/stations/add',
        name: 'addStation',
        builder: (context, state) => const StationFormScreen(),
      ),
      GoRoute(
        path: '/admin/stations/:id',
        name: 'editStation',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return StationFormScreen(stationId: id);
        },
      ),

      // Admin - Equipment
      GoRoute(
        path: '/admin/equipment',
        name: 'equipmentConfigs',
        builder: (context, state) => const EquipmentConfigsScreen(),
      ),
      GoRoute(
        path: '/admin/equipment/add',
        name: 'addEquipment',
        builder: (context, state) => const EquipmentFormScreen(),
      ),
      GoRoute(
        path: '/admin/equipment/:qrId',
        name: 'editEquipment',
        builder: (context, state) {
          final qrId = state.pathParameters['qrId']!;
          return EquipmentFormScreen(qrId: qrId);
        },
      ),
      GoRoute(
        path: '/admin/equipment/:qrId/qr',
        name: 'qrCode',
        builder: (context, state) {
          final qrId = state.pathParameters['qrId']!;
          return QrCodeScreen(qrId: qrId);
        },
      ),
    ],
  );
});

/// Helper class to refresh router on auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(this.ref) {
    ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref ref;
}
