import 'package:flutter_test/flutter_test.dart';
import 'package:tareshwar_tutorials/features/auth/presentation/providers/auth_provider.dart';
import 'package:tareshwar_tutorials/shared/models/models.dart';

void main() {
  test('QuestionModel.fromJson keeps the answer key for review flows', () {
    final question = QuestionModel.fromJson({
      'id': 'q1',
      'test_id': 't1',
      'question': '2 + 2 = ?',
      'options': ['1', '2', '4', '5'],
      'correct_option_index': 2,
      'marks': 4,
      'explanation': '2 plus 2 equals 4.',
    });

    expect(question.correctOptionIndex, 2);
    expect(question.hasAnswerKey, isTrue);
    expect(question.explanation, '2 plus 2 equals 4.');
  });

  test('QuestionModel.fromStudentJson redacts the answer key', () {
    final question = QuestionModel.fromStudentJson({
      'id': 'q1',
      'test_id': 't1',
      'question': '2 + 2 = ?',
      'options': ['1', '2', '4', '5'],
      'marks': 4,
    });

    expect(question.correctOptionIndex, QuestionModel.redactedAnswerIndex);
    expect(question.hasAnswerKey, isFalse);
    expect(question.explanation, isNull);
  });

  test('BatchModel computes fill percentage and full-state correctly', () {
    final batch = BatchModel(
      id: 'b1',
      courseId: 'c1',
      batchName: 'Morning Batch',
      startDate: DateTime(2026, 1, 1),
      maxStudents: 40,
      enrolledCount: 40,
      createdAt: DateTime(2026, 1, 1),
    );

    expect(batch.fillPercent, 1.0);
    expect(batch.isFull, isTrue);
  });

  test('AuthState keeps verification-email flow unauthenticated', () {
    const state = AuthState(status: AuthStatus.verificationEmailSent);

    expect(state.isAuthenticated, isFalse);
    expect(state.verificationEmailSent, isTrue);
  });

  test('AuthState.copyWith clears volatile auth values when requested', () {
    const initial = AuthState(
      status: AuthStatus.error,
      errorMessage: 'Bad credentials',
      pendingPhone: '+910000000000',
    );

    final cleared = initial.copyWith(
      clearError: true,
      clearPhone: true,
      status: AuthStatus.unauthenticated,
    );

    expect(cleared.status, AuthStatus.unauthenticated);
    expect(cleared.errorMessage, isNull);
    expect(cleared.pendingPhone, isNull);
  });
}
