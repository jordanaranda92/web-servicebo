import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/config/app_config.dart';
import 'app/config/environments/dev_config.dart';
import 'app/di/injection.dart';
import 'app/router/router.dart';
import 'core/auth/current_user_provider.dart';
import 'features/auth/data/datasources/auth_local_data_source.dart';
import 'features/auth/domain/usecases/check_auto_login.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'firebase_options.dart';
import 'app/localization/l10n/app_localizations.dart';
import 'app/theme/app_theme.dart';
import 'core/log/app_logger.dart';
import 'core/usecase/usecase.dart';
import 'core/presentation/bloc/side_menu_cubit.dart';
import 'features/locale/presentation/bloc/locale_cubit.dart';
import 'features/locale/presentation/bloc/locale_state.dart';

/// Default entry point - uses dev configuration.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await runApplication(DevConfig());
}

/// Runs the application with the provided configuration.
///
/// This function is shared across all environment entry points.
Future<void> runApplication(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final initialRoute = await _initializeServices(config);
  runApp(MainApp(initialRoute: initialRoute));
}

/// Whether Firebase was initialized successfully.
bool _firebaseAvailable = false;

Future<String> _initializeServices(AppConfig config) async {
  // Early logger that respects the environment config (no-op in production)
  final logger = AppLogger(
    enabled: config.enableLogging,
    minLevel: config.logMinLevel,
  );

  // Initialize Firebase (best-effort — app works without it)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseAvailable = true;
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      // Already initialized (hot restart) — this is fine
      _firebaseAvailable = true;
    } else {
      _firebaseAvailable = false;
      logger.error('[Firebase] Initialization failed', e);
    }
  } on Exception catch (e) {
    _firebaseAvailable = false;
    logger.error('[Firebase] Initialization failed', e);
  }

  logger.debug('[Firebase] Available: $_firebaseAvailable');

  await initDI(config, firebaseAvailable: _firebaseAvailable);

  // Determine initial route based on auth state
  if (!_firebaseAvailable) {
    return AppRoutes.login;
  }

  final authLocal = sl<AuthLocalDataSource>();
  final rememberMe = authLocal.getRememberMe();

  if (rememberMe) {
    // Check if Firebase Auth still has a valid session
    final firebaseAuth = sl<FirebaseAuth>();
    if (firebaseAuth.currentUser != null) {
      // Fetch user profile (including role) from Firestore
      final checkAutoLogin = sl<CheckAutoLogin>();
      final result = await checkAutoLogin(NoParams());
      result.fold(
        (_) {
          logger.warning(
            '[Auth] Failed to fetch user profile during auto-login',
          );
        },
        (user) {
          if (user != null) {
            sl<AuthCubit>().setUser(user);
          }
        },
      );

      // Resolve current user name from Firestore for action history.
      await sl<CurrentUserProvider>().resolve();

      return AppRoutes.ordersToday;
    }
  }

  return AppRoutes.login;
}

class MainApp extends StatefulWidget {
  final String initialRoute;

  const MainApp({super.key, required this.initialRoute});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    // Initialize cubits to load saved preferences or detect system defaults
    sl<LocaleCubit>().init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AuthCubit>()),
        BlocProvider(create: (_) => sl<LocaleCubit>()),
        BlocProvider(create: (_) => sl<SideMenuCubit>()),
      ],
      child: BlocBuilder<LocaleCubit, LocaleState>(
        buildWhen: (previous, current) => previous.locale != current.locale,
        builder: (context, localeState) {
          return _buildMaterialApp(localeState.locale);
        },
      ),
    );
  }

  Widget _buildMaterialApp(Locale? locale) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: createRouter(initialLocation: widget.initialRoute),
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: sl<AppConfig>().showDebugBanner,
    );
  }
}
