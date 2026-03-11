// ─────────────────────────────────────────────────────────────
//  content_upload_screen.dart  –  Teacher: upload lecture content
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../core/constants/app_constants.dart';

// ── State ─────────────────────────────────────────────────────
class _UploadState {
  final bool isUploading;
  final double progress;
  final String? error;
  final String? successMessage;
  final ContentType selectedType;

  const _UploadState({
    this.isUploading = false,
    this.progress = 0,
    this.error,
    this.successMessage,
    this.selectedType = ContentType.video,
  });

  _UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    String? successMessage,
    ContentType? selectedType,
  }) =>
      _UploadState(
        isUploading: isUploading ?? this.isUploading,
        progress: progress ?? this.progress,
        error: error,
        successMessage: successMessage,
        selectedType: selectedType ?? this.selectedType,
      );
}

enum ContentType { video, pdf, notes, quiz }

extension ContentTypeExt on ContentType {
  String get label {
    switch (this) {
      case ContentType.video:
        return 'Video Lecture';
      case ContentType.pdf:
        return 'PDF Notes';
      case ContentType.notes:
        return 'Text Notes';
      case ContentType.quiz:
        return 'Quiz';
    }
  }

  IconData get icon {
    switch (this) {
      case ContentType.video:
        return Icons.play_circle_rounded;
      case ContentType.pdf:
        return Icons.picture_as_pdf_rounded;
      case ContentType.notes:
        return Icons.article_rounded;
      case ContentType.quiz:
        return Icons.quiz_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ContentType.video:
        return AppColors.primary;
      case ContentType.pdf:
        return AppColors.error;
      case ContentType.notes:
        return AppColors.success;
      case ContentType.quiz:
        return AppColors.warning;
    }
  }

  String get bucket {
    switch (this) {
      case ContentType.video:
        return AppConstants.lectureVideosBucket;
      case ContentType.pdf:
      case ContentType.notes:
        return AppConstants.notesBucket;
      case ContentType.quiz:
        return AppConstants.notesBucket;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────
class ContentUploadScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String teacherId;

  const ContentUploadScreen({
    super.key,
    required this.courseId,
    required this.teacherId,
  });

  @override
  ConsumerState<ContentUploadScreen> createState() =>
      _ContentUploadScreenState();
}

class _ContentUploadScreenState extends ConsumerState<ContentUploadScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '0');
  final _formKey = GlobalKey<FormState>();

  _UploadState _state = const _UploadState();
  PlatformFile? _pickedFile;
  bool _isFree = false;
  int _order = 1;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final type = _state.selectedType;
    FileType fileType = FileType.video;
    List<String>? extensions;

    if (type == ContentType.pdf) {
      fileType = FileType.custom;
      extensions = ['pdf'];
    } else if (type == ContentType.notes) {
      fileType = FileType.custom;
      extensions = ['pdf', 'doc', 'docx', 'txt'];
    }

    final result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowedExtensions: extensions,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_state.selectedType != ContentType.quiz && _pickedFile == null) {
      setState(() => _state = _state.copyWith(error: 'Please select a file'));
      return;
    }

    setState(() => _state = _state.copyWith(isUploading: true, progress: 0));

    try {
      final client = ref.read(supabaseClientProvider);
      String? fileUrl;

      // Upload file to Supabase Storage
      if (_pickedFile != null && _pickedFile!.bytes != null) {
        final fileName =
            '${widget.courseId}/${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}';
        final bucket = _state.selectedType.bucket;

        setState(() =>
            _state = _state.copyWith(isUploading: true, progress: 0.3));

        await client.storage.from(bucket).uploadBinary(
              fileName,
              _pickedFile!.bytes!,
              fileOptions: const FileOptions(upsert: false),
            );

        fileUrl = client.storage.from(bucket).getPublicUrl(fileName);
        setState(() =>
            _state = _state.copyWith(isUploading: true, progress: 0.7));
      }

      // Insert lecture record to DB
      await client.from('lectures').insert({
        'course_id': widget.courseId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'type': _state.selectedType.name,
        'video_url': _state.selectedType == ContentType.video ? fileUrl : null,
        'pdf_url': _state.selectedType == ContentType.pdf ? fileUrl : null,
        'duration_seconds':
            int.tryParse(_durationCtrl.text) ?? 0,
        'is_free': _isFree,
        'order': _order,
        'created_at': DateTime.now().toIso8601String(),
      });

      setState(() => _state = _state.copyWith(
            isUploading: false,
            progress: 1.0,
            successMessage: '✅ Content uploaded successfully!',
          ));

      _titleCtrl.clear();
      _descCtrl.clear();
      _pickedFile = null;
    } catch (e) {
      setState(() => _state = _state.copyWith(
            isUploading: false,
            error: 'Upload failed: $e',
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Content'),
        actions: [
          TextButton.icon(
            onPressed: _state.isUploading ? null : _upload,
            icon: const Icon(Icons.cloud_upload_rounded),
            label: const Text('Publish'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Content Type Selector ──────────────────────
              Text('Content Type', style: AppTextStyles.labelLarge),
              const SizedBox(height: 12),
              Row(
                children: ContentType.values
                    .map((type) => Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: _TypeCard(
                              type: type,
                              isSelected:
                                  _state.selectedType == type,
                              onTap: () => setState(() => _state =
                                  _state.copyWith(selectedType: type)),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),

              // ── Title ──────────────────────────────────────
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lecture Title *',
                  hintText: 'e.g. Introduction to Kinematics',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              // ── Description ────────────────────────────────
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of this lecture',
                  prefixIcon: Icon(Icons.description_rounded),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // ── Duration & Order ───────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Duration (seconds)',
                        prefixIcon: Icon(Icons.timer_rounded),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_order',
                      decoration: const InputDecoration(
                        labelText: 'Order / Sequence',
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          _order = int.tryParse(v) ?? 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Free preview toggle ────────────────────────
              SwitchListTile(
                title: const Text('Free Preview'),
                subtitle: const Text(
                    'Allow non-enrolled students to view this'),
                value: _isFree,
                onChanged: (v) => setState(() => _isFree = v),
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              const SizedBox(height: 8),

              // ── File Picker ────────────────────────────────
              if (_state.selectedType != ContentType.quiz) ...[
                Text('File', style: AppTextStyles.labelLarge),
                const SizedBox(height: 12),
                _FilePicker(
                  pickedFile: _pickedFile,
                  contentType: _state.selectedType,
                  onPick: _pickFile,
                ),
                const SizedBox(height: 24),
              ],

              // ── Upload Progress ────────────────────────────
              if (_state.isUploading) ...[
                Text(
                  'Uploading… ${(_state.progress * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _state.progress,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
              ],

              // ── Status Messages ────────────────────────────
              if (_state.error != null)
                _StatusBanner(
                    message: _state.error!, isError: true),
              if (_state.successMessage != null)
                _StatusBanner(
                    message: _state.successMessage!, isError: false),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Type Card ─────────────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final ContentType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? type.color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? type.color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(type.icon, color: type.color, size: 24),
            const SizedBox(height: 4),
            Text(
              type.label.split(' ').first,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? type.color : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── File Picker Widget ────────────────────────────────────────
class _FilePicker extends StatelessWidget {
  final PlatformFile? pickedFile;
  final ContentType contentType;
  final VoidCallback onPick;

  const _FilePicker({
    required this.pickedFile,
    required this.contentType,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: pickedFile != null
                ? AppColors.success
                : AppColors.border,
            style: BorderStyle.solid,
          ),
        ),
        child: pickedFile != null
            ? Row(
                children: [
                  Icon(contentType.icon,
                      color: contentType.color, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pickedFile!.name,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          _formatSize(pickedFile!.size),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success),
                ],
              )
            : Column(
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 48, color: AppColors.textHint),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to select ${contentType.label}',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contentType == ContentType.video
                        ? 'MP4, MOV up to 2 GB'
                        : 'PDF, DOC up to 50 MB',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ── Status Banner ─────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _StatusBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.success;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
