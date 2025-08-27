import 'dart:math';

sealed class Option<T> {
  static Option<A> of<A>(A? value) {
    if (value != null) return Some(value);
    return None();
  }

  static Option<String> str(String? value) {
    if (value != null && value.trim().isNotEmpty) return Some(value);
    return None();
  }

  const Option();

  T get() {
    throw Exception("can't get value");
  }

  T? get orNull => empty ? null : get();

  T or(T value) => empty ? value : get();

  Option<T> orElse(Option<T> Function() f) => empty ? f() : this;

  bool get nonEmpty => switch (this) { Some() => true, None() => false };

  bool get empty => !nonEmpty;

  Option<A> map<A>(A Function(T) f) {
    return switch (this) { Some(value: var v) => of(f(v)), None() => None() };
  }

  Option<B> cast<B>() {
    return map((x) => x as B);
  }

  Option<A> flatMap<A>(Option<A> Function(T) f) {
    return switch (this) { Some(value: var v) => f(v), None() => None() };
  }

  Option<T> foreach(Function(T) f) {
    if (this.nonEmpty) f(this.get());
    return this;
  }

  Option<T> filter(bool Function(T) f) {
    return switch (this) { Some(value: var v) => (f(v) ? this : None()), None() => None() };
  }

  Option<T> ifEmpty(Function() f) {
    if (empty) {
      f();
    }
    return this;
  }

  Option<T> ifNonEmpty(Function(T) f) {
    if (nonEmpty) {
      f((this as Some<T>).get());
    }
    return this;
  }
}

final class Some<T> extends Option<T> {
  T value;

  Some(this.value);

  @override
  T get() {
    return value!;
  }

  @override
  String toString() {
    return "Some($value)";
  }
}

final class None<T> extends Option<T> {
  const None();

  @override
  String toString() {
    return "None";
  }
}


extension AnyToOption<T> on T {
  Option<T> get liftOption => Option.of(this);
}
