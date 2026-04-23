// Kalkulator Jadwal Shalat - Wahdah Calculator Raw
// Dikonversi dari TypeScript ke Dart
// Perhitungan waktu shalat astronomis tanpa library eksternal

import 'dart:math' as math;

// ==========================
// CONFIG
// ==========================

class PrayerConfig {
  final double fajrAngle;
  final double ishaAngle;
  final String mazhab; // 'shafi' | 'hanafi'
  final int ihtiyatFajr;
  final int ihtiyatDhuhr;
  final int ihtiyatAsr;
  final int ihtiyatMaghrib;
  final int ihtiyatIsha;

  const PrayerConfig({
    this.fajrAngle = 17.5,
    this.ishaAngle = 18.0,
    this.mazhab = 'shafi',
    this.ihtiyatFajr = 0,
    this.ihtiyatDhuhr = 4,
    this.ihtiyatAsr = 0,
    this.ihtiyatMaghrib = 2,
    this.ihtiyatIsha = 0,
  });

  PrayerConfig copyWith({
    double? fajrAngle,
    double? ishaAngle,
    String? mazhab,
    int? ihtiyatFajr,
    int? ihtiyatDhuhr,
    int? ihtiyatAsr,
    int? ihtiyatMaghrib,
    int? ihtiyatIsha,
  }) {
    return PrayerConfig(
      fajrAngle: fajrAngle ?? this.fajrAngle,
      ishaAngle: ishaAngle ?? this.ishaAngle,
      mazhab: mazhab ?? this.mazhab,
      ihtiyatFajr: ihtiyatFajr ?? this.ihtiyatFajr,
      ihtiyatDhuhr: ihtiyatDhuhr ?? this.ihtiyatDhuhr,
      ihtiyatAsr: ihtiyatAsr ?? this.ihtiyatAsr,
      ihtiyatMaghrib: ihtiyatMaghrib ?? this.ihtiyatMaghrib,
      ihtiyatIsha: ihtiyatIsha ?? this.ihtiyatIsha,
    );
  }
}

// ==========================
// HASIL WAKTU SHALAT
// ==========================

class WahdahPrayerTimes {
  final DateTime imsak;
  final DateTime fajr;
  final DateTime duha;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  const WahdahPrayerTimes({
    required this.imsak,
    required this.fajr,
    required this.duha,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });
}

// ==========================
// TIMEZONE HELPER
// ==========================

/// Tentukan offset timezone (jam) dari koordinat
/// WIB = 7, WITA = 8, WIT = 9
int getTimezoneOffsetFromCoords(double latitude, double longitude) {
  // Sulawesi (WITA)
  if (longitude >= 118 && longitude <= 126 && latitude >= -7 && latitude <= 3) {
    return 8;
  }
  // Bali, NTB, NTT (WITA)
  if (longitude >= 114 && longitude <= 125 && latitude >= -12 && latitude <= -6) {
    return 8;
  }
  // Kalimantan Timur/Tengah/Selatan (WITA)
  if (longitude >= 114 && longitude < 118 && latitude >= -4 && latitude <= 4) {
    return 8;
  }
  // Maluku (WIT)
  if (longitude >= 125 && longitude < 132 && latitude >= -9 && latitude <= 2) {
    return 9;
  }
  // Papua (WIT)
  if (longitude >= 130) {
    return 9;
  }
  // WIB (default Sumatera, Jawa, Kalbar)
  if (longitude < 114) {
    return 7;
  }
  // Sisanya WITA
  return 8;
}

String getTimezoneLabel(int offset) {
  switch (offset) {
    case 7: return 'WIB';
    case 8: return 'WITA';
    case 9: return 'WIT';
    default: return 'WIB';
  }
}

// ==========================
// KALKULATOR UTAMA
// ==========================

class WahdahCalculator {
  static const double _deg2rad = math.pi / 180.0;
  static const double _rad2deg = 180.0 / math.pi;

  // ==========================
  // MAIN API
  // ==========================

  /// Hitung waktu shalat untuk koordinat dan tanggal tertentu
  /// [timezoneOffset] = offset jam dari UTC, misal 8 untuk WITA
  static WahdahPrayerTimes calculate({
    required double latitude,
    required double longitude,
    required int timezoneOffset,
    required DateTime date,
    PrayerConfig config = const PrayerConfig(),
  }) {
    // Normalisasi ke jam 00:00:00
    final localDate = DateTime(date.year, date.month, date.day);

    // 1. Hitung waktu astronomi
    final astroTimes = _calculateAstronomicalTimes(
      latitude, longitude, localDate, timezoneOffset, config,
    );

    // 2. Terapkan Ihtiyat
    final ihtiyatApplied = _applyIhtiyat(astroTimes, config);

    // 3. Hitung Imsak & Duha
    final rawImsak = _shiftTime(ihtiyatApplied['fajr']!, -10);
    final rawDuha = _shiftTime(ihtiyatApplied['sunrise']!, 15);

    // 4. Bulatkan ke atas (ceil minute)
    return WahdahPrayerTimes(
      imsak: _ceilMinute(rawImsak),
      fajr: _ceilMinute(ihtiyatApplied['fajr']!),
      duha: _ceilMinute(rawDuha),
      sunrise: _ceilMinute(ihtiyatApplied['sunrise']!),
      dhuhr: _ceilMinute(ihtiyatApplied['dhuhr']!),
      asr: _ceilMinute(ihtiyatApplied['asr']!),
      maghrib: _ceilMinute(ihtiyatApplied['maghrib']!),
      isha: _ceilMinute(ihtiyatApplied['isha']!),
    );
  }

  // ==========================
  // CORE ASTRONOMY
  // ==========================

  static Map<String, DateTime> _calculateAstronomicalTimes(
    double lat,
    double lon,
    DateTime date,
    int tzOffset,
    PrayerConfig config,
  ) {
    final t = (_getJulianDay(date) - 2451545) / 36525;

    final solarDecl = _getSolarDeclination(t);
    final eqTime = _getEquationOfTime(t);

    final latRad = lat * _deg2rad;
    final decRad = solarDecl * _deg2rad;

    final transit = 12 - lon / 15 - eqTime / 60;

    final fajrAngle = -config.fajrAngle;
    final ishaAngle = -config.ishaAngle;

    final rawTimes = {
      'transit': transit,
      'sunrise': _calcPrayerTime(latRad, decRad, -0.833, transit, false),
      'sunset': _calcPrayerTime(latRad, decRad, -0.833, transit, true),
      'fajr': _calcPrayerTime(latRad, decRad, fajrAngle, transit, false),
      'isha': _calcPrayerTime(latRad, decRad, ishaAngle, transit, true),
      'asr': _calcAsrTime(latRad, decRad, transit, config.mazhab),
    };

    // Shift ke timezone lokal
    final shifted = <String, double>{};
    for (final k in rawTimes.keys) {
      shifted[k] = rawTimes[k]! + tzOffset;
    }

    return {
      'fajr': _timeToDate(date, shifted['fajr']!),
      'sunrise': _timeToDate(date, shifted['sunrise']!),
      'dhuhr': _timeToDate(date, shifted['transit']!),
      'asr': _timeToDate(date, shifted['asr']!),
      'maghrib': _timeToDate(date, shifted['sunset']!),
      'isha': _timeToDate(date, shifted['isha']!),
    };
  }

  // ==========================
  // IHTIYAT
  // ==========================

  static Map<String, DateTime> _applyIhtiyat(
    Map<String, DateTime> times,
    PrayerConfig config,
  ) {
    return {
      'fajr': _shiftTime(times['fajr']!, config.ihtiyatFajr),
      'sunrise': times['sunrise']!,
      'dhuhr': _shiftTime(times['dhuhr']!, config.ihtiyatDhuhr),
      'asr': _shiftTime(times['asr']!, config.ihtiyatAsr),
      'maghrib': _shiftTime(times['maghrib']!, config.ihtiyatMaghrib),
      'isha': _shiftTime(times['isha']!, config.ihtiyatIsha),
    };
  }

  // ==========================
  // ROUNDING
  // ==========================

  static DateTime _ceilMinute(DateTime t) {
    if (t.second > 0 || t.millisecond > 0 || t.microsecond > 0) {
      return DateTime(t.year, t.month, t.day, t.hour, t.minute)
          .add(const Duration(minutes: 1));
    }
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }

  // ==========================
  // RUMUS ASTRONOMI
  // ==========================

  static int _getJulianDay(DateTime date) {
    final y = date.year;
    final m = date.month;
    final d = date.day;

    final r = ((14 - m) / 12).floor();
    final h = y - r;

    return d +
        ((153 * (m + 12 * r - 3) + 2) / 5).floor() +
        365 * h +
        (h / 4).floor() -
        (h / 100).floor() +
        (h / 400).floor() +
        1721119;
  }

  static double _getSolarDeclination(double t) {
    final M = 357.52911 + t * (35999.05029 - 0.0001537 * t);

    final C = (1.914602 - t * (0.004817 + 0.000014 * t)) *
            math.sin(M * _deg2rad) +
        (0.019993 - 0.000101 * t) * math.sin(2 * M * _deg2rad) +
        0.000289 * math.sin(3 * M * _deg2rad);

    final L = (280.46646 + t * (36000.76983 + 0.0003032 * t) + C) % 360;

    final e = 23.4392911 -
        0.0130042 * t -
        0.00000016 * t * t +
        0.000000504 * t * t * t;

    return math.asin(
          math.sin(e * _deg2rad) * math.sin(L * _deg2rad),
        ) *
        _rad2deg;
  }

  static double _getEquationOfTime(double t) {
    final L0 =
        (280.46646 + t * (36000.76983 + 0.0003032 * t)) * _deg2rad;
    final M =
        (357.52911 + t * (35999.05029 - 0.0001537 * t)) * _deg2rad;
    final e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    final obliquity = (23.4392911 - 0.0130042 * t) * _deg2rad;
    final y = math.pow(math.tan(obliquity / 2), 2).toDouble();

    final eq = y * math.sin(2 * L0) -
        2 * e * math.sin(M) +
        4 * e * y * math.sin(M) * math.cos(2 * L0) -
        0.5 * y * y * math.sin(4 * L0) -
        1.25 * e * e * math.sin(2 * M);

    return eq * _rad2deg * 4;
  }

  static double _calcPrayerTime(
    double lat,
    double dec,
    double angle,
    double transit,
    bool isAfterNoon,
  ) {
    final cosH =
        (math.sin(angle * _deg2rad) - math.sin(lat) * math.sin(dec)) /
            (math.cos(lat) * math.cos(dec));

    if (cosH.abs() > 1) {
      return isAfterNoon ? transit + 1.5 : transit - 1.5;
    }

    final H = (math.acos(cosH) * _rad2deg) / 15;
    return isAfterNoon ? transit + H : transit - H;
  }

  static double _calcAsrTime(
    double lat,
    double dec,
    double transit,
    String mazhab,
  ) {
    final factor = mazhab == 'hanafi' ? 2 : 1;

    final cosH = (math.sin(
              math.atan(1 / (factor + math.tan((lat - dec).abs()))),
            ) -
            math.sin(lat) * math.sin(dec)) /
        (math.cos(lat) * math.cos(dec));

    if (cosH.abs() > 1) return transit + 3;

    return transit + (math.acos(cosH) * _rad2deg) / 15;
  }

  // ==========================
  // DATE HELPERS
  // ==========================

  static DateTime _timeToDate(DateTime date, double timeDecimal) {
    final t = ((timeDecimal % 24) + 24) % 24;
    final hour = t.floor();
    final minuteDecimal = (t - hour) * 60;
    final minute = minuteDecimal.floor();
    final second = ((minuteDecimal - minute) * 60 + 0.5).floor();

    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  static DateTime _shiftTime(DateTime date, int minutes) {
    return date.add(Duration(minutes: minutes));
  }
}
