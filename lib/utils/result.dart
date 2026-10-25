sealed class Result<T, E> {
  const Result._();

  const factory Result.success(T value) = Success<T, E>;
  const factory Result.failure(E error) = Failure<T, E>;

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T? get valueOrNull => switch (this) {
    Success<T, E>(:final value) => value,
    Failure<T, E>() => null,
  };

  E? get errorOrNull => switch (this) {
    Success<T, E>() => null,
    Failure<T, E>(:final error) => error,
  };

  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) {
    return switch (this) {
      Success<T, E>(:final value) => success(value),
      Failure<T, E>(:final error) => failure(error),
    };
  }

  T getOrElse(T Function(E error) orElse) {
    return switch (this) {
      Success<T, E>(:final value) => value,
      Failure<T, E>(:final error) => orElse(error),
    };
  }

  T getOrDefault(T defaultValue) {
    return switch (this) {
      Success<T, E>(:final value) => value,
      Failure<T, E>() => defaultValue,
    };
  }

  Result<R, E> map<R>(R Function(T value) mapper) {
    return switch (this) {
      Success<T, E>(:final value) => Result.success(mapper(value)),
      Failure<T, E>(:final error) => Result.failure(error),
    };
  }

  Result<T, R> mapError<R>(R Function(E error) mapper) {
    return switch (this) {
      Success<T, E>(:final value) => Result.success(value),
      Failure<T, E>(:final error) => Result.failure(mapper(error)),
    };
  }

  Result<R, E> flatMap<R>(Result<R, E> Function(T value) mapper) {
    return switch (this) {
      Success<T, E>(:final value) => mapper(value),
      Failure<T, E>(:final error) => Result.failure(error),
    };
  }
}

final class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value) : super._();

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error) : super._();

  @override
  String toString() => 'Failure($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}

extension NullableToResult<T> on T? {
  Result<T, E> toResult<E>(E Function() onNull) {
    final value = this;
    if (value != null) return Result.success(value);
    return Result.failure(onNull());
  }
}

extension FutureResultExtension<T, E> on Future<Result<T, E>> {
  Future<Result<R, E>> mapAsync<R>(Future<R> Function(T value) mapper) async {
    final result = await this;
    return switch (result) {
      Success<T, E>(:final value) => Result.success(await mapper(value)),
      Failure<T, E>(:final error) => Result.failure(error),
    };
  }

  Future<Result<R, E>> flatMapAsync<R>(
    Future<Result<R, E>> Function(T value) mapper,
  ) async {
    final result = await this;
    return switch (result) {
      Success<T, E>(:final value) => await mapper(value),
      Failure<T, E>(:final error) => Result.failure(error),
    };
  }
}
