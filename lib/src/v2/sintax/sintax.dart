
import 'package:dartz/src/v2/io.dart';
import 'package:dartz/src/v2/io_app.dart';
import 'package:dartz/src/option.dart';

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
}

extension ListIO on List<IO> {
  Future unsafeRun({int? workerCount, bool continueOnError = true}) =>
    IOApp(workerCount: workerCount)
        .unsafeRunMany(this, continueOnError: continueOnError);
}