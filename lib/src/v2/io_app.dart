
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dartz/src/result.dart';
import 'package:dartz/src/option.dart';
import 'package:dartz/src/trying.dart';
import 'package:dartz/src/v2/runtime.dart';
import 'package:dartz/src/v2/io.dart';


class IOApp {

  late int? workerCount;
  late final Runtime _runtime;

  IOApp({this.workerCount}){
    _runtime = Runtime(workerCount: workerCount ?? Platform.numberOfProcessors);
  }

  Future<Option<A>> unsafeRun<A>(IO<A> io) async {

    try {
      switch(await eval(io)) {
        case Ok(value: var value):
          return value;
        case Failure(failure: var failure):
          //debugPrintStack(stackTrace: StackTrace.current, label: 'IOApp', maxFrames: 10);
          return throw failure;
      }
    } catch(err, stacktrace){
      print("Error $err:\n $stacktrace");
      debugPrintStack(stackTrace: stacktrace, label: 'IOApp', maxFrames: 10);
      return throw err;
    }
  }

  Future<Option<List>> unsafeRunMany(List<IO> items, {bool continueOnError = true, int? maxParallelism}) async {
    final results = List.filled(items.length, null);
    final completer = Completer<Option<List>>();
    var completed = 0;

    // Função para processar um item
    void processItem(int index) {

      _runtime.execute(() async {

        if(completer.isCompleted) return;

        var r = await eval(items[index]);
        switch (r) {
          case Ok(:var value) when value.nonEmpty:
          //print("index=$index");
            results[index] = value.get();
            completed++;
            if (completed == items.length) {
              if(completer.isCompleted) return;
              completer.complete(results.liftOption);
            }
            break;
          case Ok _:
            if(completer.isCompleted) return;
            completer.complete(None());
            break;
          case Failure(:var err):
            if(completer.isCompleted) return;
            completer.completeError(err);
            break;
        }
      });
    }

    final max = maxParallelism ?? _runtime.workerCount;
    // Distribuir tarefas inicialmente
    for (var i = 0; i < items.length && i < max; i++) {
      final index = i;
      processItem(index);
    }

    var nextIndex = max;
    // Adicionar callbacks para work stealing
    _runtime.onIdle = () {
      if (nextIndex < items.length) {
        final index = nextIndex++;
        processItem(index);
      }
    };

    return await completer.future;
  }

  Result<Option<A>> _resultOf<A>(A value) => Result.ok(Option.of(value));

  Future<Result<Option<A>>> _tryExec<A>(FutureOr<A> Function() f) =>
      Result.fromAsync(() async => Option.ofAsync(await f()));


  Future<Result<Option<A>>> eval<A>(IO<A> io) async {
    return switch(io){
      IOPure pt => _resultOf(pt.computation()),
      IOAttempt pt => _tryExec(() async => await pt.apply()),
      IOMap pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty => _resultOf(pt.apply(value.get())),
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOFlatMap pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty =>
            switch(await eval(pt.apply(value.get()))){
              Ok(:var value) => Result.ok(value.cast()),
              Failure(:var failure) => Result.failure(failure)
            },
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOFold pt =>
        Result.ok(pt.items.fold(pt.initialValue, pt.apply).liftOption),
      IOAndThan pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty =>
          switch(await eval(pt.computation())){
            Ok(:var value) => Result.ok(value.cast()),
            Failure(:var failure) => Result.failure(failure)
          },
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOForeach pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty => _tap(pt.apply(value.get()), Result.ok(value.cast())),
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOFilter pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty => Result.ok(pt.apply(value.get()) ? value.cast() : None()),
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOFilterWith pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty =>
            switch(await eval(pt.apply(value.get()))){
              Ok(value: Some(value: var b)) => Result.ok(b ? value.cast() : None()),
              Ok _ => Result.ok(None()),
              Failure(:var failure) => Result.failure(failure)
            },
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOOr pt =>
        switch(await eval(pt.last)){
          Ok(value: None()) => _resultOf(pt.value),
          Ok(:var value) => Result.ok(value.cast()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOOrElse pt =>
        switch(await eval(pt.last)){
          Ok(value: None()) =>
            switch(await eval(pt.computation())){
              Ok(:var value) => Result.ok(value.cast()),
              Failure(:var failure) => Result.failure(failure)
            },
          Ok(:var value) => Result.ok(value.cast()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOCatchAll pt =>
        switch(await eval(pt.last)){
          Ok(:var value) => Result.ok(value.cast()),
          Failure(:var failure) => _tap(pt.computation(failure), Result.failure(failure))
        },
      IORecover pt =>
        switch(await eval(pt.last)){
          Ok(:var value) => Result.ok(value.cast()),
          Failure(:var failure) => _resultOf(pt.computation(failure))
        },
      IORecoverWith pt =>
        switch(await eval(pt.last)){
          Ok(:var value) => Result.ok(value.cast()),
          Failure(:var failure) =>
          switch(await eval(pt.computation(failure))){
            Ok(:var value) => Result.ok(value.cast()),
            Failure(:var failure) => Result.failure(failure)
          }
        },
      IOTraverseM pt =>
          switch(await _traverseM(pt.items,  pt.maxParallelism, pt.apply)){
            Ok(:var value)  => Result.ok(value.map((x) => pt.convert(x) as A)),
            Failure(:var failure) => Result.failure(failure)
          },
      IOTraverse pt =>
        switch(await _traverse(pt.items,  pt.maxParallelism, pt.apply)){
          Ok(:var value)  => Result.ok(value.map((x) => pt.convert(x) as A)),
          Failure(:var failure) => Result.failure(failure)
        },
      IORaceM pt =>
          switch(await _raceM(pt.items, pt.ignoreErrors)){
            Ok(:var value)  => Result.ok(value.cast()),
            Failure(:var failure) => Result.failure(failure)
          },
      IORace pt =>
        switch(await _race(pt.items, pt.ignoreErrors, pt.apply)){
          Ok(:var value)  => Result.ok(value.cast()),
          Failure(:var failure) => Result.failure(failure)
        },
      IODebug pt =>
        switch(await eval(pt.last)){
          Ok(:var value)  => _debug(pt.last.runtimeType, pt.label ?? "??", "$value", Result.ok(value.cast())),
          Failure(:var failure) =>
              _debug(pt.last.runtimeType, pt.label ?? "??", "$failure", Result.failure(failure))
        },
      IORetry pt => await _retry(pt.last.cast(), pt.retryCount, pt.interval),
      IOSleep pt => await _sleep(pt.last.cast(), pt.duration),
      IOTimeout pt => await _timeout(pt.last.cast(), pt.duration),
      IORateLimit pt => await _rateLimit(pt.last.cast(), pt.rateInterval),
      IOFailWith pt =>
        switch(await eval(pt.last)){
          Ok(value: Some(:var value))  =>
            switch (await pt.computation(value)) {
              null => Result.ok(value.cast()),
              Exception ex => Result.failure(ex)
            },
          Ok(value: None()) => Result.ok(None()),
          Failure(:var failure) =>
              Result.failure(failure)
        },
      IOFromError pt => Result.failure(pt.err)
    };
  }

  Future<Result<Option<A>>> _rateLimit<A>(IO<A> io, Duration interval) async {
    final future = Future.delayed(interval);
    return switch(await eval(io)){
      Failure(:var failure) => Result.failure(failure),
      Ok(:var value) => future.then((_) => Result.ok(value))
    };
  }

  Future<Result<Option<A>>> _retry<A>(IO<A> io, int retryCount, Duration interval) async {
    return switch(await eval(io)){
      Failure(:var failure) =>
        retryCount == 1 ? Result.failure(failure) : _tap(await Future.delayed(interval), _retry(io, --retryCount, interval)),
      Ok(:var value) => Result.ok(value)
    };
  }

  Future<Result<Option<A>>> _sleep<A>(IO<A> io, Duration duration) async {
    return switch(await eval(io)){
      Failure(:var failure) => Result.failure(failure),
      Ok(:var value) => _tap(await Future.delayed(duration), Result.ok(value))
    };
  }

  Future<Result<Option<A>>> _timeout<A>(IO<A> io, Duration duration) async {
    return eval(io)
        .timeout(duration)
        .catchError((err) => Result.failure<Option<A>>(err));
  }

  Future<Result<Option<List<B>>>> _traverseM<A, B>(List<A> items, int? maxParallelism, IO<B> Function(A) f) async {
    final results = List<B?>.filled(items.length, null);
    final completer = Completer<Option<List<B>>>();
    var completed = 0;

    // Função para processar um item
    void processItem(int index) {

      _runtime.execute(() async {

        if(completer.isCompleted) return;

        var r = await eval(f(items[index]));
        switch (r) {
          case Ok(:var value) when value.nonEmpty:
            //print("index=$index");
            results[index] = value.get();
            completed++;
            if (completed == items.length) {
              if(completer.isCompleted) return;
              completer.complete(results.cast<B>().liftOption);
            }
            break;
          case Ok _:
            if(completer.isCompleted) return;
            completer.complete(None());
            break;
          case Failure(:var err):
            if(completer.isCompleted) return;
            completer.completeError(err);
            break;
        }
      });
    }

    final max = maxParallelism ?? _runtime.workerCount;
    // Distribuir tarefas inicialmente
    for (var i = 0; i < items.length && i < max; i++) {
      final index = i;
      processItem(index);
    }

    var nextIndex = max;
    // Adicionar callbacks para work stealing
    _runtime.onIdle = () {
      if (nextIndex < items.length) {
        final index = nextIndex++;
        processItem(index);
      }
    };

    try{
      final ok = (await completer.future).liftOk;
      return ok;
    } on Exception catch (err, _){
      return Result.failure(err);
    } on Object catch (err, _) {
      return Result.failure(Exception("$err"));
    }
  }


  Future<Result<Option<List<B>>>> _traverse<A, B>(
      List<A> items, int? maxParallelism, FutureOr<B> Function(A) f) async {
    final results = List<B?>.filled(items.length, null);
    final completer = Completer<Option<List<B>>>();
    var completed = 0;

    // Função para processar um item
    void processItem(int index) {
      _runtime.execute(() async {
        if (completer.isCompleted) return;
        try {
          results[index] = await f(items[index]);
          completed++;
          if (completed == items.length) {
            if (completer.isCompleted) return;
            completer.complete(results
                .cast<B>()
                .liftOption);
          }
        } catch (err) {
          if (completer.isCompleted) return;
          completer.completeError(err);
        }
      });
    }

    final max = maxParallelism ?? _runtime.workerCount;
    // Distribuir tarefas inicialmente
    for (var i = 0; i < items.length && i < max; i++) {
      final index = i;
      processItem(index);
    }

    var nextIndex = max;
    // Adicionar callbacks para work stealing
    _runtime.onIdle = () {
      if (nextIndex < items.length) {
        final index = nextIndex++;
        processItem(index);
      }
    };

    try{
      final ok = (await completer.future).liftOk;
      return ok;
    } on Exception catch (err, _){
      return Result.failure(err);
    } on Object catch (err, _) {
      return Result.failure(Exception("$err"));
    }
  }

  Future<Result<Option<A>>> _raceM<A>(
      List<IO<A>> items, bool ignoreErrors) async {
    final completer = Completer<Option<A>>();

    for(var io in items){
      final runnable = io;
      _runtime.execute(() async {

        if(completer.isCompleted) return;

        switch(await eval(runnable)){
           case Ok(:var value) when value.nonEmpty:
             if(completer.isCompleted) return;
            completer.complete(value);
            break;
          case Ok _: // pass
            break;
          case Failure(:var failure):
            if(!ignoreErrors){
              if(completer.isCompleted) return;
              completer.completeError(failure);
              }
            break;
        }
      });
    }

    try{
      return (await completer.future).liftOk;
    } on Exception catch (err, _){
      return Result.failure(err);
    } catch(err){
      return Result.failure(Exception("$err"));
    }
  }

  Future<Result<Option<B>>> _race<A,B>(
      List<A> items, bool ignoreErrors, FutureOr<B> Function(A) f) async {
    final completer = Completer<Option<B>>();

    for(var i in items){
      final n = i;
      _runtime.execute(() async {

        if(completer.isCompleted) return;

        try {
          final result = await f(n);
          if(completer.isCompleted) return;
          completer.complete(Option.of(result));
        } on Exception catch(err, _) {
          if(!ignoreErrors){
            if(completer.isCompleted) return;
            completer.completeError(err);
          }
        } catch(err){
          if(!ignoreErrors){
            if(completer.isCompleted) return;
            completer.completeError(Exception("$err"));
          }
        }

      });
    }

    try{
      return (await completer.future).liftOk;
    } on Exception catch (err, _){
      return Result.failure(err);
    } catch(err){
      return Result.failure(Exception("$err"));
    }
  }

  void dispose() {
    _runtime.dispose();
  }

  Map<String, dynamic> get stats => _runtime.stats;
}

T _tap<T>(dynamic unused, T result) => result;

T _debug<T>(Type typ, String label, String msg, T value) {
  log("::> DEBUG [$typ($label)]: $msg");
  return value;
}

