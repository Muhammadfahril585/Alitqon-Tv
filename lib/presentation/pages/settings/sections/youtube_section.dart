import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/islamic_colors.dart';
import '../../../../core/theme/islamic_typography.dart';
import '../../../cubits/settings/settings_cubit.dart';
import '../../../cubits/settings/settings_state.dart';
import '../../../widgets/focusable_widget.dart';
import '../../../widgets/focusable_text_field.dart';

class YoutubeSection extends StatefulWidget {
  const YoutubeSection({super.key});

  @override
  State<YoutubeSection> createState() => _YoutubeSectionState();
}

class _YoutubeSectionState extends State<YoutubeSection> {
  final TextEditingController _inputController = TextEditingController();

  // List URL sementara di UI (belum tersimpan)
  List<String> _urls = [];

  // Apakah ada perubahan yang belum disimpan
  bool _isDirty = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // Tambah URL baru ke list
  void _addUrl() {
    final raw = _inputController.text.trim();
    if (raw.isEmpty) return;

    // Validasi sederhana — harus mengandung youtube atau youtu.be
    final isValid = raw.contains('youtube.com') ||
        raw.contains('youtu.be') ||
        RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(raw);

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Link tidak valid. Gunakan link YouTube yang benar.',
            style: IslamicTypography.body(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Cek duplikat
    if (_urls.contains(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Link ini sudah ada di daftar.',
            style: IslamicTypography.body(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _urls.add(raw);
      _isDirty = true;
      _inputController.clear();
    });
  }

  // Hapus URL dari list
  void _removeUrl(int index) {
    setState(() {
      _urls.removeAt(index);
      _isDirty = true;
    });
  }

  // Simpan ke cubit / database
  void _save(BuildContext context) {
    context.read<SettingsCubit>().updateYoutubeUrls(List.from(_urls));
    setState(() => _isDirty = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Daftar video berhasil disimpan.',
          style: IslamicTypography.body(color: IslamicColors.surfaceDark),
        ),
        backgroundColor: IslamicColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (prev, curr) =>
          prev is! SettingsLoaded && curr is SettingsLoaded,
      listener: (context, state) {
        // Isi list dari settings saat pertama load
        if (state is SettingsLoaded && !_isDirty) {
          setState(() {
            _urls = List.from(state.settings.youtubeUrls);
          });
        }
      },
      builder: (context, state) {
        if (state is! SettingsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        // Isi list dari settings jika masih kosong dan belum ada perubahan
        if (_urls.isEmpty && !_isDirty) {
          _urls = List.from(state.settings.youtubeUrls);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── JUDUL ───────────────────────────────────────────────
            Text('Video YouTube', style: IslamicTypography.heading()),
            SizedBox(height: 8.h),
            Text(
              'Tambahkan link YouTube yang akan diputar bergantian '
              'di layar utama saat belum masuk waktu sholat. '
              'Pastikan TV terhubung ke internet.',
              style: IslamicTypography.subtitle(
                color: IslamicColors.textSecondary,
              ),
            ),

            SizedBox(height: 32.h),

            // ── DAFTAR URL ───────────────────────────────────────────
            Text(
              'Daftar Video (${_urls.length})',
              style: IslamicTypography.title(),
            ),
            SizedBox(height: 12.h),

            if (_urls.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: IslamicColors.glassWhite,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: IslamicColors.glassBorder),
                ),
                child: Text(
                  'Belum ada video. Tambahkan link YouTube di bawah.',
                  textAlign: TextAlign.center,
                  style: IslamicTypography.body(
                    color: IslamicColors.textSecondary,
                  ),
                ),
              )
            else
              // List URL yang sudah ditambahkan
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _urls.length,
                separatorBuilder: (_, __) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: IslamicColors.glassWhite,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: IslamicColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        // Nomor urut
                        Container(
                          width: 32.w,
                          height: 32.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: IslamicColors.goldAmber.withValues(
                              alpha: 0.2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: IslamicTypography.body(
                              color: IslamicColors.goldAmber,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),

                        SizedBox(width: 12.w),

                        // URL text
                        Expanded(
                          child: Text(
                            _urls[index],
                            style: IslamicTypography.body(
                              color: IslamicColors.textPrimary,
                            ).copyWith(fontSize: 22.sp),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),

                        SizedBox(width: 12.w),

                        // Tombol hapus
                        FocusableWidget(
                          onSelect: () => _removeUrl(index),
                          builder: (isFocused) => AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? Colors.redAccent.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: isFocused
                                    ? Colors.redAccent
                                    : Colors.transparent,
                              ),
                            ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: isFocused
                                  ? Colors.redAccent
                                  : IslamicColors.textSecondary,
                              size: 28.w,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            SizedBox(height: 24.h),

            // ── INPUT TAMBAH URL ─────────────────────────────────────
            Text('Tambah Link YouTube', style: IslamicTypography.title()),
            SizedBox(height: 12.h),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Input field
                Expanded(
                  child: FocusableTextField(
                    controller: _inputController,
                    hintText: 'https://www.youtube.com/watch?v=...',
                    maxLines: 1,
                    minLines: 1,
                    onSubmitted: (_) => _addUrl(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                SizedBox(width: 12.w),

                // Tombol tambah
                FocusableWidget(
                  onSelect: _addUrl,
                  builder: (isFocused) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      color: IslamicColors.primaryTeal,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isFocused
                            ? IslamicColors.goldAmber
                            : IslamicColors.primaryTeal,
                        width: isFocused ? 2.0 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 24.w),
                        SizedBox(width: 6.w),
                        Text(
                          'Tambah',
                          style: IslamicTypography.body(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 32.h),

            // ── TOMBOL SIMPAN ────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: FocusableWidget(
                onSelect: () => _save(context),
                builder: (isFocused) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    horizontal: 32.w,
                    vertical: 14.h,
                  ),
                  decoration: BoxDecoration(
                    color: _isDirty
                        ? IslamicColors.primaryTeal
                        : IslamicColors.glassWhite,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isFocused
                          ? IslamicColors.goldAmber
                          : (_isDirty
                              ? IslamicColors.primaryTeal
                              : IslamicColors.glassBorder),
                      width: isFocused ? 2.0 : 1.0,
                    ),
                  ),
                  child: Text(
                    _isDirty ? 'Simpan Perubahan' : 'Tersimpan',
                    style: IslamicTypography.title(
                      color: _isDirty
                          ? Colors.white
                          : IslamicColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
