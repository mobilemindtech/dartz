sealed class Either<A, B> {
  Either();

  bool get isLeft => switch (this) { Left() => true, _ => false };

  bool get isRight => !isLeft;

  static Either<A, B> left<A, B>(A value) => Left(value);

  static Either<A, B> right<A, B>(B value) => Right(value);
}

class Left<A, B> extends Either<A, B> {
  final A value;

  Left(this.value);

  @override
  String toString() {
    return "Left($value)";
  }
}

class Right<A, B> extends Either<A, B> {
  final B value;

  Right(this.value);

  @override
  String toString() {
    return "Right($value)";
  }
}
