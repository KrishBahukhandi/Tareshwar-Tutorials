// ─────────────────────────────────────────────────────────────
//  content_upload_screen.dart  –  Teacher: upload lecture content
//  Flow: Pick Subject → Pick Chapter → Upload Lecture (video/PDF)
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../content_upload/data/content_upload_repository.dart';

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
  // ── Step tracking ──────────────────────────────────────────
  int _currentStep = 0; // 0 = subject, 1 = chapter, 2 = lecture

  // ── Subject ────────────────────────────────────────────────
  List<SubjectModel> _subjects = [];
  SubjectModel? _selectedSubject;
  bool _loadingSubjects = true;
  bool _creatingSubject = false;
  final _newSubjectCtrl = TextEditingController();
  bool _showNewSubjectField = false;

  // ── Chapter ────────────────────────────────────────────────
  List<ChapterModel> _chapters = [];
  ChapterModel? _selectedChapter;
  bool _loadingChapters = false;
  bool _creatingChapter = false;
  final _newChapterCtrl = TextEditingController();
  bool _showNewChapterField = false;

  // ── Lecture ────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '0');
  final _formKey = GlobalKey<FormState>();
  bool _isFree = false;
  int _order = 1;

  // ── File ───────────────────────────────────────────────────
  PlatformFile? _videoFile;
  PlatformFile? _pdfFile;

  // ── Upload state ───────────────────────────────────────────
  bool _isUploading = false;
  double _progress = 0;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _newSubjectCtrl.dispose();
    _newChapterCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  ContentUploadRepository get _repo =>
      ref.read(contentUploadRepoProvider);

  // ── Data loading ───────────────────────────────────────────
  Future<void> _loadSubjects() async {
    setState(() {
      _loadingSubjects = true;
      _error = null;
    });
    try {
      final subjects = await _repo.fetchSubjects(
        widget.courseId,
        teacherId: widget.teacherId,
      );
      setState(() {
        _subjects = subjects;
        _loadingSubjects = false;
      });
    } catch (e) {
      setState(() {
        _loadingSubjects = false;
        _error = 'Failed to load subjects: $e';
      });
    }
  }

  Future<void> _loadChapters(String subjectId) async {
    setState(() {
      _loadingChapters = true;
      _chapters = [];
      _selectedChapter = null;
      _error = null;
    });
    try {
      final chapters = await _repo.fetchChapters(
        subjectId,
        teacherId: widget.teacherId,
      );
      setState(() {
        _chapters = chapters;
        _loadingChapters = false;
      });
    } catch (e) {
      setState(() {
        _loadingChapters = false;
        _error = 'Failed to load chapters: $e';
      });
    }
  }

  // ── Create subject ─────────────────────────────────────────
  Future<void> _createSubject() async {
    final name = _newSubjectCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _creatingSubject = true);
    try {
      final subject = await _repo.createSubject(
        teacherId: widget.teacherId,
        courseId: widget.courseId,
        name: name,
        sortOrder: _subjects.length + 1,
      );
      _newSubjectCtrl.clear();
      setState(() {
        _subjects.add(subject);
        _selectedSubject = subject;
        _showNewSubjectField = false;
        _creatingSubject = false;
        _currentStep = 1;
      });
      _loadChapters(subject.id);
    } catch (e) {
      setState(() {
        _creatingSubject = false;
        _error = 'Failed to create subject: $e';
      });
    }
  }

  // ── Create chapter ─────────────────────────────────────────
  Future<void> _createChapter() async {
    final name = _newChapterCtrl.text.trim();
    if (name.isEmpty || _selectedSubject == null) return;
    setState(() => _creatingChapter = true);
    try {
      final chapter = await _repo.createChapter(
        teacherId: widget.teacherId,
        subjectId: _selectedSubject!.id,
        name: name,
        sortOrder: _chapters.length + 1,
      );
      _newChapterCtrl.clear();
      setState(() {
        _chapters.add(chapter);
        _selectedChapter = chapter;
        _showNewChapterField = false;
        _creatingChapter = false;
        _currentStep = 2;
      });
    } catch (e) {
      setState(() {
        _creatingChapter = false;
        _error = 'Failed to create chapter: $e';
      });
    }
  }

  // ── File picking ───────────────────────────────────────────
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
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
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pdfFile = result.files.first);
    }
  }

  // ── Upload lecture ─────────────────────────────────────────
  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedChapter == null) {
      setState(() => _error = 'Please select a chapter first.');
      return;
    }
    if (_videoFile == null && _pdfFile == null) {
      setState(() => _error = 'Please select at least a video or PDF file.');
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0;
      _error = null;
      _successMessage = null;
    });

    try {
      await _repo.createLecture(
        teacherId: widget.teacherId,
        chapterId: _selectedChapter!.id,
        courseId: widget.courseId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
        videoBytes: _videoFile?.bytes,
        videoFileName: _videoFile?.name,
        pdfBytes: _pdfFile?.bytes,
        pdfFileName: _pdfFile?.name,
        durationSeconds: int.tryParse(_durationCtrl.text) ?? 0,
        isFree: _isFree,
        sortOrder: _order,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      setState(() {
        _isUploading = false;
        _progress = 1.0;
        _successMessage = 'Lecture uploaded successfully!';
      });

      // Reset lecture form for next upload
      _titleCtrl.clear();
      _descCtrl.clear();
      _durationCtrl.text = '0';
      _videoFile = null;
      _pdfFile = null;
      _isFree = false;
      _order++;
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Upload failed: $e';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Content'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stepper Header ───────────────────────────────
            _StepperHeader(currentStep: _currentStep),
            const SizedBox(height: 24),

            // ── Error / Success Banners ──────────────────────
            if (_error != null) ...[
              _StatusBanner(message: _error!, isError: true),
              const SizedBox(height: 12),
            ],
            if (_successMessage != null) ...[
              _StatusBanner(message: _successMessage!, isError: false),
              const SizedBox(height: 12),
            ],

            // ── Step 1: Subject ──────────────────────────────
            _SectionCard(
              title: 'Step 1: Select Subject',
              icon: Icons.menu_book_rounded,
              isActive: true,
              child: _loadingSubjects
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_subjects.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedSubject?.id,
                            decoration: const InputDecoration(
                              labelText: 'Subject',
                              prefixIcon: Icon(Icons.subject_rounded),
                              border: OutlineInputBorder(),
                            ),
                            items: _subjects
                                .map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.name),
                                    ))
                                .toList(),
                            onChanged: (id) {
                              final subject = _subjects.firstWhere(
                                  (s) => s.id == id);
                              setState(() {
                                _selectedSubject = subject;
                                _currentStep = 1;
                              });
                              _loadChapters(subject.id);
                            },
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'or',
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_subjects.isEmpty && !_showNewSubjectField)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'No subjects yet. Create one to get started.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        if (!_showNewSubjectField)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => setState(
                                  () => _showNewSubjectField = true),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create New Subject'),
                            ),
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newSubjectCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'New Subject Name',
                                    hintText: 'e.g. Physics',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.add_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _creatingSubject
                                  ? const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : IconButton.filled(
                                      onPressed: _createSubject,
                                      icon: const Icon(Icons.check),
                                    ),
                              IconButton(
                                onPressed: () => setState(
                                    () => _showNewSubjectField = false),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // ── Step 2: Chapter ──────────────────────────────
            _SectionCard(
              title: 'Step 2: Select Chapter',
              icon: Icons.library_books_rounded,
              isActive: _selectedSubject != null,
              child: _selectedSubject == null
                  ? Text(
                      'Select a subject first',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textHint),
                    )
                  : _loadingChapters
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_chapters.isNotEmpty) ...[
                              DropdownButtonFormField<String>(
                                initialValue: _selectedChapter?.id,
                                decoration: const InputDecoration(
                                  labelText: 'Chapter',
                                  prefixIcon:
                                      Icon(Icons.bookmark_rounded),
                                  border: OutlineInputBorder(),
                                ),
                                items: _chapters
                                    .map((c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.name),
                                        ))
                                    .toList(),
                                onChanged: (id) {
                                  final chapter = _chapters.firstWhere(
                                      (c) => c.id == id);
                                  setState(() {
                                    _selectedChapter = chapter;
                                    _currentStep = 2;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: Text('or',
                                    style: AppTextStyles.bodySmall),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_chapters.isEmpty &&
                                !_showNewChapterField)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'No chapters yet. Create one to continue.',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            if (!_showNewChapterField)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(
                                      () => _showNewChapterField = true),
                                  icon: const Icon(Icons.add_rounded),
                                  label:
                                      const Text('Create New Chapter'),
                                ),
                              )
                            else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _newChapterCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'New Chapter Name',
                                        hintText:
                                            'e.g. Kinematics',
                                        border: OutlineInputBorder(),
                                        prefixIcon:
                                            Icon(Icons.add_rounded),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _creatingChapter
                                      ? const SizedBox(
                                          width: 40,
                                          height: 40,
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2),
                                        )
                                      : IconButton.filled(
                                          onPressed: _createChapter,
                                          icon: const Icon(
                                              Icons.check),
                                        ),
                                  IconButton(
                                    onPressed: () => setState(() =>
                                        _showNewChapterField = false),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
            ),
            const SizedBox(height: 16),

            // ── Step 3: Lecture Details + Upload ──────────────
            _SectionCard(
              title: 'Step 3: Upload Lecture',
              icon: Icons.cloud_upload_rounded,
              isActive: _selectedChapter != null,
              child: _selectedChapter == null
                  ? Text(
                      'Select a chapter first',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textHint),
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Lecture Title *',
                              hintText:
                                  'e.g. Introduction to Kinematics',
                              prefixIcon: Icon(Icons.title_rounded),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Title is required'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // Description
                          TextFormField(
                            controller: _descCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                              hintText: 'Brief description',
                              prefixIcon:
                                  Icon(Icons.description_rounded),
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 14),

                          // Duration & Order
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _durationCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Duration (sec)',
                                    prefixIcon:
                                        Icon(Icons.timer_rounded),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: '$_order',
                                  decoration: const InputDecoration(
                                    labelText: 'Sort Order',
                                    prefixIcon: Icon(
                                        Icons
                                            .format_list_numbered_rounded),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      TextInputType.number,
                                  onChanged: (v) =>
                                      _order = int.tryParse(v) ?? 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Free toggle
                          SwitchListTile(
                            title: const Text('Free Preview'),
                            subtitle: const Text(
                                'Non-enrolled students can view'),
                            value: _isFree,
                            onChanged: (v) =>
                                setState(() => _isFree = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(),
                          const SizedBox(height: 8),

                          // Video picker
                          Text('Video File',
                              style: AppTextStyles.labelLarge),
                          const SizedBox(height: 8),
                          _FilePickerTile(
                            file: _videoFile,
                            label: 'Tap to select video',
                            subtitle: 'MP4, MOV, MKV, WebM',
                            icon: Icons.play_circle_rounded,
                            iconColor: AppColors.primary,
                            onPick: _pickVideo,
                            onClear: () =>
                                setState(() => _videoFile = null),
                          ),
                          const SizedBox(height: 14),

                          // PDF picker
                          Text('PDF Notes (optional)',
                              style: AppTextStyles.labelLarge),
                          const SizedBox(height: 8),
                          _FilePickerTile(
                            file: _pdfFile,
                            label: 'Tap to select PDF',
                            subtitle: 'PDF up to 50 MB',
                            icon: Icons.picture_as_pdf_rounded,
                            iconColor: AppColors.error,
                            onPick: _pickPdf,
                            onClear: () =>
                                setState(() => _pdfFile = null),
                          ),
                          const SizedBox(height: 20),

                          // Progress
                          if (_isUploading) ...[
                            Text(
                              'Uploading... ${(_progress * 100).toStringAsFixed(0)}%',
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _progress,
                              backgroundColor:
                                  AppColors.surfaceVariant,
                              valueColor:
                                  const AlwaysStoppedAnimation(
                                      AppColors.primary),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Upload button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isUploading ? null : _upload,
                              icon: const Icon(
                                  Icons.cloud_upload_rounded),
                              label: Text(_isUploading
                                  ? 'Uploading...'
                                  : 'Upload Lecture'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stepper Header ───────────────────────────────────────────
class _StepperHeader extends StatelessWidget {
  final int currentStep;
  const _StepperHeader({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = ['Subject', 'Chapter', 'Upload'];
    return Row(
      children: List.generate(3, (i) {
        final isActive = i <= currentStep;
        return Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    isActive ? AppColors.primary : AppColors.border,
                child: Text(
                  '${i + 1}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isActive ? Colors.white : AppColors.textHint,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  labels[i],
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (i < 2) ...[
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < currentStep
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
        );
      }),
    );
  }
}

// ── Section Card ─────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isActive ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isActive ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      color:
                          isActive ? AppColors.primary : AppColors.textHint,
                      size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── File Picker Tile ─────────────────────────────────────────
class _FilePickerTile extends StatelessWidget {
  final PlatformFile? file;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _FilePickerTile({
    required this.file,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? AppColors.success : AppColors.border,
          ),
        ),
        child: file != null
            ? Row(
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file!.name,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          _formatSize(file!.size),
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 28, color: AppColors.textHint),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.bodyMedium),
                      Text(subtitle, style: AppTextStyles.bodySmall),
                    ],
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

// ── Status Banner ────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _StatusBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.success;
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;
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
