import 'dart:convert';

import 'package:miqotul_khoir_tv/domain/entities/settings.dart';

/// Data model yang mengkonversi antara [Settings] entity dan SQLite map.
///
/// Extends [Settings] sehingga bisa digunakan di mana pun [Settings] diterima
/// (Liskov Substitution Principle).
///
/// Mapping conventions:
/// - SQLite column names: `snake_case`
/// - Dart field names: `camelCase`
/// - Boolean: SQLite `INTEGER` (0/1) → Dart `bool`
///
/// Ref: SPEC-01 §4.4
class SettingsModel extends Settings {
  const SettingsModel({
    super.isFirstRun,
    super.mosqueName,
    super.mosqueAddress,
    super.cityName,
    super.provinceName,
    super.latitude,
    super.longitude,
    super.timezone,
    super.calculationMethod,
    super.offsetSubuh,
    super.offsetSyuruq,
    super.offsetDhuha,
    super.offsetDzuhur,
    super.offsetAshar,
    super.offsetMaghrib,
    super.offsetIsya,
    super.dhuhaOffsetMinutes,
    super.hijriAdjustment,
    super.iqomahSubuh,
    super.iqomahDzuhur,
    super.iqomahAshar,
    super.iqomahMaghrib,
    super.iqomahIsya,
    super.iqomahJumat,
    super.preAdzanMinutes,
    super.sholatDurationMinutes,
    super.sholatJumatDurationMinutes,
    super.adzanDurationSeconds,
    super.runningText,
    super.settingsPinHash,
    super.elevation,
    super.isTreasuryEnabled,
    super.treasuryBalance,
    super.treasuryIncome,
    super.treasuryExpense,
    super.isWisdomEnabled,
    super.wisdomIntervalMinutes,
    super.wisdomDurationMinutes,
    super.wisdomStartHour,
    super.wisdomStartMinute,
    super.wisdomEndHour,
    super.wisdomEndMinute,
    super.wisdomSelectedIds,
    super.wisdomShuffle,
    super.isMidnightModeEnabled,
    super.midnightStartHour,
    super.midnightStartMinute,
    super.midnightEndHour,
    super.midnightEndMinute,
    super.isPreAdzanAlertEnabled,
    super.isPreIqomahAlertEnabled,
    super.preAdzanAlertSeconds,
    super.preIqomahAlertSeconds,
    super.youtubeUrls,
  });

  /// Membuat [SettingsModel] dari raw SQLite `Map<String, dynamic>`.
  ///
  /// Melakukan konversi:
  /// - `is_first_run` (int 0/1) → `isFirstRun` (bool)
  /// - Semua snake_case keys → camelCase fields
  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      isFirstRun: (map['is_first_run'] as int) == 1,
      mosqueName: map['mosque_name'] as String,
      mosqueAddress: map['mosque_address'] as String,
      cityName: map['city_name'] as String,
      provinceName: map['province_name'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timezone: map['timezone'] as String,
      calculationMethod: map['calculation_method'] as String,
      offsetSubuh: map['offset_subuh'] as int,
      offsetSyuruq: map['offset_syuruq'] as int,
      offsetDhuha: map['offset_dhuha'] as int,
      offsetDzuhur: map['offset_dzuhur'] as int,
      offsetAshar: map['offset_ashar'] as int,
      offsetMaghrib: map['offset_maghrib'] as int,
      offsetIsya: map['offset_isya'] as int,
      dhuhaOffsetMinutes: map['dhuha_offset_minutes'] as int,
      hijriAdjustment: map['hijri_adjustment'] as int,
      iqomahSubuh: map['iqomah_subuh'] as int,
      iqomahDzuhur: map['iqomah_dzuhur'] as int,
      iqomahAshar: map['iqomah_ashar'] as int,
      iqomahMaghrib: map['iqomah_maghrib'] as int,
      iqomahIsya: map['iqomah_isya'] as int,
      iqomahJumat: map['iqomah_jumat'] as int,
      preAdzanMinutes: map['pre_adzan_minutes'] as int,
      sholatDurationMinutes: map['sholat_duration_minutes'] as int,
      sholatJumatDurationMinutes: map['sholat_jumat_duration_minutes'] as int,
      adzanDurationSeconds: map['adzan_duration_seconds'] as int,
      runningText: map['running_text'] as String,
      settingsPinHash: map['settings_pin_hash'] as String,
      elevation: (map['elevation'] as int?) ?? 0,
      isTreasuryEnabled: (map['is_treasury_enabled'] as int? ?? 0) == 1,
      treasuryBalance: map['treasury_balance'] as int? ?? 0,
      treasuryIncome: map['treasury_income'] as int? ?? 0,
      treasuryExpense: map['treasury_expense'] as int? ?? 0,
      isWisdomEnabled: (map['is_wisdom_enabled'] as int? ?? 0) == 1,
      wisdomIntervalMinutes: map['wisdom_interval_minutes'] as int? ?? 15,
      wisdomDurationMinutes: map['wisdom_duration_minutes'] as int? ?? 3,
      wisdomStartHour: map['wisdom_start_hour'] as int? ?? 6,
      wisdomStartMinute: map['wisdom_start_minute'] as int? ?? 0,
      wisdomEndHour: map['wisdom_end_hour'] as int? ?? 21,
      wisdomEndMinute: map['wisdom_end_minute'] as int? ?? 0,
      wisdomSelectedIds: List<String>.from(
        jsonDecode(map['wisdom_selected_ids'] as String? ?? '[]') as List,
      ),
      wisdomShuffle: (map['wisdom_shuffle'] as int? ?? 0) == 1,
      isMidnightModeEnabled:
          (map['is_midnight_mode_enabled'] as int? ?? 0) == 1,
      midnightStartHour: map['midnight_start_hour'] as int? ?? 23,
      midnightStartMinute: map['midnight_start_minute'] as int? ?? 0,
      midnightEndHour: map['midnight_end_hour'] as int? ?? 3,
      midnightEndMinute: map['midnight_end_minute'] as int? ?? 30,
      isPreAdzanAlertEnabled:
          (map['is_pre_adzan_alert_enabled'] as int? ?? 0) == 1,
      isPreIqomahAlertEnabled:
          (map['is_pre_iqomah_alert_enabled'] as int? ?? 0) == 1,
      preAdzanAlertSeconds: map['pre_adzan_alert_seconds'] as int? ?? 10,
      preIqomahAlertSeconds: map['pre_iqomah_alert_seconds'] as int? ?? 10,
      youtubeUrls: List<String>.from(
        jsonDecode(map['youtube_urls'] as String? ?? '[]') as List,
      ),
    );
  }

  /// Mengkonversi entity ke SQLite-compatible map.
  ///
  /// Output menggunakan snake_case keys sesuai column names di database.
  /// Boolean `isFirstRun` → int (0/1).
  /// Tidak menyertakan `id`, `created_at`, `updated_at` karena
  /// dikelola oleh database.
  Map<String, dynamic> toMap() {
    return {
      'is_first_run': isFirstRun ? 1 : 0,
      'mosque_name': mosqueName,
      'mosque_address': mosqueAddress,
      'city_name': cityName,
      'province_name': provinceName,
      'latitude': latitude,
      'longitude': longitude,
      'timezone': timezone,
      'calculation_method': calculationMethod,
      'offset_subuh': offsetSubuh,
      'offset_syuruq': offsetSyuruq,
      'offset_dhuha': offsetDhuha,
      'offset_dzuhur': offsetDzuhur,
      'offset_ashar': offsetAshar,
      'offset_maghrib': offsetMaghrib,
      'offset_isya': offsetIsya,
      'dhuha_offset_minutes': dhuhaOffsetMinutes,
      'hijri_adjustment': hijriAdjustment,
      'iqomah_subuh': iqomahSubuh,
      'iqomah_dzuhur': iqomahDzuhur,
      'iqomah_ashar': iqomahAshar,
      'iqomah_maghrib': iqomahMaghrib,
      'iqomah_isya': iqomahIsya,
      'iqomah_jumat': iqomahJumat,
      'pre_adzan_minutes': preAdzanMinutes,
      'sholat_duration_minutes': sholatDurationMinutes,
      'sholat_jumat_duration_minutes': sholatJumatDurationMinutes,
      'adzan_duration_seconds': adzanDurationSeconds,
      'running_text': runningText,
      'settings_pin_hash': settingsPinHash,
      'elevation': elevation,
      'is_treasury_enabled': isTreasuryEnabled ? 1 : 0,
      'treasury_balance': treasuryBalance,
      'treasury_income': treasuryIncome,
      'treasury_expense': treasuryExpense,
      'is_wisdom_enabled': isWisdomEnabled ? 1 : 0,
      'wisdom_interval_minutes': wisdomIntervalMinutes,
      'wisdom_duration_minutes': wisdomDurationMinutes,
      'wisdom_start_hour': wisdomStartHour,
      'wisdom_start_minute': wisdomStartMinute,
      'wisdom_end_hour': wisdomEndHour,
      'wisdom_end_minute': wisdomEndMinute,
      'wisdom_selected_ids': jsonEncode(wisdomSelectedIds),
      'wisdom_shuffle': wisdomShuffle ? 1 : 0,
      'is_midnight_mode_enabled': isMidnightModeEnabled ? 1 : 0,
      'midnight_start_hour': midnightStartHour,
      'midnight_start_minute': midnightStartMinute,
      'midnight_end_hour': midnightEndHour,
      'midnight_end_minute': midnightEndMinute,
      'is_pre_adzan_alert_enabled': isPreAdzanAlertEnabled ? 1 : 0,
      'is_pre_iqomah_alert_enabled': isPreIqomahAlertEnabled ? 1 : 0,
      'pre_adzan_alert_seconds': preAdzanAlertSeconds,
      'pre_iqomah_alert_seconds': preIqomahAlertSeconds,
      'youtube_urls': jsonEncode(youtubeUrls),
    };
  }
}
