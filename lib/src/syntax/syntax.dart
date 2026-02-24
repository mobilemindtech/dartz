
import 'package:dartz/src/io.dart';
import 'package:dartz/src/io_app.dart';
import 'package:dartz/src/option.dart';
import 'package:dartz/src/result.dart';

extension IOFlatMapSintax<A, B> on IO<A> {
  IO<B> operator >>(B Function(A) f) => map(f);
  IO<B> operator >>>(IO<B> Function(A) f) => flatMap(f);
}

extension IntToDuration on int {
  Duration get seconds => Duration(seconds: this);
  Duration get minutes => Duration(minutes: this);
  Duration get micros => Duration(microseconds: this);
  Duration get millis => Duration(milliseconds: this);
}

extension ListTraverse<A> on List<A> {
  IO<List<B>> traverse<B>(B Function(A) f) => IO.traverse(this, f);
  IO<List<B>> traverseM<B>(IO<B> Function(A) f) => IO.traverseM(this, f);
}

extension IOAppIO<A> on IO<A> {
  Future<Option<A>> unsafeRun({int? workerCount}) async =>
      IOApp(workerCount: workerCount).unsafeRun(this);

  Future<Result<Option<A>>> safeRun({int? workerCount}) async =>
      IOApp(workerCount: workerCount).safeRun(this);

  // AndThan
  IO operator |(IO other) => andThenIO(other);
}

extension ListIO on List<IO> {
  Future unsafeRun({int? workerCount = null, bool continueOnError = true}) async =>
    IOApp(workerCount: workerCount)
        .unsafeRunMany(this, continueOnError: continueOnError);

  IO<Unit> get toIO  {
    assert(this.isNotEmpty);
    IO? io;
    for(var it in this){
      if(io == null) io = it;
      else io = io.andThenIO(it);
    }
    return io!.mapToUnit;
  }
}

extension AnyExn<T> on T {
  Exception get exn => T is Exception ? this as Exception : Exception("$this");
}