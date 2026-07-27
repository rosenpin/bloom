/// Plan time is the only engine phase allowed to fail richly.
library;

import '../content/exercise.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final PlanAssemblyError error;
}

enum PlanAssemblyErrorCode { noUsableExercises }

final class PlanAssemblyError {
  PlanAssemblyError({
    required this.code,
    required this.message,
    Iterable<BlockRole> affectedRoles = const <BlockRole>[],
  }) : affectedRoles = List<BlockRole>.unmodifiable(affectedRoles);

  final PlanAssemblyErrorCode code;
  final String message;
  final List<BlockRole> affectedRoles;

  @override
  bool operator ==(Object other) =>
      other is PlanAssemblyError &&
      other.code == code &&
      other.message == message &&
      _sameRoles(other.affectedRoles, affectedRoles);

  @override
  int get hashCode => Object.hash(code, message, Object.hashAll(affectedRoles));

  @override
  String toString() => 'PlanAssemblyError(${code.name}: $message)';
}

bool _sameRoles(List<BlockRole> left, List<BlockRole> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
