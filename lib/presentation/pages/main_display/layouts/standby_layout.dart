import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/islamic_colors.dart';
import '../../../../core/theme/islamic_typography.dart';
import '../../../../domain/entities/display_state.dart';
import '../../../../domain/entities/settings.dart';
import '../../../cubits/settings/settings_cubit.dart';
import '../../../cubits/settings/settings_state.dart';
import '../../../widgets/digital_clock_widget.dart';
import '../../../widgets/glassmorphism_card.dart';
import '../../../widgets/header_widget.dart';
import '../../../widgets/prayer_cards_row.dart';
import '../../../widgets/running_text_widget.dart';
import '../../../widgets/treasury_info_widget.dart';
import '../../../widgets/youtube_slideshow_widget.dart'; // ← BARU (Step 3)

class StandbyLayout extends StatelessWidget {
  final StandbyState state;
  final bool isSettingsVisible;

  const StandbyLayout({
    super.key,
    required this.state,
    this.isSettingsVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        String mosqueName = 'Masjid Anda';
        String mosqueAddress = '';
        String? runningText = state.runningText;
        List<String> youtubeUrls = [];

        if (settingsState is SettingsLoaded) {
          final s = settingsState.settings;
          if (s.mosqueName.isNotEmpty) mosqueName = s.mosqueName;
          mosqueAddress = s.mosqueAddress;
          runningText ??= s.runningText;
          youtubeUrls = s.youtubeUrls; // ← BARU (Step 4)
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── HEADER ──────────────────────────────────────────────
            HeaderWidget(
              mosqueName: mosqueName,
              mosqueAddress: mosqueAddress,
              hijriDate: state.hijriDate ?? '',
              currentTime: state.currentTime,
              isSettingsVisible: isSettingsVisible,
            ),

            SizedBox(height: 16.h),

            // ── BODY ─────────────────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── KIRI: Jam + Info Sholat (compact) ──────────────
                  SizedBox(
                    width: 340.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Jam digital — FittedBox menyesuaikan ukuran kolom kiri
                        RepaintBoundary(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: DigitalClockWidget(),
                          ),
                        ),

                        SizedBox(height: 12.h),

                        // Info sholat berikutnya — DIPERKECIL
                        _buildCompactInfoPanel(
                          settingsState is SettingsLoaded
                              ? settingsState.settings
                              : null,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 16.w),

                  // ── KANAN: YouTube Slideshow ────────────────────────
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20.r),
                      child: youtubeUrls.isNotEmpty
                          ? YoutubeSlideshowWidget(
                              urls: youtubeUrls,
                            )
                          : _buildVideoPlaceholder(),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // ── PRAYER CARDS ─────────────────────────────────────────
            if (state.dailyPrayerTimes != null)
              PrayerCardsRow(
                prayers: state.dailyPrayerTimes!.allPrayers,
                nextPrayer: state.nextPrayer,
              ),

            SizedBox(height: 16.h),

            // ── RUNNING TEXT ─────────────────────────────────────────
            _StandbyRunningTextFooter(runningText: runningText),
          ],
        );
      },
    );
  }

  // ── Info panel DIPERKECIL ─────────────────────────────────────────
  Widget _buildCompactInfoPanel(Settings? settings) {
    if (state.nextPrayer == null || state.timeToNextPrayer == null) {
      return const SizedBox.shrink();
    }

    final duration = state.timeToNextPrayer!;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    final String timeRemainingStr = hours > 0
        ? '$hours j $minutes mnt'
        : '$minutes menit lagi';

    return GlassmorphismCard(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label atas
          Text(
            'Sholat Berikutnya',
            style: IslamicTypography.subtitle(
              color: IslamicColors.textSecondary,
            ).copyWith(fontSize: 20.sp),
          ),

          SizedBox(height: 6.h),

          // Nama sholat
          Text(
            state.nextPrayer!.name,
            style: IslamicTypography.heading(
              color: IslamicColors.goldAmber,
              fontWeight: FontWeight.bold,
            ).copyWith(fontSize: 46.sp),
          ),

          SizedBox(height: 4.h),

          // Waktu masuk
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                color: IslamicColors.textPrimary,
                size: 18.w,
              ),
              SizedBox(width: 6.w),
              Text(
                state.nextPrayer!.formattedTime,
                style: IslamicTypography.body(
                  color: IslamicColors.textPrimary,
                ).copyWith(fontSize: 22.sp),
              ),
            ],
          ),

          SizedBox(height: 4.h),

          // Countdown
          Text(
            timeRemainingStr,
            style: IslamicTypography.body(
              color: IslamicColors.textSecondary,
            ).copyWith(fontSize: 18.sp),
          ),

          // Treasury (kalau aktif) — tetap di sini tapi lebih ringkas
          if (settings != null && settings.isTreasuryEnabled) ...[
            SizedBox(height: 10.h),
            Divider(color: IslamicColors.glassBorder, thickness: 0.5),
            SizedBox(height: 6.h),
            TreasuryInfoWidget(
              balance: settings.treasuryBalance,
              income: settings.treasuryIncome,
              expense: settings.treasuryExpense,
            ),
          ],
        ],
      ),
    );
  }

  // ── Placeholder saat belum ada URL YouTube ────────────────────────
  Widget _buildVideoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: IslamicColors.glassWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: IslamicColors.glassBorder,
          width: 1.w,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            color: IslamicColors.textSecondary,
            size: 64.w,
          ),
          SizedBox(height: 16.h),
          Text(
            'Belum ada video',
            style: IslamicTypography.subtitle(
              color: IslamicColors.textSecondary,
            ).copyWith(fontSize: 28.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Tambahkan link YouTube\ndi menu Pengaturan',
            textAlign: TextAlign.center,
            style: IslamicTypography.body(
              color: IslamicColors.textSecondary,
            ).copyWith(fontSize: 22.sp),
          ),
        ],
      ),
    );
  }
}

// ── Running Text Footer (tidak diubah) ───────────────────────────────
class _StandbyRunningTextFooter extends StatelessWidget {
  final String? runningText;

  const _StandbyRunningTextFooter({required this.runningText});

  @override
  Widget build(BuildContext context) {
    if (runningText == null || runningText!.isEmpty) {
      return SizedBox(height: 60.h);
    }

    return RepaintBoundary(
      child: SizedBox(
        height: 60.h,
        child: Container(
          decoration: BoxDecoration(
            color: IslamicColors.glassWhite,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: IslamicColors.glassBorder,
              width: 1.w,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Center(
            child: RunningTextWidget(
              text: runningText!,
              showBackground: false,
              textStyle: IslamicTypography.body().copyWith(
                color: IslamicColors.goldAmber,
                fontSize: 28.sp,
              ),
              scrollSpeed: 30.0,
            ),
          ),
        ),
      ),
    );
  }
}
