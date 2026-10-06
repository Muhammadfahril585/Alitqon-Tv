import 'package:equatable/equatable.dart';

/// Domain entity yang merepresentasikan konfigurasi aplikasi.
///
/// Immutable class dengan value equality via [Equatable].
/// Setiap instance merepresentasikan snapshot konfigurasi
/// dari singleton row di table `settings`.
///
/// Ref: SPEC-01 §4.2
class Settings extends Equatable {
  final bool isFirstRun;

  // Identity
  final String mosqueName;
  final String mosqueAddress;

  // Location
  final String cityName;
  final String provinceName;
  final double latitude;
  final double longitude;
  final String timezone;

  // Calculation
  final String calculationMethod;

  // Time Corrections / Ihtiyat (minutes)
  final int offsetSubuh;
  final int offsetSyuruq;
  final int offsetDhuha;
  final int offsetDzuhur;
  final int offsetAshar;
  final int offsetMaghrib;
  final int offsetIsya;

  // Dhuha offset from Syuruq (minutes)
  final int dhuhaOffsetMinutes;

  // Hijri Date Adjustment (days)
  final int hijriAdjustment;

  // Iqomah Delays (minutes)
  final int iqomahSubuh;
  final int iqomahDzuhur;
  final int iqomahAshar;
  final int iqomahMaghrib;
  final int iqomahIsya;

  // Iqomah Jum'at (minutes) — berlaku khusus hari Jumat, setelah khutbah
  final int iqomahJumat;

  // Timing
  final int preAdzanMinutes;
  final int sholatDurationMinutes;

  /// Durasi layar mati khusus hari Jum'at (menit). Mencakup khutbah + sholat 2 rakaat.
  final int sholatJumatDurationMinutes;
  final int adzanDurationSeconds;

  // Display
  final String runningText;

  // PIN
  final String settingsPinHash;

  /// Ketinggian tempat di atas permukaan laut (meter).
  /// Digunakan untuk koreksi waktu Maghrib/Syuruq.
  final int elevation;

  // Informasi Kas Masjid (fitur opsional, default OFF)
  final bool isTreasuryEnabled;
  final int treasuryBalance;
  final int treasuryIncome;
  final int treasuryExpense;

  // Kata Mutiara Islam (fitur opsional, default OFF)
  final bool isWisdomEnabled;
  final int wisdomIntervalMinutes;
  final int wisdomDurationMinutes;
  final int wisdomStartHour;
  final int wisdomStartMinute;
  final int wisdomEndHour;
  final int wisdomEndMinute;
  final List<String> wisdomSelectedIds;
  final bool wisdomShuffle;

  // Mode Hemat Daya Malam (fitur opsional, default OFF)
  final bool isMidnightModeEnabled;
  final int midnightStartHour;
  final int midnightStartMinute;
  final int midnightEndHour;
  final int midnightEndMinute;

  // Alarm Tanda Waktu (fitur opsional, default OFF)
  final bool isPreAdzanAlertEnabled;
  final bool isPreIqomahAlertEnabled;
  final int preAdzanAlertSeconds;
  final int preIqomahAlertSeconds;
  final List<String> youtubeUrls;

  const Settings({
    this.isFirstRun = true,
    this.mosqueName = '',
    this.mosqueAddress = '',
    this.cityName = '',
    this.provinceName = '',
    this.latitude = -6.9175,
    this.longitude = 107.6191,
    this.timezone = 'Asia/Jakarta',
    this.elevation = 0,
    this.calculationMethod = 'kemenag',
    this.offsetSubuh = 0,
    this.offsetSyuruq = 0,
    this.offsetDhuha = 0,
    this.offsetDzuhur = 0,
    this.offsetAshar = 0,
    this.offsetMaghrib = 0,
    this.offsetIsya = 0,
    this.dhuhaOffsetMinutes = 20,
    this.hijriAdjustment = 0,
    this.iqomahSubuh = 10,
    this.iqomahDzuhur = 10,
    this.iqomahAshar = 10,
    this.iqomahMaghrib = 7,
    this.iqomahIsya = 10,
    this.iqomahJumat = 10,
    this.preAdzanMinutes = 10,
    this.sholatDurationMinutes = 15,
    this.sholatJumatDurationMinutes = 45,
    this.adzanDurationSeconds = 180,
    this.runningText = 'Selamat datang di masjid kami',
    this.settingsPinHash = '',
    this.isTreasuryEnabled = false,
    this.treasuryBalance = 0,
    this.treasuryIncome = 0,
    this.treasuryExpense = 0,
    this.isWisdomEnabled = false,
    this.wisdomIntervalMinutes = 15,
    this.wisdomDurationMinutes = 3,
    this.wisdomStartHour = 6,
    this.wisdomStartMinute = 0,
    this.wisdomEndHour = 21,
    this.wisdomEndMinute = 0,
    this.wisdomSelectedIds = const <String>[],
    this.wisdomShuffle = false,
    this.isMidnightModeEnabled = false,
    this.midnightStartHour = 23,
    this.midnightStartMinute = 0,
    this.midnightEndHour = 3,
    this.midnightEndMinute = 30,
    this.isPreAdzanAlertEnabled = false,
    this.isPreIqomahAlertEnabled = false,
    this.preAdzanAlertSeconds = 10,
    this.preIqomahAlertSeconds = 10,
    this.youtubeUrls = const <String>[],
  });

  /// Membuat salinan [Settings] dengan field tertentu di-override.
  Settings copyWith({
    bool? isFirstRun,
    String? mosqueName,
    String? mosqueAddress,
    String? cityName,
    String? provinceName,
    double? latitude,
    double? longitude,
    String? timezone,
    String? calculationMethod,
    int? offsetSubuh,
    int? offsetSyuruq,
    int? offsetDhuha,
    int? offsetDzuhur,
    int? offsetAshar,
    int? offsetMaghrib,
    int? offsetIsya,
    int? dhuhaOffsetMinutes,
    int? hijriAdjustment,
    int? iqomahSubuh,
    int? iqomahDzuhur,
    int? iqomahAshar,
    int? iqomahMaghrib,
    int? iqomahIsya,
    int? iqomahJumat,
    int? preAdzanMinutes,
    int? sholatDurationMinutes,
    int? sholatJumatDurationMinutes,
    int? adzanDurationSeconds,
    String? runningText,
    String? settingsPinHash,
    int? elevation,
    bool? isTreasuryEnabled,
    int? treasuryBalance,
    int? treasuryIncome,
    int? treasuryExpense,
    bool? isWisdomEnabled,
    int? wisdomIntervalMinutes,
    int? wisdomDurationMinutes,
    int? wisdomStartHour,
    int? wisdomStartMinute,
    int? wisdomEndHour,
    int? wisdomEndMinute,
    List<String>? wisdomSelectedIds,
    bool? wisdomShuffle,
    bool? isMidnightModeEnabled,
    int? midnightStartHour,
    int? midnightStartMinute,
    int? midnightEndHour,
    int? midnightEndMinute,
    bool? isPreAdzanAlertEnabled,
    bool? isPreIqomahAlertEnabled,
    int? preAdzanAlertSeconds,
    int? preIqomahAlertSeconds,
    List<String>? youtubeUrls,
  }) {
    return Settings(
      isFirstRun: isFirstRun ?? this.isFirstRun,
      mosqueName: mosqueName ?? this.mosqueName,
      mosqueAddress: mosqueAddress ?? this.mosqueAddress,
      cityName: cityName ?? this.cityName,
      provinceName: provinceName ?? this.provinceName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timezone: timezone ?? this.timezone,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      offsetSubuh: offsetSubuh ?? this.offsetSubuh,
      offsetSyuruq: offsetSyuruq ?? this.offsetSyuruq,
      offsetDhuha: offsetDhuha ?? this.offsetDhuha,
      offsetDzuhur: offsetDzuhur ?? this.offsetDzuhur,
      offsetAshar: offsetAshar ?? this.offsetAshar,
      offsetMaghrib: offsetMaghrib ?? this.offsetMaghrib,
      offsetIsya: offsetIsya ?? this.offsetIsya,
      dhuhaOffsetMinutes: dhuhaOffsetMinutes ?? this.dhuhaOffsetMinutes,
      hijriAdjustment: hijriAdjustment ?? this.hijriAdjustment,
      iqomahSubuh: iqomahSubuh ?? this.iqomahSubuh,
      iqomahDzuhur: iqomahDzuhur ?? this.iqomahDzuhur,
      iqomahAshar: iqomahAshar ?? this.iqomahAshar,
      iqomahMaghrib: iqomahMaghrib ?? this.iqomahMaghrib,
      iqomahIsya: iqomahIsya ?? this.iqomahIsya,
      iqomahJumat: iqomahJumat ?? this.iqomahJumat,
      preAdzanMinutes: preAdzanMinutes ?? this.preAdzanMinutes,
      sholatDurationMinutes:
          sholatDurationMinutes ?? this.sholatDurationMinutes,
      sholatJumatDurationMinutes:
          sholatJumatDurationMinutes ?? this.sholatJumatDurationMinutes,
      adzanDurationSeconds: adzanDurationSeconds ?? this.adzanDurationSeconds,
      runningText: runningText ?? this.runningText,
      settingsPinHash: settingsPinHash ?? this.settingsPinHash,
      elevation: elevation ?? this.elevation,
      isTreasuryEnabled: isTreasuryEnabled ?? this.isTreasuryEnabled,
      treasuryBalance: treasuryBalance ?? this.treasuryBalance,
      treasuryIncome: treasuryIncome ?? this.treasuryIncome,
      treasuryExpense: treasuryExpense ?? this.treasuryExpense,
      isWisdomEnabled: isWisdomEnabled ?? this.isWisdomEnabled,
      wisdomIntervalMinutes:
          wisdomIntervalMinutes ?? this.wisdomIntervalMinutes,
      wisdomDurationMinutes:
          wisdomDurationMinutes ?? this.wisdomDurationMinutes,
      wisdomStartHour: wisdomStartHour ?? this.wisdomStartHour,
      wisdomStartMinute: wisdomStartMinute ?? this.wisdomStartMinute,
      wisdomEndHour: wisdomEndHour ?? this.wisdomEndHour,
      wisdomEndMinute: wisdomEndMinute ?? this.wisdomEndMinute,
      wisdomSelectedIds: wisdomSelectedIds ?? this.wisdomSelectedIds,
      wisdomShuffle: wisdomShuffle ?? this.wisdomShuffle,
      isMidnightModeEnabled:
          isMidnightModeEnabled ?? this.isMidnightModeEnabled,
      midnightStartHour: midnightStartHour ?? this.midnightStartHour,
      midnightStartMinute: midnightStartMinute ?? this.midnightStartMinute,
      midnightEndHour: midnightEndHour ?? this.midnightEndHour,
      midnightEndMinute: midnightEndMinute ?? this.midnightEndMinute,
      isPreAdzanAlertEnabled:
          isPreAdzanAlertEnabled ?? this.isPreAdzanAlertEnabled,
      isPreIqomahAlertEnabled:
          isPreIqomahAlertEnabled ?? this.isPreIqomahAlertEnabled,
      preAdzanAlertSeconds: preAdzanAlertSeconds ?? this.preAdzanAlertSeconds,
      preIqomahAlertSeconds:
          preIqomahAlertSeconds ?? this.preIqomahAlertSeconds,
      youtubeUrls: youtubeUrls ?? this.youtubeUrls,
    );
  }

  @override
  List<Object?> get props => [
    isFirstRun,
    mosqueName,
    mosqueAddress,
    cityName,
    provinceName,
    latitude,
    longitude,
    timezone,
    calculationMethod,
    offsetSubuh,
    offsetSyuruq,
    offsetDhuha,
    offsetDzuhur,
    offsetAshar,
    offsetMaghrib,
    offsetIsya,
    dhuhaOffsetMinutes,
    hijriAdjustment,
    iqomahSubuh,
    iqomahDzuhur,
    iqomahAshar,
    iqomahMaghrib,
    iqomahIsya,
    iqomahJumat,
    preAdzanMinutes,
    sholatDurationMinutes,
    sholatJumatDurationMinutes,
    adzanDurationSeconds,
    runningText,
    settingsPinHash,
    elevation,
    isTreasuryEnabled,
    treasuryBalance,
    treasuryIncome,
    treasuryExpense,
    isWisdomEnabled,
    wisdomIntervalMinutes,
    wisdomDurationMinutes,
    wisdomStartHour,
    wisdomStartMinute,
    wisdomEndHour,
    wisdomEndMinute,
    wisdomSelectedIds,
    wisdomShuffle,
    isMidnightModeEnabled,
    midnightStartHour,
    midnightStartMinute,
    midnightEndHour,
    midnightEndMinute,
    isPreAdzanAlertEnabled,
    isPreIqomahAlertEnabled,
    preAdzanAlertSeconds,
    preIqomahAlertSeconds,
    youtubeUrls,
  ];
}
