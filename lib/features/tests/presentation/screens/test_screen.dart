// ─────────────────────────────────────────────────────────────
//  test_screen.dart  –  MCQ Test Interface with Timer
// ─────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/test_service.dart';

// ── State ─────────────────────────────────────────────────────
class TestState {
  final TestModel? test;
  final List<QuestionModel> questions;
  final Map<String, int> answers;        // questionId → selectedOption
  final int currentIndex;
  final int remainingSeconds;
  final bool isSubmitted;
  final bool isLoading;
  final String? error;

  const TestState({
    this.test,
    this.questions = const [],
    this.answers = const {},
    this.currentIndex = 0,
    this.remainingSeconds = 0,
    this.isSubmitted = false,
    this.isLoading = true,
    this.error,
  });

  TestState copyWith({
    TestModel? test,
    List<QuestionModel>? questions,
    Map<String, int>? answers,
    int? currentIndex,
    int? remainingSeconds,
    bool? isSubmitted,
    bool? isLoading,
    String? error,
  }) =>
      TestState(
        test: test ?? this.test,
        questions: questions ?? this.questions,
        answers: answers ?? this.answers,
        currentIndex: currentIndex ?? this.currentIndex,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        isSubmitted: isSubmitted ?? this.isSubmitted,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class TestNotifier extends StateNotifier<TestState> {
  final TestService _service;
  final AuthService _authService;
  final String testId;
  Timer? _timer;

  TestNotifier(this._service, this._authService, this.testId)
      : super(const TestState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final test = await _service.fetchTest(testId);
      final questions = await _service.fetchQuestions(testId);
      state = state.copyWith(
        test: test,
        questions: questions,
        remainingSeconds: test.durationMinutes * 60,
        isLoading: false,
      );
      _startTimer();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.remainingSeconds <= 0) {
        _timer?.cancel();
        _autoSubmit();
      } else {
        state = state.copyWith(
            remainingSeconds: state.remainingSeconds - 1);
      }
    });
  }

  void selectAnswer(String questionId, int optionIndex) {
    state = state.copyWith(
        answers: {...state.answers, questionId: optionIndex});
  }

  void goToQuestion(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void goNext() {
    if (state.currentIndex < state.questions.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void goPrev() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  Future<void> submit(BuildContext context) async {
    _timer?.cancel();
    final userId = _authService.currentAuthUser?.id;
    if (userId == null) return;

    final timeTaken =
        (state.test?.durationMinutes ?? 0) * 60 - state.remainingSeconds;

    try {
      final attempt = await _service.submitAttempt(
        testId: testId,
        studentId: userId,
        questions: state.questions,
        answers: state.answers,
        timeTakenSeconds: timeTaken,
      );
      state = state.copyWith(isSubmitted: true);
      if (context.mounted) {
        context.go(AppRoutes.testResultPath(testId),
            extra: attempt);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _autoSubmit() {
    // trigger auto-submit without navigation (called later)
    state = state.copyWith(isSubmitted: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final testNotifierProvider = StateNotifierProvider.autoDispose
    .family<TestNotifier, TestState, String>((ref, testId) {
  return TestNotifier(
    ref.watch(testServiceProvider),
    ref.watch(authServiceProvider),
    testId,
  );
});

// ── Screen ─────────────────────────────────────────────────────
class TestScreen extends ConsumerWidget {
  final String testId;
  const TestScreen({super.key, required this.testId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(testNotifierProvider(testId));
    final notifier = ref.read(testNotifierProvider(testId).notifier);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null) {
      return Scaffold(
        body: Center(child: Text('Error: ${state.error}')),
      );
    }

    final q = state.questions[state.currentIndex];
    final mins = state.remainingSeconds ~/ 60;
    final secs = state.remainingSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final isWarning = state.remainingSeconds < 300;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog(context, notifier, state);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(state.test?.title ?? 'Test',
              style: AppTextStyles.headlineSmall),
          actions: [
            // Timer chip
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isWarning
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: isWarning ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isWarning ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (state.currentIndex + 1) / state.questions.length,
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.primary,
              minHeight: 4,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question number
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Q ${state.currentIndex + 1}/${state.questions.length}',
                            style: AppTextStyles.labelLarge
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${q.marks} marks',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Question text
                    Text(q.question, style: AppTextStyles.bodyLarge),
                    const SizedBox(height: 24),

                    // Options
                    ...List.generate(q.options.length, (i) {
                      final selected = state.answers[q.id];
                      final isSelected = selected == i;
                      return GestureDetector(
                        onTap: () => notifier.selectAnswer(q.id, i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surfaceVariant,
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + i),
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(q.options[i],
                                    style: AppTextStyles.bodyMedium),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Navigation footer
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: state.currentIndex > 0
                        ? notifier.goPrev
                        : null,
                    child: const Text('← Prev'),
                  ),
                  const Spacer(),
                  // Question palette button
                  IconButton(
                    icon: const Icon(Icons.grid_view_rounded),
                    onPressed: () => _showPalette(
                        context, state, notifier),
                  ),
                  const Spacer(),
                  if (state.currentIndex < state.questions.length - 1)
                    ElevatedButton(
                      onPressed: notifier.goNext,
                      child: const Text('Next →'),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success),
                      onPressed: () =>
                          notifier.submit(context),
                      child: const Text('Submit Test'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPalette(BuildContext context, TestState state,
      TestNotifier notifier) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Question Palette',
                style: AppTextStyles.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                state.questions.length,
                (i) {
                  final qId = state.questions[i].id;
                  final answered = state.answers.containsKey(qId);
                  return GestureDetector(
                    onTap: () {
                      notifier.goToQuestion(i);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: i == state.currentIndex
                            ? AppColors.primary
                            : answered
                                ? AppColors.success
                                : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: (i == state.currentIndex || answered)
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(color: AppColors.primary, label: 'Current'),
                const SizedBox(width: 16),
                _Legend(color: AppColors.success, label: 'Answered'),
                const SizedBox(width: 16),
                _Legend(
                    color: AppColors.surfaceVariant,
                    label: 'Unanswered'),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showExitDialog(
      BuildContext context, TestNotifier notifier, TestState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quit Test?'),
        content: const Text(
            'Your progress will be lost. Are you sure you want to exit?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Test')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.go(AppRoutes.studentDashboard);
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}
