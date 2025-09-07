import 'io.dart';

///
/// R env
/// S state
/// A result
///
class EnvStateIO<R, S, A> {
  final IO<(A, S)> Function(R, S) run;

  EnvStateIO(this.run);

  EnvStateIO<R, S, B> map<B>(B Function(A) f) =>
      EnvStateIO((r, s) =>
        run(r, s).flatMap((tp) => IO.attempt(() => (f(tp.$1), tp.$2)))
      );

  EnvStateIO<R, S, B> flatMap<B>(EnvStateIO<R, S, B> Function(A) f) =>
      EnvStateIO((r, s) =>
        run(r, s).flatMap((tp) => f(tp.$1).run(r, tp.$2))
      );

  IO<(A, S)> provide(R r, S s) => run(r, s);
}

// Lê o ambiente
EnvStateIO<R, S, R> ask<R, S>() =>
    EnvStateIO((r, s) => IO.attempt(() => (r, s)));

// Lê o estado
EnvStateIO<R, S, S> get<R, S>() =>
    EnvStateIO((r, s) => IO.attempt(() => (s, s)));

// Atualiza o estado
EnvStateIO<R, S, void> put<R, S>(S newState) =>
    EnvStateIO((r, s) => IO.attempt(() => (null, newState)));

// Modifica o estado
EnvStateIO<R, S, void> modify<R, S>(S Function(S) f) =>
    EnvStateIO((r, s) => IO.attempt(() => (null, f(s))));