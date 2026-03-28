// ─────────────────────────────────────────────────────────────
//  test_providers.dart  –  Live test session state + Riverpod
//  providers for the MCQ Test module.
// ─────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/app_router.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/services/analytics_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/test_service.dart';

// ═══════════════════════════════════════════════════════════════
//  TestSessionState  –  immutable snapshot of live test
// ═══════════════════════════════════════════════════════════════
class TestSessionState {
  final TestModel? test;
  final List<QuestionModel> questions;

  /// questionId → selectedOptionIndex
  final Map<String, int> answers;

  /// Set of questionIds marked for review
  final Set<String> markedForReview;

  final int currentIndex;
  final int remainingSeconds;
  final bool isSubmitted;
  final bool isLoading;
  final String? error;

  const TestSessionState({
    this.test,
    this.questions = const [],
    this.answers = const {},
    this.markedForReview = const {},
    this.currentIndex = 0,
    this.remainingSeconds = 0,
    this.isSubmitted = false,
    this.isLoading = true,
    this.error,
  });

  TestSessionState copyWith({
    TestModel? test,
    List<QuestionModel>? questions,
    Map<String, int>? answers,
    Set<String>? markedForReview,
    int? currentIndex,
    int? remainingSeconds,
    bool? isSubmitted,
    bool? isLoading,
    String? error,
  }) =>
      TestSessionState(
        test: test ?? this.test,
        questions: questions ?? this.questions,
        answers: answers ?? this.answers,
        markedForReview: markedForReview ?? this.markedForReview,
        currentIndex: currentIndex ?? this.currentIndex,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        isSubmitted: isSubmitted ?? this.isSubmitted,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  // ── Derived helpers ──────────────────────────────────────
  int get totalQuestions => questions.length;
  int get answeredCount => answers.length;
  int get notVisitedCount =>
      questions.where((q) => !answers.containsKey(q.id)).length;
  int get reviewCount => markedForReview.length;
  int get answeredAndReviewCount => answers.keys
      .where((id) => markedForReview.contains(id))
      .length;

  /// Status for question palette colouring
  QuestionStatus statusOf(int idx) {
    if (idx >= questions.length) return QuestionStatus.notVisited;
    final qId = questions[idx].id;
    final answered = answers.containsKey(qId);
    final marked = markedForReview.contains(qId);
    if (answered && marked) return QuestionStatus.answeredAndMarked;
    if (marked) return QuestionStatus.markedForReview;
    if (answered) return QuestionStatus.answered;
    if (idx == currentIndex) return QuestionStatus.current;
    return QuestionStatus.notVisited;
  }
}

enum QuestionStatus {
  notVisited,
  current,
  answered,
  markedForReview,
  answeredAndMarked,
}

// ═══════════════════════════════════════════════════════════════
//  TestSessionNotifier
// ═══════════════════════════════════════════════════════════════
class TestSessionNotifier extends StateNotifier<TestSessionState> {
  final TestService _service;
  final AuthService _auth;
  final AnalyticsService _analytics;
  final String testId;

  Timer? _timer;

  TestSessionNotifier({
    required TestService service,
    required AuthService auth,
    required AnalyticsService analytics,
    required this.testId,
  })  : _service = service,
        _auth = auth,
        _analytics = analytics,
        super(const TestSessionState()) {
    _load();
  }

  // ── Initialise ───────────────────────────────────────────
  Future<void> _load() async {
    try {
      final test = await _service.fetchTest(testId);
      final questions = await _service.fetchStudentQuestions(testId);
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
      if (state.remainingSeconds <= 1) {
        _timer?.cancel();
        state = state.copyWith(remainingSeconds: 0);
        // auto-submit flag — screen listens and navigates
        state = state.copyWith(isSubmitted: true);
      } else {
        state = state.copyWith(
            remainingSeconds: state.remainingSeconds - 1);
      }
    });
  }

  // ── Actions ──────────────────────────────────────────────
  void selectAnswer(String questionId, int optionIndex) {
    state = state.copyWith(
      answers: {...state.answers, questionId: optionIndex},
    );
  }

  void clearAnswer(String questionId) {
    final updated = Map<String, int>.from(state.answers);
    updated.remove(questionId);
    state = state.copyWith(answers: updated);
  }

  void toggleMarkForReview(String questionId) {
    final set = Set<String>.from(state.markedForReview);
    if (set.contains(questionId)) {
      set.remove(questionId);
    } else {
      set.add(questionId);
    }
    state = state.copyWith(markedForReview: set);
  }

  void goToQuestion(int index) {
    if (index >= 0 && index < state.questions.length) {
      state = state.copyWith(currentIndex: index);
    }
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

  // ── Submit ───────────────────────────────────────────────
  Future<void> submit(BuildContext context) async {
    _timer?.cancel();
    final userId = _auth.currentAuthUser?.id;
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

      // ── Analytics: test_attempted ─────────────────────
      _analytics.trackTestAttempted(
        testId:           testId,
        testTitle:        state.test?.title ?? testId,
        score:            attempt.score.toDouble(),
        totalMarks:       attempt.totalMarks.toDouble(),
        timeTakenSeconds: timeTaken,
      );

      if (context.mounted) {
        context.go(AppRoutes.testResultPath(testId), extra: attempt);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
//  Provider
// ═══════════════════════════════════════════════════════════════
final testSessionProvider = StateNotifierProvider.autoDispose
    .family<TestSessionNotifier, TestSessionState, String>((ref, testId) {
  return TestSessionNotifier(
    service:   ref.watch(testServiceProvider),
    auth:      ref.watch(authServiceProvider),
    analytics: ref.watch(analyticsServiceProvider),
    testId:    testId,
  );
});
