
import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:dartz/src/result.dart';
import 'package:dartz/src/option.dart';
import 'package:dartz/src/runtime.dart';


class IOApp {

  late int? workerCount;
  static final Runtime _runtime  = Runtime(workerCount: Platform.numberOfProcessors);

  IOApp({this.workerCount});

  Future<Option<A>> unsafeRun<A>(IO<A> io) async {
    try {
      switch(await _runtime.eval(io)) {
        case Ok(value: var value):
          return value;
        case Failure(failure: var failure, stackTrace: var stackTrace):
          return Future.error(failure, stackTrace);
      }
    } catch(err, stacktrace){
      print("IOApp error $err:\n $stacktrace");
      return Future.error(err, stacktrace);
    }
  }

  Future<Result<Option<A>>> safeRun<A>(IO<A> io) async {
    try {
      return await _runtime.eval(io);
    } on Exception catch(err, stackTrace){
      print("IOApp error $err:\n $stackTrace");
      return Result.failure(err.exn, stackTrace);
    }
  }
  

  Future<Option<List>> unsafeRunMany(List<IO> ios, {bool continueOnError = true, int? maxParallelism}) async {
    return _runtime.evalMany(ios, continueOnError: continueOnError, maxParallelism: maxParallelism);
  }



  void dispose() {
    _runtime.dispose();
  }

  Map<String, dynamic> get stats => _runtime.stats;
}



