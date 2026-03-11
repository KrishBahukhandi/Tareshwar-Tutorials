// ─────────────────────────────────────────────────────────────
//  lecture_upload_form.dart
//  Reusable form for uploading a Lecture (video + optional PDF).
// ─────────────────────────────────────────────────────────────
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────
//  Data class returned on submit
// ─────────────────────────────────────────────────────────────
class LectureUploadData {
  final String title;
  final String? description;
  final Uint8List? videoBytes;
  final String? videoFileName;
  final Uint8List? pdfBytes;
  final String? pdfFileName;
  final int? durationSeconds;
  final bool isFree;
  final int sortOrder;

  const LectureUploadData({
    required this.title,
    this.description,
    this.videoBytes,
    this.videoFileName,
    this.pdfBytes,
    this.pdfFileName,
    this.durationSeconds,
    this.isFree = false,
    this.sortOrder = 0,
  });
}

// ─────────────────────────────────────────────────────────────
//  LectureUploadForm widget
// ─────────────────────────────────────────────────────────────
class LectureUploadForm extends StatefulWidget {
  final Future<void> Function(LectureUploadData data) onSubmit;
  final bool isLoading;

  /// 0.0 – 1.0 upload progress reported by the caller.
  final double uploadProgress;

  const LectureUploadForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
    this.uploadProgress = 0.0,
  });

  @override
  State<LectureUploadForm> createState() => _LectureUploadFormState();
}

class _LectureUploadFormState extends State<LectureUploadForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '1');

  bool _isFree = false;

  // ── Picked files ──────────────────────────────────────────
  PlatformFile? _videoFile;
  PlatformFile? _pdfFile;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  // ── File pickers ──────────────────────────────────────────

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _videoFile = result.files.first);
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pdfFile = result.files.first);
    }
  }

  // ── Submit ────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final dur = int.tryParse(_durationCtrl.text.trim());
    final order = int.tryParse(_orderCtrl.text.trim()) ?? 0;

    await widget.onSubmit(LectureUploadData(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      videoBytes: _videoFile?.bytes,
      videoFileName: _videoFile?.name,
      pdfBytes: _pdfFile?.bytes,
      pdfFileName: _pdfFile?.name,
      durationSeconds: dur,
      isFree: _isFree,
      sortOrder: order,
    ));
  }

  // ── Helpers ───────────────────────────────────────────────

  String _fileSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title ─────────────────────────────────────
          _FieldLabel('Lecture Title *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Title is required' : null,
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'e.g. Introduction to Newton\'s Laws',
            ),
          ),

          const SizedBox(height: 16),

          // ── Description ───────────────────────────────
          _FieldLabel('Description'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Optional – What does this lecture cover?',
            ),
          ),

          const SizedBox(height: 16),

          // ── Video file picker ─────────────────────────
          _FieldLabel('Video File'),
          const SizedBox(height: 8),
          _FilePicker(
            icon: Icons.video_library_rounded,
            label: _videoFile == null
                ? 'Select video (MP4, MOV, MKV…)'
                : '${_videoFile!.name}  •  ${_fileSize(_videoFile!.size)}',
            color: AppColors.primary,
            hasFile: _videoFile != null,
            onTap: widget.isLoading ? null : _pickVideo,
            onRemove: _videoFile == null
                ? null
                : () => setState(() => _videoFile = null),
          ),

          const SizedBox(height: 12),

          // ── PDF notes picker ──────────────────────────
          _FieldLabel('PDF Notes  (optional)'),
          const SizedBox(height: 8),
          _FilePicker(
            icon: Icons.picture_as_pdf_rounded,
            label: _pdfFile == null
                ? 'Select PDF file'
                : '${_pdfFile!.name}  •  ${_fileSize(_pdfFile!.size)}',
            color: AppColors.error,
            hasFile: _pdfFile != null,
            onTap: widget.isLoading ? null : _pickPdf,
            onRemove: _pdfFile == null
                ? null
                : () => setState(() => _pdfFile = null),
          ),

          const SizedBox(height: 16),

          // ── Duration + Sort order (two columns) ───────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Duration (seconds)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: AppTextStyles.bodyMedium,
                      decoration: const InputDecoration(hintText: '0'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Display Order'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _orderCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: AppTextStyles.bodyMedium,
                      decoration: const InputDecoration(hintText: '1'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Free preview toggle ───────────────────────
          _FreeToggle(
            value: _isFree,
            onChanged: (v) => setState(() => _isFree = v),
          ),

          // ── Upload progress ───────────────────────────
          if (widget.isLoading) ...[
            const SizedBox(height: 20),
            _UploadProgressBar(progress: widget.uploadProgress),
          ],

          const SizedBox(height: 24),

          // ── Submit button ─────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: widget.isLoading ? null : _submit,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 20),
              label: Text(
                widget.isLoading ? 'Uploading…' : 'Upload Lecture',
                style: AppTextStyles.button,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Private sub-widgets
// ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.bodyMedium
            .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
      );
}

class _FilePicker extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool hasFile;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _FilePicker({
    required this.icon,
    required this.label,
    required this.color,
    required this.hasFile,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasFile
              ? color.withAlpha(20)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? color.withAlpha(100) : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: hasFile ? color : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: hasFile ? color : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasFile)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onRemove,
              )
            else
              Icon(Icons.attach_file_rounded,
                  size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _FreeToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _FreeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_open_rounded,
              size: 20, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Free Preview',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.success,
            activeTrackColor: AppColors.success.withAlpha(160),
          ),
        ],
      ),
    );
  }
}

class _UploadProgressBar extends StatelessWidget {
  final double progress;
  const _UploadProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Uploading…',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.primary)),
            Text('$pct%',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.surfaceVariant,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
