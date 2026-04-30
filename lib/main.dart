import 'dart:ui';

import 'package:error_stack/error_stack.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/theme/islamic_theme.dart';
import 'data/datasources/city_local_data_source.dart';
import 'data/datasources/database_helper.dart';
import 'data/datasources/settings_local_data_source.dart';
import 'data/datasources/wisdom_quote_local_data_source.dart';
import 'data/repositories/city_repository_impl.dart';
import 'data/repositories/settings_repository_impl.dart';
import 'data/repositories/wisdom_quote_repository_impl.dart';
import 'data/services/audio_alert_service_impl.dart';
import 'domain/repositories/city_repository.dart';
import 'domain/repositories/settings_repository.dart';
import 'domain/repositories/wisdom_quote_repository.dart';
import 'domain/usecases/calculate_prayer_times_use_case.dart';
import 'domain/usecases/evaluate_display_state_use_case.dart';
import 'presentation/cubits/display_state/display_state_cubit.dart';
import 'presentation/cubits/prayer_time/prayer_time_cubit.dart';
import 'presentation/cubits/settings/settings_cubit.dart';
import 'presentation/pages/splash_page.dart';

/// Entry point aplikasi Miqotul Khoir TV.
///
/// Inisialisasi:
/// - [WidgetsFlutterBinding.ensureInitialized] — wajib sebelum runApp (TASK-032)
/// - SQLite FFI (Windows) — init desktop database factory
/// - Landscape lock — Android TV selalu landscape
/// - [ScreenUtilInit] — design baseline 1920×1080 (TASK-030)
/// - [IslamicTheme.darkTheme] — Islamic Glassmorphism theme (TASK-031)
/// - Dependency Injection (RepositoryProvider) — Settings & City Repositories
void main() async {
  // TASK-032: Pastikan binding sudah diinisialisasi sebelum runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Nonaktifkan runtime fetching Google Fonts — app ini 100% offline (REQ-offline).
  // Font Poppins sudah di-bundle via pubspec.yaml (assets/fonts/).
  // Tanpa ini, google_fonts mencoba download dari fonts.gstatic.com → crash di device tanpa internet.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Init ErrorStack — harus dipanggil setelah ensureInitialized
  await ErrorStack.init(
    level: ErrorStackLogLevel.verbose,
    initialRoute: '/',
    enableDevPanel: false,
    devPanelConfig: DevPanelConfig(
      enableApiLogging: true,
      enableConsoleLogging: true,
      enableRouteTracking: true,
    ),
    errorWidget: (errorDetails) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Terjadi kesalahan pada aplikasi.',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                errorDetails.exception.toString(),
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    },
  );

  // Init SQLite FFI khusus untuk Windows/Desktop environment
  // Di Android real device ini tidak diperlukan, tapi app ini target Windows juga
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Init locale untuk intl package (DateFormat dengan 'id_ID')
  await initializeDateFormatting('id_ID', null);

  // Init DatabaseHelper singleton
  // Memastikan database siap sebelum app jalan (opsional, tapi good practice)
  await DatabaseHelper().database;

  // Lock orientasi ke landscape — Android TV requirement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await WakelockPlus.enable();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAnalytics.instance.logAppOpen(
    callOptions: AnalyticsCallOptions(global: true),
    parameters: {
      'platform': Platform.operatingSystem,
      'version': '1.0.0',
      'build': 'MiqotulKhoirTV-001',
    },
  );

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  }

  runApp(const MiqotulKhoirApp());
}

/// Root widget aplikasi.
///
/// Menggunakan [ScreenUtilInit] sebagai wrapper terluar untuk memastikan
/// semua `.sp`, `.w`, `.h`, `.r` extensions tersedia di seluruh widget tree.
class MiqotulKhoirApp extends StatelessWidget {
  const MiqotulKhoirApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Setup repositories
    final dbHelper = DatabaseHelper();

    final settingsDataSource = SettingsLocalDataSource(dbHelper);
    final cityDataSource = CityLocalDataSource(dbHelper);

    final settingsRepository = SettingsRepositoryImpl(settingsDataSource);
    final cityRepository = CityRepositoryImpl(cityDataSource);

    // TASK-057: Instansiasi WisdomQuoteRepository (baca dari JSON asset)
    final wisdomDataSource = WisdomQuoteLocalDataSource();
    final wisdomQuoteRepository = WisdomQuoteRepositoryImpl(wisdomDataSource);

    // TASK-030: Wrap MaterialApp dengan ScreenUtilInit
    return ScreenUtilInit(
      // Design baseline: 1920×1080 (REQ-002)
      designSize: const Size(1920, 1080),
      // Adaptasi minimum text size otomatis
      minTextAdapt: true,
      // Tidak perlu split screen mode untuk TV
      splitScreenMode: false,
      builder: (context, child) {
        return MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SettingsRepository>.value(
              value: settingsRepository,
            ),
            RepositoryProvider<CityRepository>.value(value: cityRepository),
            // TASK-058: Provide WisdomQuoteRepository ke widget tree
            RepositoryProvider<WisdomQuoteRepository>.value(
              value: wisdomQuoteRepository,
            ),
          ],
          child: Builder(
            builder: (context) {
              // Use Cases — bergantung pada SettingsRepository
              final calculateUseCase = CalculatePrayerTimesUseCase(
                context.read<SettingsRepository>(),
              );
              final evaluateUseCase = EvaluateDisplayStateUseCase();

              // Cubit instances — dibuat sekali, dikelola di sini
              final prayerTimeCubit = PrayerTimeCubit(calculateUseCase);
              final audioAlertService = AudioAlertServiceImpl();
              final displayStateCubit = DisplayStateCubit(
                evaluateUseCase: evaluateUseCase,
                prayerTimeCubit: prayerTimeCubit,
                settingsRepository: context.read<SettingsRepository>(),
                // TASK-059: Inject WisdomQuoteRepository ke DisplayStateCubit
                wisdomQuoteRepository: context.read<WisdomQuoteRepository>(),
                audioAlertService: audioAlertService,
              );
              final settingsCubit = SettingsCubit(
                settingsRepository: context.read<SettingsRepository>(),
                prayerTimeCubit: prayerTimeCubit,
                displayStateCubit: displayStateCubit,
              );

              return MultiBlocProvider(
                providers: [
                  BlocProvider<PrayerTimeCubit>.value(value: prayerTimeCubit),
                  BlocProvider<DisplayStateCubit>.value(
                    value: displayStateCubit,
                  ),
                  BlocProvider<SettingsCubit>.value(value: settingsCubit),
                ],
                child: MaterialApp(
                  title: 'Miqotul Khoir TV',
                  debugShowCheckedModeBanner: false,
                  // TASK-031: Gunakan Islamic Glassmorphism dark theme
                  theme: IslamicTheme.darkTheme(),
                  // ErrorStack.builder — aktifkan Dev Panel & UI debug overlays
                  builder: ErrorStack.builder,
                  // Route awal ke SplashPage untuk check first-run
                  home: const SplashPage(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
