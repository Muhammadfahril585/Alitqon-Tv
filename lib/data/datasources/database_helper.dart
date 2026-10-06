import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton class yang mengelola lifecycle database SQLite.
///
/// Bertanggung jawab atas:
/// - Inisialisasi database (open/create)
/// - Schema DDL (table creation)
/// - Default data insertion
/// - Cities seed data
/// - Migration antar versi
///
/// Gunakan [DatabaseHelper().database] untuk mendapatkan instance database.
class DatabaseHelper {
  /// Nama file database di internal storage.
  static const String _databaseName = 'miqotul_khoir.db';

  /// Versi database saat ini. Increment untuk setiap schema change.
  static const int _databaseVersion = 10;
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static DatabaseHelper? _instance;
  static Database? _database;

  /// Factory constructor yang mengembalikan singleton instance.
  factory DatabaseHelper() => _instance ??= DatabaseHelper._internal();

  DatabaseHelper._internal();

  // ---------------------------------------------------------------------------
  // Database Access
  // ---------------------------------------------------------------------------

  /// Lazy-initialized database getter.
  ///
  /// Membuka database jika belum ada, atau mengembalikan instance
  /// yang sudah ada.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Inisialisasi database: menentukan path dan membuka koneksi.
  ///
  /// Database disimpan di internal storage sesuai [SEC-001].
  /// Callback [_onCreate] dipanggil saat database pertama kali dibuat.
  /// Callback [_onUpgrade] dipanggil saat versi berubah.
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Reset pengaturan ke default pabrik (menghapus tabel settings dan
  /// mengisi ulang nilainya).
  ///
  /// Berguna untuk action Factory Reset / Kembali ke Pengaturan Awal.
  Future<void> resetSettings() async {
    final db = await database;
    // Hapus state lama (langsung di instance Database, tanpa transation
    // karena init _insertDefaultSettings juga tidak pake transaction)
    await db.delete('settings');
    // Setel ulang konfigurasi pabrik (is_first_run=1, dll)
    await _insertDefaultSettings(db);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle Callbacks
  // ---------------------------------------------------------------------------

  /// Dipanggil saat database pertama kali dibuat.
  ///
  /// Urutan eksekusi:
  /// 1. Buat semua tables (schema DDL)
  /// 2. Insert default settings row
  /// 3. Seed cities data dari JSON asset
  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    // Seed cities terlebih dahulu agar elevation bisa di-lookup saat
    // insert default settings
    await _seedCities(db);
    await _insertDefaultSettings(db);
  }

  /// Dipanggil saat database version berubah (migration).
  ///
  /// Menggunakan pattern `if (oldVersion < N)` untuk setiap increment,
  /// memastikan migration berjalan berurutan dari versi lama ke baru.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE settings ADD COLUMN province_name TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE settings ADD COLUMN elevation INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE cities ADD COLUMN elevation INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      // Isi data elevasi cities dari JSON (untuk user yang upgrade dari v2/v3
      // sebelum migration ini ada, atau fresh dari v3 tanpa data elevasi)
      await _updateCitiesElevationFromJson(db);
      // Sync settings.elevation dari kota yang sudah dipilih
      await _syncSettingsElevationFromCity(db);
    }
    if (oldVersion < 5) {
      // Tambah kolom Iqomah Jum'at dan durasi Sholat Jum'at (CON-001)
      await db.execute(
        'ALTER TABLE settings ADD COLUMN iqomah_jumat INTEGER NOT NULL DEFAULT 10',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN sholat_jumat_duration_minutes INTEGER NOT NULL DEFAULT 45',
      );
    }
    if (oldVersion < 6) {
      // Tambah kolom Informasi Kas Masjid (fitur opsional)
      await db.execute(
        'ALTER TABLE settings ADD COLUMN is_treasury_enabled INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN treasury_balance INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN treasury_income INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN treasury_expense INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 7) {
      // Tambah kolom Kata Mutiara Islam (fitur opsional, default OFF)
      await db.execute(
        'ALTER TABLE settings ADD COLUMN is_wisdom_enabled INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN wisdom_interval_minutes INTEGER NOT NULL DEFAULT 15',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN wisdom_duration_minutes INTEGER NOT NULL DEFAULT 3',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN wisdom_start_hour INTEGER NOT NULL DEFAULT 6',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN wisdom_start_minute INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN wisdom_end_hour INTEGER NOT NULL DEFAULT 21',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN wisdom_end_minute INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE settings ADD COLUMN wisdom_selected_ids TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN wisdom_shuffle INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 8) {
      // Tambah kolom Mode Hemat Daya Tengah Malam (fitur opsional, default OFF)
      await db.execute(
        'ALTER TABLE settings ADD COLUMN is_midnight_mode_enabled INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN midnight_start_hour INTEGER NOT NULL DEFAULT 23',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN midnight_start_minute INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN midnight_end_hour INTEGER NOT NULL DEFAULT 3',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN midnight_end_minute INTEGER NOT NULL DEFAULT 30',
      );
    }
    if (oldVersion < 9) {
      // Tambah kolom Alarm Tanda Waktu (fitur opsional, default OFF)
      await db.execute(
        'ALTER TABLE settings ADD COLUMN is_pre_adzan_alert_enabled INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN is_pre_iqomah_alert_enabled INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN pre_adzan_alert_seconds INTEGER NOT NULL DEFAULT 10',
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN pre_iqomah_alert_seconds INTEGER NOT NULL DEFAULT 10',
      );
    }
    if (oldVersion < 10) {
      // Tambah kolom YouTube Slideshow URLs (fitur opsional, default kosong)
      await db.execute(
        "ALTER TABLE settings ADD COLUMN youtube_urls TEXT NOT NULL DEFAULT '[]'",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Migration Helpers
  // ---------------------------------------------------------------------------

  /// [Migration v3] Update semua baris tabel `cities` dengan data elevasi
  /// dari `assets/data/cities.json`.
  ///
  /// Menggunakan batch update dengan WHERE province_name + city_name
  /// sebagai key agar akurat meski ada nama kota yang sama di provinsi berbeda.
  Future<void> _updateCitiesElevationFromJson(Database db) async {
    final jsonString = await rootBundle.loadString('assets/data/cities.json');
    final List<dynamic> cities = json.decode(jsonString) as List<dynamic>;

    final batch = db.batch();
    for (final city in cities) {
      final elevation = (city['elevation'] as num?)?.toInt() ?? 0;
      batch.update(
        'cities',
        {'elevation': elevation},
        where: 'province_name = ? AND city_name = ?',
        whereArgs: [
          city['province_name'] as String,
          city['city_name'] as String,
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  /// [Migration v3] Sync kolom `elevation` di tabel `settings` dari kota
  /// yang sudah dipilih user.
  ///
  /// Query kota berdasarkan `city_name` di settings, lalu update
  /// `settings.elevation` jika ditemukan nilai > 0.
  /// Tidak melakukan apa-apa jika city_name kosong (fresh install).
  Future<void> _syncSettingsElevationFromCity(Database db) async {
    final settingsRows = await db.query('settings', limit: 1);
    if (settingsRows.isEmpty) return;

    final cityName = settingsRows.first['city_name'] as String? ?? '';
    if (cityName.isEmpty) return;

    final cityRows = await db.query(
      'cities',
      columns: ['elevation'],
      where: 'city_name = ?',
      whereArgs: [cityName],
      limit: 1,
    );

    if (cityRows.isEmpty) return;

    final elevation = (cityRows.first['elevation'] as int?) ?? 0;
    if (elevation > 0) {
      await db.update(
        'settings',
        {'elevation': elevation},
        where: 'id = ?',
        whereArgs: [settingsRows.first['id']],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Schema DDL
  // ---------------------------------------------------------------------------

  /// Membuat semua tables sesuai SPEC-01 §4.1.
  ///
  /// Tables:
  /// - `settings` — Singleton row (CHECK id = 1) dengan 30+ columns
  /// - `cities` — Lookup table kota/kabupaten Indonesia
  ///
  /// Indexes:
  /// - `idx_cities_province` — Untuk query by province
  /// - `idx_cities_name` — Untuk search by city name
  @visibleForTesting
  Future<void> createTablesForTesting(Database db) => _createTables(db);

  @visibleForTesting
  Future<void> insertDefaultSettingsForTesting(Database db) =>
      _insertDefaultSettings(db);

  Future<void> _createTables(Database db) async {
    // -- Table: settings (singleton row) --
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        is_first_run INTEGER NOT NULL DEFAULT 1,

        -- Identity
        mosque_name TEXT NOT NULL DEFAULT '',
        mosque_address TEXT NOT NULL DEFAULT '',

        -- Location
        city_name TEXT NOT NULL DEFAULT '',
        province_name TEXT NOT NULL DEFAULT '',
        latitude REAL NOT NULL DEFAULT -6.9175,
        longitude REAL NOT NULL DEFAULT 107.6191,
        timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',

        -- Calculation Method
        calculation_method TEXT NOT NULL DEFAULT 'kemenag',

        -- Time Corrections / Ihtiyat (Minutes)
        offset_subuh INTEGER NOT NULL DEFAULT 0,
        offset_syuruq INTEGER NOT NULL DEFAULT 0,
        offset_dhuha INTEGER NOT NULL DEFAULT 0,
        offset_dzuhur INTEGER NOT NULL DEFAULT 0,
        offset_ashar INTEGER NOT NULL DEFAULT 0,
        offset_maghrib INTEGER NOT NULL DEFAULT 0,
        offset_isya INTEGER NOT NULL DEFAULT 0,

        -- Dhuha offset from Syuruq (Minutes)
        dhuha_offset_minutes INTEGER NOT NULL DEFAULT 20,

        -- Hijri Date Adjustment (Days)
        hijri_adjustment INTEGER NOT NULL DEFAULT 0,

        -- Iqomah Delays (Minutes)
        iqomah_subuh INTEGER NOT NULL DEFAULT 10,
        iqomah_dzuhur INTEGER NOT NULL DEFAULT 10,
        iqomah_ashar INTEGER NOT NULL DEFAULT 10,
        iqomah_maghrib INTEGER NOT NULL DEFAULT 7,
        iqomah_isya INTEGER NOT NULL DEFAULT 10,

        -- Iqomah Jum'at (Minutes) — berlaku khusus hari Jumat, setelah khutbah
        iqomah_jumat INTEGER NOT NULL DEFAULT 10,

        -- Pre-Adzan Countdown (Minutes before adzan)
        pre_adzan_minutes INTEGER NOT NULL DEFAULT 10,

        -- Sholat Duration (Minutes)
        sholat_duration_minutes INTEGER NOT NULL DEFAULT 15,

        -- Sholat Jum'at Duration (Minutes) — mencakup khutbah + sholat 2 rakaat
        sholat_jumat_duration_minutes INTEGER NOT NULL DEFAULT 45,

        -- Informasi Kas Masjid (fitur opsional, default OFF)
        is_treasury_enabled INTEGER NOT NULL DEFAULT 0,
        treasury_balance INTEGER NOT NULL DEFAULT 0,
        treasury_income INTEGER NOT NULL DEFAULT 0,
        treasury_expense INTEGER NOT NULL DEFAULT 0,

        -- Kata Mutiara Islam (fitur opsional, default OFF)
        is_wisdom_enabled INTEGER NOT NULL DEFAULT 0,
        wisdom_interval_minutes INTEGER NOT NULL DEFAULT 15,
        wisdom_duration_minutes INTEGER NOT NULL DEFAULT 3,
        wisdom_start_hour INTEGER NOT NULL DEFAULT 6,
        wisdom_start_minute INTEGER NOT NULL DEFAULT 0,
        wisdom_end_hour INTEGER NOT NULL DEFAULT 21,
        wisdom_end_minute INTEGER NOT NULL DEFAULT 0,
        wisdom_selected_ids TEXT NOT NULL DEFAULT '[]',
        wisdom_shuffle INTEGER NOT NULL DEFAULT 0,

        -- Mode Hemat Daya Tengah Malam (fitur opsional, default OFF)
        is_midnight_mode_enabled INTEGER NOT NULL DEFAULT 0,
        midnight_start_hour INTEGER NOT NULL DEFAULT 23,
        midnight_start_minute INTEGER NOT NULL DEFAULT 0,
        midnight_end_hour INTEGER NOT NULL DEFAULT 3,
        midnight_end_minute INTEGER NOT NULL DEFAULT 30,

        -- Alarm Tanda Waktu (fitur opsional, default OFF)
        is_pre_adzan_alert_enabled INTEGER NOT NULL DEFAULT 0,
        is_pre_iqomah_alert_enabled INTEGER NOT NULL DEFAULT 0,
        pre_adzan_alert_seconds INTEGER NOT NULL DEFAULT 10,
        pre_iqomah_alert_seconds INTEGER NOT NULL DEFAULT 10,
        
        -- YouTube Slideshow (fitur opsional, default kosong)
        youtube_urls TEXT NOT NULL DEFAULT '[]',

        -- Adzan Duration (Seconds)
        adzan_duration_seconds INTEGER NOT NULL DEFAULT 180,

        -- Display
        running_text TEXT NOT NULL DEFAULT 'Selamat datang di masjid kami',

        -- PIN Protection (empty = disabled)
        settings_pin_hash TEXT NOT NULL DEFAULT '',

        -- Timestamps
        created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),

        -- Elevation (meter DPL)
        elevation INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // -- Table: cities (lookup for Setup Wizard city picker) --
    await db.execute('''
      CREATE TABLE cities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        province_name TEXT NOT NULL,
        city_name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        elevation INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // -- Indexes untuk query performance --
    await db.execute(
      'CREATE INDEX idx_cities_province ON cities(province_name)',
    );
    await db.execute('CREATE INDEX idx_cities_name ON cities(city_name)');
  }

  /// Insert default settings row (singleton, id = 1).
  ///
  /// Melakukan lookup elevasi dari tabel `cities` berdasarkan koordinat default
  /// (Bandung: -6.9175, 107.6191) agar fresh install langsung punya DPL
  /// correction yang benar tanpa perlu masuk Setup Wizard.
  ///
  /// Jika kota tidak ditemukan (misal test environment), fallback ke elevation = 0.
  Future<void> _insertDefaultSettings(Database db) async {
    // Lookup elevasi default dari cities table (sudah di-seed sebelumnya)
    const defaultLat = -6.9175;
    const defaultLng = 107.6191;

    int defaultElevation = 0;
    final cityRows = await db.query(
      'cities',
      columns: ['elevation'],
      where: 'ABS(latitude - ?) < 0.01 AND ABS(longitude - ?) < 0.01',
      whereArgs: [defaultLat, defaultLng],
      orderBy: 'ABS(latitude - $defaultLat) + ABS(longitude - $defaultLng)',
      limit: 1,
    );
    if (cityRows.isNotEmpty) {
      defaultElevation = (cityRows.first['elevation'] as int?) ?? 0;
    }

    await db.insert('settings', {'id': 1, 'elevation': defaultElevation});
  }

  // ---------------------------------------------------------------------------
  // Seed Data
  // ---------------------------------------------------------------------------

  /// Seed cities/kabupaten data dari JSON asset.
  ///
  /// Membaca `assets/data/cities.json` dan insert semua entries
  /// menggunakan batch operations untuk performa optimal [GUD-001].
  ///
  /// Dataset berisi 514 kota/kabupaten di 34 provinsi Indonesia
  /// dengan koordinat latitude/longitude [REQ-008].
  Future<void> _seedCities(Database db) async {
    final jsonString = await rootBundle.loadString('assets/data/cities.json');
    final List<dynamic> citiesList = json.decode(jsonString) as List<dynamic>;

    final batch = db.batch();
    for (final city in citiesList) {
      batch.insert('cities', {
        'province_name': city['province_name'] as String,
        'city_name': city['city_name'] as String,
        'latitude': city['latitude'] as num,
        'longitude': city['longitude'] as num,
        'elevation': (city['elevation'] as num?) ?? 0,
      });
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Menutup koneksi database dan reset singleton state.
  ///
  /// Panggil method ini saat app dispose atau saat testing teardown.
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }

  // ---------------------------------------------------------------------------
  // Testing Support
  // ---------------------------------------------------------------------------

  /// Inject database instance yang sudah dibuat dari luar (untuk testing).
  ///
  /// Memungkinkan test menggunakan in-memory database tanpa menyentuh
  /// file system. Hanya boleh dipanggil dari test code.
  ///
  /// Contoh penggunaan:
  /// ```dart
  /// final db = await databaseFactoryFfi.openDatabase(
  ///   inMemoryDatabasePath,
  ///   options: OpenDatabaseOptions(version: 1, onCreate: ...),
  /// );
  /// DatabaseHelper().initForTesting(db);
  /// ```
  @visibleForTesting
  void initForTesting(Database db) {
    _database = db;
  }

  /// Reset singleton state untuk test isolation.
  ///
  /// Panggil di `tearDown()` setelah setiap test agar test berikutnya
  /// mendapat fresh instance.
  @visibleForTesting
  void resetForTesting() {
    _database = null;
    _instance = null;
  }
}
