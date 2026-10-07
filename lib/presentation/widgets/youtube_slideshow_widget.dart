import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/theme/islamic_colors.dart';
import '../../../../core/theme/islamic_typography.dart';

/// Widget pemutar video YouTube bergiliran (slideshow).
///
/// Menerima list [urls] berupa link YouTube biasa, lalu:
/// - Mengekstrak video ID secara otomatis
/// - Memutar video satu per satu berurutan
/// - Otomatis pindah ke video berikutnya saat selesai
/// - Menampilkan fallback jika tidak ada koneksi internet
class YoutubeSlideshowWidget extends StatefulWidget {
  final List<String> urls;

  const YoutubeSlideshowWidget({
    super.key,
    required this.urls,
  });

  @override
  State<YoutubeSlideshowWidget> createState() => _YoutubeSlideshowWidgetState();
}

class _YoutubeSlideshowWidgetState extends State<YoutubeSlideshowWidget> {
  late YoutubePlayerController _controller;

  // Index video yang sedang diputar
  int _currentIndex = 0;

  // List video ID hasil ekstraksi dari URL
  List<String> _videoIds = [];

  // Status error (misal tidak ada koneksi)
  bool _hasError = false;
  String _errorMessage = '';

  // Timer fallback — kalau video tidak mulai dalam 15 detik, skip ke berikutnya
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _videoIds = _extractVideoIds(widget.urls);

    if (_videoIds.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Tidak ada video ID yang valid.\nPeriksa kembali link YouTube di Pengaturan.';
      });
      return;
    }

    _initController(_videoIds[_currentIndex]);
  }

  @override
  void didUpdateWidget(YoutubeSlideshowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Kalau list URL berubah (misalnya diupdate dari settings),
    // reset dan mulai dari awal
    if (oldWidget.urls != widget.urls) {
      _videoIds = _extractVideoIds(widget.urls);
      _currentIndex = 0;
      _hasError = false;

      if (_videoIds.isNotEmpty) {
        _controller.loadVideoById(videoId: _videoIds[0]);
        _startFallbackTimer();
      }
    }
  }

  // ── Inisialisasi controller YouTube ────────────────────────────────
  void _initController(String videoId) {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: false,      // Sembunyikan kontrol (ini TV display)
        showFullscreenButton: false,
        mute: false,
        loop: false,              // Tidak loop, kita handle manual
        showVideoAnnotations: false,
        playsInline: true,
        strictRelatedVideos: true,
      ),
    );

    // Dengarkan perubahan state video
    _controller.listen(_onPlayerStateChange);

    // Mulai timer fallback
    _startFallbackTimer();
  }

  // ── Listener state perubahan video ─────────────────────────────────
  void _onPlayerStateChange(YoutubePlayerValue value) {
    // Kalau video sudah selesai → pindah ke berikutnya
    if (value.playerState == PlayerState.ended) {
      _cancelFallbackTimer();
      _playNext();
      return;
    }

    // Kalau sudah mulai bermain → cancel fallback timer
    if (value.playerState == PlayerState.playing) {
      _cancelFallbackTimer();
    }

    // Kalau error → tampilkan pesan dan coba video berikutnya
    if (value.error != null) {
      _cancelFallbackTimer();
      _handleVideoError();
    }
  }

  // ── Pindah ke video berikutnya ──────────────────────────────────────
  void _playNext() {
    if (_videoIds.isEmpty) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % _videoIds.length;
    });

    _controller.loadVideoById(videoId: _videoIds[_currentIndex]);
    _startFallbackTimer();
  }

  // ── Pindah ke video sebelumnya ──────────────────────────────────────
  void _playPrevious() {
    if (_videoIds.isEmpty) return;

    setState(() {
      _currentIndex =
          (_currentIndex - 1 + _videoIds.length) % _videoIds.length;
    });

    _controller.loadVideoById(videoId: _videoIds[_currentIndex]);
    _startFallbackTimer();
  }

  // ── Handle error video ──────────────────────────────────────────────
  void _handleVideoError() {
    // Kalau hanya 1 video dan error → tampilkan pesan
    if (_videoIds.length == 1) {
      setState(() {
        _hasError = true;
        _errorMessage =
            'Video tidak dapat diputar.\nPastikan TV terhubung ke internet\ndan link YouTube masih valid.';
      });
      return;
    }

    // Kalau lebih dari 1 video → skip ke berikutnya setelah 2 detik
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _playNext();
    });
  }

  // ── Fallback timer — skip kalau video tidak mulai ───────────────────
  void _startFallbackTimer() {
    _cancelFallbackTimer();
    _fallbackTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        // Kalau hanya 1 video → tampilkan error koneksi
        if (_videoIds.length == 1) {
          setState(() {
            _hasError = true;
            _errorMessage =
                'Koneksi internet bermasalah.\nVideo tidak dapat dimuat.';
          });
        } else {
          _playNext();
        }
      }
    });
  }

  void _cancelFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  // ── Ekstrak video ID dari berbagai format URL YouTube ───────────────
  List<String> _extractVideoIds(List<String> urls) {
    final List<String> ids = [];

    for (final url in urls) {
      final id = _extractSingleId(url.trim());
      if (id != null && id.isNotEmpty) {
        ids.add(id);
      }
    }

    return ids;
  }

  String? _extractSingleId(String url) {
    // Format: https://www.youtube.com/watch?v=VIDEO_ID
    // Format: https://youtu.be/VIDEO_ID
    // Format: https://www.youtube.com/embed/VIDEO_ID
    // Format: VIDEO_ID langsung (11 karakter)

    try {
      // Kalau langsung berupa ID (11 karakter alfanumerik + - _)
      if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(url)) {
        return url;
      }

      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      // youtu.be/VIDEO_ID
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }

      // youtube.com/watch?v=VIDEO_ID
      if (uri.host.contains('youtube.com')) {
        if (uri.queryParameters.containsKey('v')) {
          return uri.queryParameters['v'];
        }
        // youtube.com/embed/VIDEO_ID
        if (uri.pathSegments.contains('embed') &&
            uri.pathSegments.length >= 2) {
          return uri.pathSegments[uri.pathSegments.indexOf('embed') + 1];
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  @override
  void dispose() {
    _cancelFallbackTimer();
    _controller.close();
    super.dispose();
  }

  // ── BUILD ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Tampilan error / tidak ada koneksi
    if (_hasError) {
      return _buildErrorState();
    }

    return Stack(
      children: [
        // ── Player YouTube ──────────────────────────────────────────
        Positioned.fill(
          child: YoutubePlayer(
            controller: _controller,
            aspectRatio: 16 / 9,
          ),
        ),

        // ── Indikator video (pojok kanan bawah) ────────────────────
        if (_videoIds.length > 1)
          Positioned(
            bottom: 12.h,
            right: 12.w,
            child: _buildVideoIndicator(),
          ),

        // ── Tombol prev/next (muncul di tepi kiri/kanan) ───────────
        if (_videoIds.length > 1) ...[
          // Tombol Previous
          Positioned(
            left: 8.w,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: _playPrevious,
              ),
            ),
          ),
          // Tombol Next
          Positioned(
            right: 8.w,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: _playNext,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Indikator titik-titik video ke-N ───────────────────────────────
  Widget _buildVideoIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_videoIds.length, (i) {
          final isActive = i == _currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(horizontal: 3.w),
            width: isActive ? 20.w : 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: isActive
                  ? IslamicColors.goldAmber
                  : Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(4.r),
            ),
          );
        }),
      ),
    );
  }

  // ── Tombol navigasi prev/next ───────────────────────────────────────
  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: 0.0, // Tersembunyi, muncul saat di-tap layar
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 40.w,
          height: 80.h,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: Colors.white, size: 32.w),
        ),
      ),
    );
  }

  // ── Tampilan error ──────────────────────────────────────────────────
  Widget _buildErrorState() {
  return Container(
    decoration: BoxDecoration(
      color: IslamicColors.glassWhite,
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(color: IslamicColors.glassBorder, width: 1.w),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off_rounded,
            color: IslamicColors.textSecondary, size: 56.w),
        SizedBox(height: 16.h),
        Text(
          _errorMessage,
          textAlign: TextAlign.center,
          style: IslamicTypography.body(
            color: IslamicColors.textSecondary,
          ).copyWith(fontSize: 22.sp),
        ),
        SizedBox(height: 8.h),
        // ← TAMBAH INI: tampilkan detail error
        Text(
          'Video ID: ${_videoIds.isNotEmpty ? _videoIds[_currentIndex] : "kosong"}',
          textAlign: TextAlign.center,
          style: IslamicTypography.body(
            color: IslamicColors.goldAmber,
          ).copyWith(fontSize: 18.sp),
        ),
        SizedBox(height: 20.h),
        GestureDetector(
          onTap: () {
            setState(() {
              _hasError = false;
              _errorMessage = '';
            });
            _controller.loadVideoById(videoId: _videoIds[_currentIndex]);
            _startFallbackTimer();
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: IslamicColors.glassWhite,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: IslamicColors.glassBorder, width: 1.w),
            ),
            child: Text(
              'Coba Lagi',
              style: IslamicTypography.body(
                color: IslamicColors.goldAmber,
              ).copyWith(fontSize: 22.sp),
            ),
          ),
        ),
      ],
    ),
  );
}
