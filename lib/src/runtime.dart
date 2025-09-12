import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dartz/dartz.dart';

class Runtime {
  final int workerCount;
  late final List<Queue<Function()>> _workerQueues;
  late final List<bool> _workerBusy;
  late final List<Completer<void>> _idleCompleters;
  Timer? _stealingTimer;

  Function()? onIdle;

  Runtime({this.workerCount = 4}) {
    _workerQueues = List.generate(workerCount, (_) => Queue());
    _workerBusy = List.filled(workerCount, false);
    _idleCompleters = List.generate(workerCount, (_) => Completer<void>()..complete());
  }

  static Runtime defaultExecutor() {
    return Runtime(workerCount: Platform.numberOfProcessors);
  }

  // Executar uma tarefa no executor
  void execute(Function() task, {int? preferredWorker}) {
    ////_lock.synchronized(() async {
      final workerId = preferredWorker ?? _findLeastBusyWorker();
      _workerQueues[workerId].add(task);
      _tryStartWorker(workerId);
    //});
  }

  // Encontrar o worker menos ocupado
  int _findLeastBusyWorker() {
    var minQueue = _workerQueues[0].length;
    var candidate = 0;
//
    for (var i = 1; i < workerCount; i++) {
      if (_workerQueues[i].length < minQueue) {
        minQueue = _workerQueues[i].length;
        candidate = i;
      }
    }

    return candidate;
  }

  // Tentar iniciar um worker
  void _tryStartWorker(int workerId) {
    if (!_workerBusy[workerId] && _workerQueues[workerId].isNotEmpty) {
      _workerBusy[workerId] = true;
      _idleCompleters[workerId] = Completer<void>();
      _executeOnWorker(workerId);
    }
  }

  // Executar tarefas em um worker específico
  void _executeOnWorker(int workerId) {
    Future.microtask(() async {
      while (true) {

        final task = await _nextTask(workerId);

        if (task == null) break;

        try {
          task();
        } catch (error) {
          print('Error in worker $workerId: $error');
        }
      }
    });
  }

  Future<dynamic Function()?> _nextTask(int workerId) async {
    //final task = await _lock.synchronized(() async {
      if (_workerQueues[workerId].isEmpty) {
        // Tentar roubar trabalho de outros workers
        final stolenTask = _tryStealWork(workerId);
        if (stolenTask == null) {
          _workerBusy[workerId] = false;
          _idleCompleters[workerId].complete();
          onIdle?.call();
          return null;
        }
        return stolenTask;
      }
      return _workerQueues[workerId].removeFirst();
    //});
  }

  // Tentar roubar trabalho de outros workers
  Function()? _tryStealWork(int thiefWorkerId) {
    for (var i = 0; i < workerCount; i++) {
      final victimWorkerId = (i + thiefWorkerId) % workerCount;

      if (victimWorkerId != thiefWorkerId &&
          _workerQueues[victimWorkerId].length > 1) {

        final stolenTask = _workerQueues[victimWorkerId].removeLast();
        return stolenTask;
      }
    }

    return null;
  }

  // Esperar até que todas as tarefas sejam concluídas
  Future<void> waitForCompletion() {
    return Future.wait(_idleCompleters.map((c) => c.future));
  }

  // Obter estatísticas do executor
  Map<String, dynamic> get stats {
    return {
      'workerCount': workerCount,
      'queueSizes': _workerQueues.map((q) => q.length).toList(),
      'busyWorkers': _workerBusy.where((busy) => busy).length,
    };
  }

  Future<Option<List>> evalMany(List<IO> items, {bool continueOnError = true, int? maxParallelism}) async {
    final results = List.filled(items.length, null);
    final completer = Completer<Option<List>>();
    var completed = 0;

    // Função para processar um item
    void processItem(int index) {

      execute(() async {

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

    final max = maxParallelism ?? workerCount;
    // Distribuir tarefas inicialmente
    for (var i = 0; i < items.length && i < max; i++) {
      final index = i;
      processItem(index);
    }

    var nextIndex = max;
    // Adicionar callbacks para work stealing
    onIdle = () {
      if (nextIndex < items.length) {
        final index = nextIndex++;
        processItem(index);
      }
    };

    return await completer.future;
  }

  Result<Option<A>> _resultOf<A>(A value) => Result.ok(Option.of(value));

  Future<Result<Option<A>>> _tryExec<A>(FutureOr<A> Function() f) =>
      Result.of(() async => Option.ofAsync(await f()));


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
          Result.ok(pt.items
              .fold(pt.initialValue, pt.apply)
              .liftOption),
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
        Ok(:var value) when value.nonEmpty =>
            _tap(pt.apply(value.get()), Result.ok(value.cast())),
        Ok _ => Result.ok(None()),
        Failure(:var failure) => Result.failure(failure)
      },
      IOFilter pt =>
      switch(await eval(pt.last)){
        Ok(:var value) when value.nonEmpty =>
            Result.ok(pt.apply(value.get()) ? value.cast() : None()),
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
        Failure failure => _tap(pt.computation(failure.failure), Result.failure<Option<A>>(failure.failure))
      },
      IORecover pt =>
      switch(await eval(pt.last)){
        Ok(:var value) => Result.ok(value.cast()),
        Failure failure => _resultOf(pt.computation(failure.failure))
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
      switch(await _traverseM(pt.items, pt.maxParallelism, pt.apply)){
        Ok(:var value) => Result.ok(value.map((x) => pt.convert(x) as A)),
        Failure(:var failure) => Result.failure(failure)
      },
      IOTraverse pt =>
      switch(await _traverse(pt.items, pt.maxParallelism, pt.apply)){
        Ok(:var value) => Result.ok(value.map((x) => pt.convert(x) as A)),
        Failure(:var failure) => Result.failure(failure)
      },
      IORaceM pt =>
      switch(await _raceM(pt.items, pt.ignoreErrors)){
        Ok(:var value) => Result.ok(value.cast()),
        Failure(:var failure) => Result.failure(failure)
      },
      IORace pt =>
      switch(await _race(pt.items, pt.ignoreErrors, pt.apply)){
        Ok(:var value) => Result.ok(value.cast()),
        Failure(:var failure) => Result.failure(failure)
      },
      IODebug pt =>
      switch(await eval(pt.last)){
        Ok(:var value) =>
            _debug(
            pt.last.runtimeType, pt.label ?? "??", "$value",
            Result.ok(value.cast())),
        Failure failure =>
            _debug(pt.last.runtimeType, pt.label ?? "??", "$failure",
                failure.cast())
      },
      IORetry pt =>
      await _retry(pt.last.cast(), pt.retryCount, pt.interval, null),
      IORetryIf pt =>
      await _retry(pt.last.cast(), pt.retryCount, pt.interval, pt.computation),
      IOSleep pt => await _sleep(pt.last.cast(), pt.duration),
      IOTimeout pt => await _timeout(pt.last.cast(), pt.duration),
      IORateLimit pt => await _rateLimit(pt.last.cast(), pt.rateInterval),
      IOFailWith pt =>
      switch(await eval(pt.last)){
        Ok(value: Some(:var value)) =>
        switch (await pt.apply(value)) {
          Exception ex => Result.failure(ex),
          _ => Result.ok( Option.of(value) ).cast()
        },
        Ok ok => ok.cast(),
        Failure(:var failure) => Result.failure(failure)
      },
      IOFailIf pt =>
          eval(pt.last).then((r) =>
              r.flatMap((opt) =>
                  opt.map(pt.apply)
                      .filter(identity)
                      .map((_) => Result.failure<Option<A>>(pt.exception))
                      .or(Result.ok<Option<A>>(opt.map((x) => x as A)))
          )),

    /*switch(await eval(pt.last)){
        Ok(value: Some(:var value))  =>
            pt.computation(value) ? Result.failure(pt.exception) : Result.ok(Some(value)),
        Ok(value: None()) => Result.ok(None()),
        Failure(:var failure) => Result.failure(failure      },*/
      IOFromError pt => Result.failure(pt.err),
      IOEnsure pt =>
        _tap0(await eval(pt.last.cast()), await pt.computation()),
      IOEffect pt => _tryExec(() async => (await pt.computation()) as A),
      IOTouch pt =>
        (await eval(pt.last.cast())).flatMapAsync((opt) {

          return Result.of(() async {
            if(opt.nonEmpty) {
              await pt.apply(opt.value);
            }
            return opt.cast();
          });
        }),
      IOToUnit pt =>
        (await eval(pt.last)).map((_) => Option.of(Unit()).cast())
    };
  }

  Future<Result<Option<A>>> _rateLimit<A>(IO<A> io, Duration interval) async {
    final future = Future.delayed(interval);
    return switch(await eval(io)){
      Failure(:var failure) => Result.failure(failure),
      Ok(:var value) => future.then((_) => Result.ok(value))
    };
  }

  Future<Result<Option<A>>> _retry<A>(IO<A> io, int retryCount, Duration interval, FutureOr<bool> Function(A)? computation) async {

    Future<Result<Option<A>>> doRetry() async {
      await Future.delayed(interval);
      return _retry(io, --retryCount, interval, computation);
    }

    return switch(await eval(io)){
      Failure failure => retryCount == 1 ? failure.cast() : doRetry(),
      Ok(value: Some(:var value)) =>
        computation != null && await computation(value) ? doRetry() : Result.ok(Some(value)),
      Ok(:var value) => value.liftOk
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
        .catchError((err, stackTrace) => Result.failure<Option<A>>(err, stackTrace));
  }

  Future<Result<Option<List<B>>>> _traverseM<A, B>(List<A> items, int? maxParallelism, IO<B> Function(A) f) async {
    final results = List<B?>.filled(items.length, null);
    final completer = Completer<Option<List<B>>>();
    var completed = 0;

    // Função para processar um item
    void processItem(int index) {

      execute(() async {

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
          case Failure failure:
            if(completer.isCompleted) return;
            completer.completeError(failure.failure, failure.stackTrace);
            break;
        }
      });
    }

    final max = maxParallelism ?? workerCount;
    // Distribuir tarefas inicialmente
    for (var i = 0; i < items.length && i < max; i++) {
      final index = i;
      processItem(index);
    }

    var nextIndex = max;
    // Adicionar callbacks para work stealing
    onIdle = () {
      if (nextIndex < items.length) {
        final index = nextIndex++;
        processItem(index);
      }
    };

    try{
      final ok = (await completer.future).liftOk;
      return ok;
    } on Exception catch (err, stackTrace){
      return Result.failure(err, stackTrace);
    } on Object catch (err, stackTrace) {
      return Result.failure(Exception("$err"), stackTrace);
    }
  }


  Future<Result<Option<List<B>>>> _traverse<A, B>(
      List<A> items, int? maxParallelism, FutureOr<B> Function(A) f) async {
    final results = List<B?>.filled(items.length, null);
    final completer = Completer<Option<List<B>>>();
    var completed = 0;

    // Função para processar um item
    void processItem(int index) {
      execute(() async {
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
        } catch (err, stackTrace) {
          if (completer.isCompleted) return;
          completer.completeError(err, stackTrace);
        }
      });
    }

    final max = maxParallelism ?? workerCount;
    // Distribuir tarefas inicialmente
    for (var i = 0; i < items.length && i < max; i++) {
      final index = i;
      processItem(index);
    }

    var nextIndex = max;
    // Adicionar callbacks para work stealing
    onIdle = () {
      if (nextIndex < items.length) {
        final index = nextIndex++;
        processItem(index);
      }
    };

    try{
      final ok = (await completer.future).liftOk;
      return ok;
    } on Exception catch (err, stackTrace){
      return Result.failure(err, stackTrace);
    } on Object catch (err, stackTrace) {
      return Result.failure(Exception("$err"), stackTrace);
    }
  }

  Future<Result<Option<A>>> _raceM<A>(
      List<IO<A>> items, bool ignoreErrors) async {
    final completer = Completer<Option<A>>();

    for(var io in items){
      final runnable = io;
      execute(() async {

        if(completer.isCompleted) return;

        switch(await eval(runnable)){
          case Ok(:var value) when value.nonEmpty:
            if(completer.isCompleted) return;
            completer.complete(value);
            break;
          case Ok _: // pass
            break;
          case Failure failure:
            if(!ignoreErrors){
              if(completer.isCompleted) return;
              completer.completeError(failure.failure, failure.stackTrace);
            }
            break;
        }
      });
    }

    try{
      return (await completer.future).liftOk;
    } on Exception catch (err, stackTrace){
      return Result.failure(err, stackTrace);
    } catch(err, stackTrace){
      return Result.failure(Exception("$err"), stackTrace);
    }
  }

  Future<Result<Option<B>>> _race<A,B>(
      List<A> items, bool ignoreErrors, FutureOr<B> Function(A) f) async {
    final completer = Completer<Option<B>>();

    for(var i in items){
      final n = i;
      execute(() async {

        if(completer.isCompleted) return;

        try {
          final result = await f(n);
          if(completer.isCompleted) return;
          completer.complete(Option.of(result));
        } on Exception catch(err, stackTrace) {
          if(!ignoreErrors){
            if(completer.isCompleted) return;
            completer.completeError(err, stackTrace);
          }
        } catch(err, stackTrace){
          if(!ignoreErrors){
            if(completer.isCompleted) return;
            completer.completeError(Exception("$err"), stackTrace);
          }
        }

      });
    }

    try{
      return (await completer.future).liftOk;
    } on Exception catch (err, stackTrace){
      return Result.failure(err, stackTrace);
    } catch(err, stackTrace){
      return Result.failure(Exception("$err"), stackTrace);
    }
  }

  void dispose() {
    _stealingTimer?.cancel();
  }

  T _tap<T>(dynamic unused, T result) => result;
  T _tap0<T>(T result, dynamic unused) => result;

  T _debug<T>(Type typ, String label, String msg, T value) {
    print("::> DEBUG [$typ($label)]: $msg");
    return value;
  }
}

