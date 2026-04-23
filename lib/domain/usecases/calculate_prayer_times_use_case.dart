import 'package:hijri/hijri_calendar.dart';
import 'package:miqotul_khoir_tv/domain/entities/daily_prayer_times.dart';
import 'package:miqotul_khoir_tv/domain/entities/prayer_time.dart';
import 'package:miqotul_khoir_tv/domain/entities/settings.dart';
import 'package:miqotul_khoir_tv/domain/repositories/settings_repository.dart';
import 'package:miqotul_khoir_tv/domain/services/wahdah_calculator.dart';

/// Use case untuk menghitung jadwal sholat harian.
///
/// Proses:
/// 1. Mengambil konfigurasi lokasi dari [SettingsRepository].
/// 2. Menghitung waktu sholat menggunakan [WahdahCalculator] (Wahdah Raw).
/// 3. Menerapkan koreksi tambahan (offset) dari Settings pengguna.
/// 4. Menghitung waktu Dhuha (Syuruq + offset).
/// 5. Mengonversi tanggal ke kalender Hijriah dengan adjustment.
///
/// Metode kalkulasi: Wahdah (Fajr 17.5°, Isya 18°, Mazhab Syafi'i)
/// Ihtiyat bawaan: Dzuhur +4 menit, Maghrib +2 menit (sesuai kalkulator Wahdah)
class CalculatePrayerTimesUseCase {
  final SettingsRepository repository;

  CalculatePrayerTimesUseCase(this.repository);

  /// Menghitung jadwal sholat untuk tanggal [date].
  /// Jika [date] null, menggunakan tanggal hari ini.
  Future<DailyPrayerTimes> execute({DateTime? date}) async {
    final now = date ?? DateTime.now();
    final settings = await repository.getSettings();

    // Validasi Koordinat
    if (settings.latitude < -90 || settings.latitude > 90) {
      throw ArgumentError('Invalid latitude: ${settings.latitude}');
    }
    if (settings.longitude < -180 || settings.longitude > 180) {
      throw ArgumentError('Invalid longitude: ${settings.longitude}');
    }

    return _calculate(settings, now);
  }

  /// Versi synchronous yang menerima [Settings] langsung (tanpa repository).
  ///
  /// Digunakan untuk preview sebelum settings disimpan, misalnya di Setup Wizard.
  DailyPrayerTimes executeWithSettings(Settings settings, {DateTime? date}) {
    final now = date ?? DateTime.now();

    if (settings.latitude < -90 || settings.latitude > 90) {
      throw ArgumentError('Invalid latitude: ${settings.latitude}');
    }
    if (settings.longitude < -180 || settings.longitude > 180) {
      throw ArgumentError('Invalid longitude: ${settings.longitude}');
    }

    return _calculate(settings, now);
  }

  // ==========================
  // KALKULASI INTI
  // ==========================

  DailyPrayerTimes _calculate(Settings settings, DateTime now) {
    // 1. Tentukan timezone offset dari koordinat (WIB=7, WITA=8, WIT=9)
    final tzOffset = getTimezoneOffsetFromCoords(
      settings.latitude,
      settings.longitude,
    );

    // 2. Hitung waktu sholat via Wahdah Calculator
    //    Output sudah include ihtiyat bawaan Wahdah:
    //    Dzuhur +4 menit, Maghrib +2 menit (Subuh/Ashar/Isya +0)
    final wahdah = WahdahCalculator.calculate(
      latitude: settings.latitude,
      longitude: settings.longitude,
      timezoneOffset: tzOffset,
      date: now,
    );

    // 3. Apply offset tambahan dari Settings user (di atas ihtiyat bawaan Wahdah)
    //    Jika user tidak mengubah offset (nilai 0), waktu tampil = hasil Wahdah murni
    final subuh = _applyOffset('Subuh', wahdah.fajr, settings.offsetSubuh);
    final syuruq = _applyOffset('Syuruq', wahdah.sunrise, settings.offsetSyuruq);

    // 4. Dhuha = Syuruq + dhuhaOffsetMinutes (default 20 menit dari Settings)
    final dhuhaBase = wahdah.sunrise.add(
      Duration(minutes: settings.dhuhaOffsetMinutes),
    );
    final dhuha = _applyOffset('Dhuha', dhuhaBase, settings.offsetDhuha);

    // Label Dzuhur berubah menjadi "Jum'at" setiap hari Jumat
    final dzuhurLabel = now.weekday == DateTime.friday ? "Jum'at" : 'Dzuhur';
    final dzuhur = _applyOffset(dzuhurLabel, wahdah.dhuhr, settings.offsetDzuhur);

    final ashar = _applyOffset('Ashar', wahdah.asr, settings.offsetAshar);
    final maghrib = _applyOffset('Maghrib', wahdah.maghrib, settings.offsetMaghrib);
    final isya = _applyOffset('Isya', wahdah.isha, settings.offsetIsya);

    // 5. Konversi Hijriah
    final hijriDateStr = _formatHijriDate(now, settings.hijriAdjustment);

    return DailyPrayerTimes(
      date: now,
      hijriDate: hijriDateStr,
      subuh: subuh,
      syuruq: syuruq,
      dhuha: dhuha,
      dzuhur: dzuhur,
      ashar: ashar,
      maghrib: maghrib,
      isya: isya,
    );
  }

  // ==========================
  // HELPER
  // ==========================

  /// Membuat [PrayerTime] dengan menerapkan offset tambahan.
  ///
  /// [original] = waktu dari WahdahCalculator (sudah include ihtiyat bawaan)
  /// [offsetMinutes] = koreksi tambahan dari Settings pengguna
  ///
  /// Ceiling diterapkan jika masih ada sisa detik sebelum offset ditambahkan.
  PrayerTime _applyOffset(String name, DateTime original, int offsetMinutes) {
    final ceiled = (original.second > 0 ||
            original.millisecond > 0 ||
            original.microsecond > 0)
        ? DateTime(
            original.year,
            original.month,
            original.day,
            original.hour,
            original.minute,
          ).add(const Duration(minutes: 1))
        : DateTime(
            original.year,
            original.month,
            original.day,
            original.hour,
            original.minute,
          );

    final adjusted = ceiled.add(Duration(minutes: offsetMinutes));

    return PrayerTime(
      name: name,
      time: adjusted,
      originalTime: original,
      ihtiyatMinutes: offsetMinutes,
    );
  }

  /// Format tanggal Hijriah: "dd MMMM yyyy H"
  /// Contoh: "12 Rajab 1447 H"
  String _formatHijriDate(DateTime date, int adjustment) {
    if (adjustment != 0) {
      final adjHijri = HijriCalendar.fromDate(
        date.add(Duration(days: adjustment)),
      );
      return '${adjHijri.hDay} ${adjHijri.longMonthName} ${adjHijri.hYear} H';
    }

    final hijri = HijriCalendar.fromDate(date);
    return '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} H';
  }
}
