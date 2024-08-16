sealed class Either<A, B> {
  Either();

  bool get isLeft => switch (this) { Left() => true, _ => false };

  bool get isRight => !isLeft;

  factory Either.left(A value) => Left(value);

  factory Either.right(B value) => Right(value);
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
