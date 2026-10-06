import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/repositories/settings_repository.dart';
import '../display_state/display_state_cubit.dart';
import '../prayer_time/prayer_time_cubit.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository settingsRepository;
  final PrayerTimeCubit prayerTimeCubit;
  final DisplayStateCubit displayStateCubit;

  Timer? _debounceTimer;

  SettingsCubit({
    required this.settingsRepository,
    required this.prayerTimeCubit,
    required this.displayStateCubit,
  }) : super(SettingsInitial()) {
    // Auto-load settings saat cubit pertama kali dibuat
    loadSettings();
  }

  Future<void> loadSettings() async {
    emit(SettingsLoading());
    try {
      // Load settings from repository (Direct return, no Either)
      final settings = await settingsRepository.getSettings();
      emit(SettingsLoaded(settings: settings));
    } catch (e) {
      emit(SettingsError(message: e.toString()));
    }
  }

  // Auto-save mechanism with debounce
  void _debounceSave(
    String field,
    Map<String, dynamic> updates, {
    bool triggerRecalculation = false,
    bool triggerConfigUpdate = false,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveField(
        field,
        updates,
        triggerRecalculation: triggerRecalculation,
        triggerConfigUpdate: triggerConfigUpdate,
      );
    });
  }

  Future<void> _saveField(
    String field,
    Map<String, dynamic> updates, {
    bool triggerRecalculation = false,
    bool triggerConfigUpdate = false,
  }) async {
    if (state is SettingsLoaded) {
      final currentSettings = (state as SettingsLoaded).settings;
      emit(SettingsLoaded(settings: currentSettings, isSaving: true));

      try {
        await settingsRepository.updateSettings(updates);

        // Reload to ensure state consistency
        final newSettings = await settingsRepository.getSettings();
        emit(
          SettingsLoaded(
            settings: newSettings,
            isSaving: false,
            lastSavedField: field,
          ),
        );

        // Trigger external cubits
        if (triggerRecalculation) {
          await prayerTimeCubit.recalculate();
        }

        if (triggerConfigUpdate) {
          await displayStateCubit.onSettingsChanged();
        }
      } catch (e) {
        emit(
          SettingsError(
            message: e.toString(),
            lastKnownSettings: currentSettings,
          ),
        );
      }
    }
  }

  // --- Phase 3: Update Methods ---

  /// Menyimpan nama dan alamat masjid (identitas).
  ///
  /// Returns true jika berhasil, false jika gagal.
  Future<void> updateIdentity({
    required String mosqueName,
    required String mosqueAddress,
  }) {
    return _saveField('identity', {
      'mosque_name': mosqueName,
      'mosque_address': mosqueAddress,
    });
  }

  void updateIhtiyatOffset(String prayerName, int minutes) {
    if (minutes < -30 || minutes > 30) return; // Validation

    // Map prayerName to field name
    final field = 'offset_${prayerName.toLowerCase()}';
    _debounceSave(field, {field: minutes}, triggerRecalculation: true);
  }

  void updateIqomahDuration(String prayerName, int minutes) {
    if (minutes < 1 || minutes > 30) return;

    // Jum'at mengandung apostrof — map ke nama kolom DB yang valid (iqomah_jumat)
    final dbKey = prayerName.toLowerCase() == "jum'at"
        ? 'iqomah_jumat'
        : 'iqomah_${prayerName.toLowerCase()}';
    _debounceSave(dbKey, {dbKey: minutes}, triggerConfigUpdate: true);
  }

  void updateDhuhaOffset(int minutes) {
    if (minutes < 10 || minutes > 60) {
      return; // Adjusted range based on typical needs
    }
    _debounceSave('dhuha', {
      'dhuha_offset_minutes': minutes,
    }, triggerRecalculation: true);
  }

  void updatePreAdzanMinutes(int minutes) {
    if (minutes < 1 || minutes > 30) return;
    _debounceSave('pre_adzan', {
      'pre_adzan_minutes': minutes,
    }, triggerConfigUpdate: true);
  }

  void updateSholatDuration(int minutes) {
    if (minutes < 5 || minutes > 60) return;
    _debounceSave('sholat_duration', {
      'sholat_duration_minutes': minutes,
    }, triggerConfigUpdate: true);
  }

  void updateSholatJumatDuration(int minutes) {
    if (minutes < 10 || minutes > 90) return;
    _debounceSave('sholat_jumat_duration', {
      'sholat_jumat_duration_minutes': minutes,
    }, triggerConfigUpdate: true);
  }

  void updateAdzanDuration(int seconds) {
    if (seconds < 60 || seconds > 600) return;
    _debounceSave('adzan_duration', {
      'adzan_duration_seconds': seconds,
    }, triggerConfigUpdate: true);
  }

  void updateRunningText(String text) {
    _debounceSave('running_text', {'running_text': text});
  }
    /// Update daftar URL video YouTube untuk slideshow layar utama.
  /// [urls] di-encode sebagai JSON string sebelum disimpan ke SQLite.
  void updateYoutubeUrls(List<String> urls) {
    _debounceSave('youtube_urls', {
      'youtube_urls': jsonEncode(urls),
    });
  }

  void updateHijriAdjustment(int days) {
    if (days < -2 || days > 2) return;
    _debounceSave('hijri_adjustment', {
      'hijri_adjustment': days,
    }, triggerRecalculation: true);
  }

  // --- Treasury Management ---

  /// Toggle aktif/nonaktif tampilan informasi kas masjid di layar utama.
  /// Disimpan langsung (tanpa debounce) karena toggle bersifat instan.
  Future<void> updateTreasuryEnabled(bool enabled) {
    return _saveField('treasury_enabled', {
      'is_treasury_enabled': enabled ? 1 : 0,
    });
  }

  /// Update saldo kas masjid.
  /// Validasi: nilai harus antara 0 dan 999.999.999.999 (di bawah 1 triliun).
  void updateTreasuryBalance(int amount) {
    if (amount < 0 || amount > 999999999999) return;
    _debounceSave('treasury_balance', {'treasury_balance': amount});
  }

  /// Update pemasukan periode ini.
  /// Validasi: nilai harus antara 0 dan 999.999.999.999 (di bawah 1 triliun).
  void updateTreasuryIncome(int amount) {
    if (amount < 0 || amount > 999999999999) return;
    _debounceSave('treasury_income', {'treasury_income': amount});
  }

  /// Update pengeluaran periode ini.
  /// Validasi: nilai harus antara 0 dan 999.999.999.999 (di bawah 1 triliun).
  void updateTreasuryExpense(int amount) {
    if (amount < 0 || amount > 999999999999) return;
    _debounceSave('treasury_expense', {'treasury_expense': amount});
  }

  // --- Kata Mutiara Islam ---

  /// Toggle aktif/nonaktif fitur Kata Mutiara Islam.
  /// Disimpan langsung (tanpa debounce) karena toggle bersifat instan.
  Future<void> updateWisdomEnabled(bool enabled) {
    return _saveField('wisdom_enabled', {
      'is_wisdom_enabled': enabled ? 1 : 0,
    }, triggerConfigUpdate: true);
  }

  /// Update interval kemunculan Kata Mutiara (menit).
  /// Validasi: 5–30 menit sesuai REQ-003.
  void updateWisdomIntervalMinutes(int minutes) {
    if (minutes < 5 || minutes > 30) return;
    _debounceSave('wisdom_interval_minutes', {
      'wisdom_interval_minutes': minutes,
    }, triggerConfigUpdate: true);
  }

  /// Update durasi tampil per item Kata Mutiara (menit).
  /// Validasi: 1–10 menit sesuai REQ-004.
  void updateWisdomDurationMinutes(int minutes) {
    if (minutes < 1 || minutes > 10) return;
    _debounceSave('wisdom_duration_minutes', {
      'wisdom_duration_minutes': minutes,
    }, triggerConfigUpdate: true);
  }

  /// Update jam mulai jendela aktif Kata Mutiara.
  /// Validasi: 0–23.
  void updateWisdomStartHour(int hour) {
    if (hour < 0 || hour > 23) return;
    _debounceSave('wisdom_start_hour', {
      'wisdom_start_hour': hour,
    }, triggerConfigUpdate: true);
  }

  /// Update menit mulai jendela aktif Kata Mutiara.
  /// Validasi: 0–59.
  void updateWisdomStartMinute(int minute) {
    if (minute < 0 || minute > 59) return;
    _debounceSave('wisdom_start_minute', {
      'wisdom_start_minute': minute,
    }, triggerConfigUpdate: true);
  }

  /// Update jam selesai jendela aktif Kata Mutiara.
  /// Validasi: 0–23.
  void updateWisdomEndHour(int hour) {
    if (hour < 0 || hour > 23) return;
    _debounceSave('wisdom_end_hour', {
      'wisdom_end_hour': hour,
    }, triggerConfigUpdate: true);
  }

  /// Update menit selesai jendela aktif Kata Mutiara.
  /// Validasi: 0–59.
  void updateWisdomEndMinute(int minute) {
    if (minute < 0 || minute > 59) return;
    _debounceSave('wisdom_end_minute', {
      'wisdom_end_minute': minute,
    }, triggerConfigUpdate: true);
  }

  /// Update daftar ID item Kata Mutiara yang aktif.
  /// [ids] di-encode sebagai JSON string sebelum disimpan ke SQLite.
  void updateWisdomSelectedIds(List<String> ids) {
    _debounceSave('wisdom_selected_ids', {
      'wisdom_selected_ids': jsonEncode(ids),
    }, triggerConfigUpdate: true);
  }

  /// Toggle mode urut/acak tampilan Kata Mutiara.
  /// Disimpan langsung (tanpa debounce) karena toggle bersifat instan.
  Future<void> updateWisdomShuffle(bool shuffle) {
    return _saveField('wisdom_shuffle', {
      'wisdom_shuffle': shuffle ? 1 : 0,
    }, triggerConfigUpdate: true);
  }

  // --- Mode Hemat Daya Tengah Malam ---

  /// Toggle aktif/nonaktif Mode Hemat Daya Tengah Malam.
  /// Disimpan langsung (tanpa debounce) karena toggle bersifat instan.
  Future<void> updateMidnightModeEnabled(bool enabled) {
    return _saveField('midnight_mode_enabled', {
      'is_midnight_mode_enabled': enabled ? 1 : 0,
    }, triggerConfigUpdate: true);
  }

  /// Update jam mulai window midnight mode.
  /// Validasi: 0–23.
  void updateMidnightStartHour(int hour) {
    if (hour < 0 || hour > 23) return;
    _debounceSave('midnight_start_hour', {
      'midnight_start_hour': hour,
    }, triggerConfigUpdate: true);
  }

  /// Update menit mulai window midnight mode.
  /// Validasi: 0–59.
  void updateMidnightStartMinute(int minute) {
    if (minute < 0 || minute > 59) return;
    _debounceSave('midnight_start_minute', {
      'midnight_start_minute': minute,
    }, triggerConfigUpdate: true);
  }

  /// Update jam berakhir window midnight mode.
  /// Validasi: 0–23.
  void updateMidnightEndHour(int hour) {
    if (hour < 0 || hour > 23) return;
    _debounceSave('midnight_end_hour', {
      'midnight_end_hour': hour,
    }, triggerConfigUpdate: true);
  }

  /// Update menit berakhir window midnight mode.
  /// Validasi: 0–59.
  void updateMidnightEndMinute(int minute) {
    if (minute < 0 || minute > 59) return;
    _debounceSave('midnight_end_minute', {
      'midnight_end_minute': minute,
    }, triggerConfigUpdate: true);
  }

  // --- Alarm Tanda Waktu ---

  /// Toggle aktif/nonaktif Alarm Tanda Waktu sebelum Adzan.
  /// Disimpan langsung (tanpa debounce) karena toggle bersifat instan.
  Future<void> updatePreAdzanAlertEnabled(bool value) {
    return _saveField('pre_adzan_alert_enabled', {
      'is_pre_adzan_alert_enabled': value ? 1 : 0,
    }, triggerConfigUpdate: true);
  }

  /// Toggle aktif/nonaktif Alarm Tanda Waktu sebelum Iqomah.
  /// Disimpan langsung (tanpa debounce) karena toggle bersifat instan.
  Future<void> updatePreIqomahAlertEnabled(bool value) {
    return _saveField('pre_iqomah_alert_enabled', {
      'is_pre_iqomah_alert_enabled': value ? 1 : 0,
    }, triggerConfigUpdate: true);
  }

  /// Update durasi alarm sebelum Adzan (detik).
  /// Validasi: 5–15 detik sesuai REQ-002.
  void updatePreAdzanAlertSeconds(int seconds) {
    if (seconds < 5 || seconds > 15) return;
    _debounceSave('pre_adzan_alert_seconds', {
      'pre_adzan_alert_seconds': seconds,
    }, triggerConfigUpdate: true);
  }

  /// Update durasi alarm sebelum Iqomah (detik).
  /// Validasi: 5–15 detik sesuai REQ-002.
  void updatePreIqomahAlertSeconds(int seconds) {
    if (seconds < 5 || seconds > 15) return;
    _debounceSave('pre_iqomah_alert_seconds', {
      'pre_iqomah_alert_seconds': seconds,
    }, triggerConfigUpdate: true);
  }

  // --- Phase 4: PIN Management ---

  Future<bool> verifyPin(String inputPin) async {
    try {
      return await settingsRepository.verifyPin(inputPin);
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String newPin) async {
    if (state is! SettingsLoaded) return;

    final currentSettings = (state as SettingsLoaded).settings;
    emit(SettingsLoaded(settings: currentSettings, isSaving: true));

    try {
      await settingsRepository.setPin(newPin);

      // Reload logic
      final newSettings = await settingsRepository.getSettings();
      emit(SettingsLoaded(settings: newSettings, isSaving: false));
    } catch (e) {
      emit(
        SettingsError(
          message: e.toString(),
          lastKnownSettings: currentSettings,
        ),
      );
    }
  }

  Future<void> removePin() async {
    await setPin('');
  }

  bool get isPinEnabled {
    if (state is SettingsLoaded) {
      return (state as SettingsLoaded).settings.settingsPinHash.isNotEmpty;
    }
    return false;
  }

  // --- Reset Data ---

  /// Reset semua pengaturan ke factory default dan state kembali ke is_first_run=1.
  /// Setelah selesai, akan fetch settings terbaru dan emit state.
  Future<void> resetSettings() async {
    emit(SettingsLoading());
    try {
      await settingsRepository.resetSettings();
      // Reload setelah reset
      await loadSettings();
    } catch (e) {
      emit(SettingsError(message: 'Gagal melakukan factory reset: $e'));
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
