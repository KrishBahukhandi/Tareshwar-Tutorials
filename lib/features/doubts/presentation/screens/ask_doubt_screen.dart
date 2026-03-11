// ─────────────────────────────────────────────────────────────
//  ask_doubt_screen.dart  –  Post a new doubt
//  • Rich text field
//  • Attach image from gallery / camera
//  • Preview before submit
//  • Linked to an optional lectureId
// ─────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/services/app_providers.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/doubt_service.dart';

// ─────────────────────────────────────────────────────────────
class AskDoubtScreen extends ConsumerStatefulWidget {
  final String? lectureId;
  const AskDoubtScreen({super.key, this.lectureId});

  @override
  ConsumerState<AskDoubtScreen> createState() => _AskDoubtScreenState();
}

class _AskDoubtScreenState extends ConsumerState<AskDoubtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionCtrl = TextEditingController();
  File? _image;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  // ── Image picker ──────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked != null && mounted) {
      setState(() => _image = File(picked.path));
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.photo_library_rounded,
                      color: Colors.white, size: 20),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.secondary,
                  child: Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 20),
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId =
        ref.read(authServiceProvider).currentAuthUser?.id;
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final doubt = await ref.read(doubtServiceProvider).postDoubt(
            studentId: userId,
            question: _questionCtrl.text.trim(),
            lectureId: widget.lectureId,
            image: _image,
          );

      // Invalidate lists so they refresh
      ref.invalidate(myDoubtsProvider);
      ref.invalidate(doubtsProvider);

      if (mounted) {
        // Navigate to the new doubt's detail screen
        context.replace(AppRoutes.doubtDetailPath(doubt.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post doubt: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ask a Doubt'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _submit,
                    child: Text(
                      'Post',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
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
              // ── Context banner ─────────────────────────
              if (widget.lectureId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.video_library_rounded,
                          size: 16, color: AppColors.info),
                      const SizedBox(width: 8),
                      Text(
                        'Linked to current lecture',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.info),
                      ),
                    ],
                  ),
                ),

              // ── Question field ─────────────────────────
              Text('Your Question',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: 10),
              TextFormField(
                controller: _questionCtrl,
                minLines: 4,
                maxLines: 10,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText:
                      'Describe your doubt clearly. Include chapter, topic, or question number if applicable...',
                  hintStyle: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textHint),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please describe your doubt';
                  }
                  if (v.trim().length < 10) {
                    return 'Please be more descriptive (min 10 chars)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Attach image ───────────────────────────
              Text('Attach Image (optional)',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: 10),
              if (_image == null)
                GestureDetector(
                  onTap: _showImageOptions,
                  child: Container(
                    width: double.infinity,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              Icons.add_photo_alternate_rounded,
                              color: AppColors.primary,
                              size: 28),
                        ),
                        const SizedBox(height: 10),
                        Text('Tap to attach a photo',
                            style: AppTextStyles.bodyMedium
                                .copyWith(
                                    color: AppColors.textSecondary)),
                        Text(
                          'Gallery or Camera',
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                _ImagePreview(
                  image: _image!,
                  onRemove: () => setState(() => _image = null),
                  onReplace: _showImageOptions,
                ),

              const SizedBox(height: 32),

              // ── Tips ───────────────────────────────────
              _TipBox(),

              const SizedBox(height: 32),

              // ── Submit button ──────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'Posting...' : 'Post Doubt',
                    style: AppTextStyles.button,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Image preview
// ─────────────────────────────────────────────────────────────
class _ImagePreview extends StatelessWidget {
  final File image;
  final VoidCallback onRemove;
  final VoidCallback onReplace;
  const _ImagePreview({
    required this.image,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            image,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _ImgBtn(
                icon: Icons.edit_rounded,
                onTap: onReplace,
                color: AppColors.info,
              ),
              const SizedBox(width: 6),
              _ImgBtn(
                icon: Icons.delete_rounded,
                onTap: onRemove,
                color: AppColors.error,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImgBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _ImgBtn(
      {required this.icon,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Tips box
// ─────────────────────────────────────────────────────────────
class _TipBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 6),
              Text('Tips for a great doubt',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 8),
          ..._tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style:
                          TextStyle(color: AppColors.textSecondary)),
                  Expanded(
                      child: Text(t,
                          style: AppTextStyles.bodySmall)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _tips = [
    'Mention the chapter and topic clearly.',
    'Include question numbers if referring to textbook.',
    'Attach an image of the problem for faster resolution.',
    'Be specific — avoid vague questions like "I don\'t understand".',
  ];
}
