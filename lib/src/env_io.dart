
import 'io.dart';



///
/// R env
/// A result
///
class EnvIO<R, A> {
  final IO<A> Function(R) run;

  EnvIO(this.run);

  EnvIO<R, B> map<B>(B Function(A) f) =>
      EnvIO((r) => run(r).map(f));

  EnvIO<R, B> flatMap<B>(EnvIO<R, B> Function(A) f) =>
      EnvIO((r) => run(r).flatMap((a) => f(a).run(r)));

  IO<A> provide(R env) => run(env);
}