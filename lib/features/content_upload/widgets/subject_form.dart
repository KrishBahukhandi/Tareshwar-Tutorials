// ─────────────────────────────────────────────────────────────
//  subject_form.dart
//  Reusable form widget for creating a Subject under a Course.
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_text_styles.dart';

class SubjectForm extends StatefulWidget {
  /// Called when the user taps "Save Subject".
  /// Returns the validated (name, sortOrder) values.
  final Future<void> Function(String name, int sortOrder) onSubmit;

  /// Whether the parent is currently saving.
  final bool isLoading;

  const SubjectForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
  });

  @override
  State<SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends State<SubjectForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _orderCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final sortOrder = int.tryParse(_orderCtrl.text.trim()) ?? 1;
    final name = _nameCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    await widget.onSubmit(name, sortOrder);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Subject Name ──────────────────────────────
          _FieldLabel('Subject Name *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Name is required';
              if (value.length < 3) return 'Enter at least 3 characters';
              return null;
            },
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'e.g. Mathematics, Physics',
            ),
          ),

          const SizedBox(height: 16),

          // ── Sort Order ────────────────────────────────
          _FieldLabel('Display Order'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _orderCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final n = int.tryParse(v.trim());
              if (n == null || n < 1) return 'Enter 1 or more';
              return null;
            },
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(hintText: '1'),
          ),

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
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                widget.isLoading ? 'Saving…' : 'Save Subject',
                style: AppTextStyles.button,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Internal field label ──────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.bodyMedium.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
  );
}
