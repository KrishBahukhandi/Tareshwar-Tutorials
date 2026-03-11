// ─────────────────────────────────────────────────────────────
//  lecture_notes_screen.dart  –  PDF notes viewer + download
// ─────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────
class LectureNotesScreen extends StatefulWidget {
  final String notesUrl;
  final String lectureTitle;

  const LectureNotesScreen({
    super.key,
    required this.notesUrl,
    required this.lectureTitle,
  });

  @override
  State<LectureNotesScreen> createState() => _LectureNotesScreenState();
}

class _LectureNotesScreenState extends State<LectureNotesScreen> {
  // ── PDF state ─────────────────────────────────────────────
  String? _localPdfPath;
  bool _loading = true;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfController;

  // ── Download state ────────────────────────────────────────
  bool _downloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  // ── Download PDF to temp dir for viewing ─────────────────
  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = await getTemporaryDirectory();
      final fileName =
          'notes_${widget.notesUrl.hashCode.abs()}.pdf';
      final file = File('${dir.path}/$fileName');

      if (!file.existsSync()) {
        await Dio().download(widget.notesUrl, file.path,
            onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        });
      }

      if (mounted) {
        setState(() {
          _localPdfPath = file.path;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load PDF: $e';
          _loading = false;
        });
      }
    }
  }

  // ── Save PDF to Downloads folder ─────────────────────────
  Future<void> _downloadToSave() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!dir.existsSync()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final fileName =
          '${widget.lectureTitle.replaceAll(RegExp(r'[^\w]'), '_')}_notes.pdf';
      final savePath = '${dir!.path}/$fileName';

      await Dio().download(widget.notesUrl, savePath,
          onReceiveProgress: (received, total) {
        if (total > 0 && mounted) {
          setState(() => _downloadProgress = received / total);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $savePath'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lectureTitle,
              style: AppTextStyles.headlineSmall
                  .copyWith(color: Colors.white, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: AppTextStyles.caption
                    .copyWith(color: Colors.white60),
              ),
          ],
        ),
        actions: [
          // Download button
          _downloading
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      value: _downloadProgress > 0
                          ? _downloadProgress
                          : null,
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Download Notes',
                  onPressed: _downloadToSave,
                ),
        ],
      ),
      body: _buildBody(),
      // Page navigation FAB row
      bottomNavigationBar: _localPdfPath != null && _totalPages > 1
          ? _buildPageNav()
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value:
                  _downloadProgress > 0 ? _downloadProgress : null,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _downloadProgress > 0
                  ? 'Loading PDF… ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                  : 'Preparing notes…',
              style:
                  AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                onPressed: _loadPdf,
              ),
            ],
          ),
        ),
      );
    }

    return PDFView(
      filePath: _localPdfPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      nightMode: true,
      onRender: (pages) {
        if (mounted) setState(() => _totalPages = pages ?? 0);
      },
      onViewCreated: (controller) {
        _pdfController = controller;
      },
      onPageChanged: (page, _) {
        if (mounted) setState(() => _currentPage = page ?? 0);
      },
      onError: (e) {
        if (mounted) setState(() => _error = 'Render error: $e');
      },
    );
  }

  Widget _buildPageNav() {
    return Container(
      height: 56,
      color: const Color(0xFF1E1E1E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page_rounded, color: Colors.white70),
            onPressed: _currentPage > 0
                ? () => _pdfController?.setPage(0)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: Colors.white70),
            onPressed: _currentPage > 0
                ? () => _pdfController?.setPage(_currentPage - 1)
                : null,
          ),
          Text(
            '${_currentPage + 1} / $_totalPages',
            style:
                AppTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded,
                color: Colors.white70),
            onPressed: _currentPage < _totalPages - 1
                ? () => _pdfController?.setPage(_currentPage + 1)
                : null,
          ),
          IconButton(
            icon:
                const Icon(Icons.last_page_rounded, color: Colors.white70),
            onPressed: _currentPage < _totalPages - 1
                ? () => _pdfController?.setPage(_totalPages - 1)
                : null,
          ),
        ],
      ),
    );
  }
}
