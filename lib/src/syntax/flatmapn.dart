import 'package:dartz/src/io.dart';

// MapN2
extension FlatMapN2<A, B> on (IO<A>, IO<B>) {
  IO<C> flatmapN<C>(IO<C> Function(A, B) f) {
    var (ioa, iob) = this;
    return ioa.flatMap((a) => iob.flatMap((b) => f(a, b)));
  }
}

// Para 3 elementos
extension FlatMapN3<A, B, C> on (IO<A>, IO<B>, IO<C>) {
  IO<D> flatmapN<D>(IO<D> Function(A, B, C) f) {
    var (ioa, iob, ioc) = this;
    return ioa.flatMap(
      (a) => iob.flatMap(
        (b) => ioc.flatMap(
          (c) => f(a, b, c),
        ),
      ),
    );
  }
}

// Para 4 elementos
extension FlatMapN4<A, B, C, D> on (IO<A>, IO<B>, IO<C>, IO<D>) {
  IO<E> flatmapN<E>(IO<E> Function(A, B, C, D) f) {
    var (ioa, iob, ioc, iod) = this;
    return ioa.flatMap(
      (a) => iob.flatMap(
        (b) => ioc.flatMap(
          (c) => iod.flatMap(
            (d) => f(a, b, c, d),
          ),
        ),
      ),
    );
  }
}

// Para 5 elementos
extension FlatMapN5<A, B, C, D, E> on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>) {
  IO<F> flatmapN<F>(IO<F> Function(A, B, C, D, E) f) {
    var (ioa, iob, ioc, iod, ioe) = this;
    return ioa.flatMap(
      (a) => iob.flatMap(
        (b) => ioc.flatMap(
          (c) => iod.flatMap(
            (d) => ioe.flatMap(
              (e) => f(a, b, c, d, e),
            ),
          ),
        ),
      ),
    );
  }
}

// Para 6 elementos
extension FlatMapN6<A, B, C, D, E, F> on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>, IO<F>) {
  IO<G> flatmapN<G>(IO<G> Function(A, B, C, D, E, F) f) {
    var (ioa, iob, ioc, iod, ioe, iof) = this;
    return ioa.flatMap(
      (a) => iob.flatMap(
        (b) => ioc.flatMap(
          (c) => iod.flatMap(
            (d) => ioe.flatMap(
              (e) => iof.flatMap(
                (f0) => f(a, b, c, d, e, f0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Para 7 elementos
extension FlatMapN7<A, B, C, D, E, F, G> on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>, IO<F>, IO<G>) {
  IO<H> flatmapN<H>(IO<H> Function(A, B, C, D, E, F, G) f) {
    var (ioa, iob, ioc, iod, ioe, iof, iog) = this;
    return ioa.flatMap(
      (a) => iob.flatMap(
        (b) => ioc.flatMap(
          (c) => iod.flatMap(
            (d) => ioe.flatMap(
              (e) => iof.flatMap(
                (f0) => iog.flatMap(
                  (g) => f(a, b, c, d, e, f0, g),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Para 8 elementos
extension FlatMapN8<A, B, C, D, E, F, G, H> on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>, IO<F>, IO<G>, IO<H>) {
  IO<I> flatmapN<I>(IO<I> Function(A, B, C, D, E, F, G, H) f) {
    var (ioa, iob, ioc, iod, ioe, iof, iog, ioh) = this;
    return ioa.flatMap(
      (a) => iob.flatMap(
        (b) => ioc.flatMap(
          (c) => iod.flatMap(
            (d) => ioe.flatMap(
              (e) => iof.flatMap(
                (f0) => iog.flatMap(
                  (g) => ioh.flatMap(
                    (h) => f(a, b, c, d, e, f0, g, h),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Para 9 elementos
extension FlatMapN9<A, B, C, D, E, F, G, H, I>
on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>, IO<F>, IO<G>, IO<H>, IO<I>) {
  IO<J> flatmapN<J>(IO<J> Function(A, B, C, D, E, F, G, H, I) f) {
    var (ioa, iob, ioc, iod, ioe, iof, iog, ioh, ioi) = this;
    return ioa.flatMap(
      (a) => iob.flatMap(
        (b) => ioc.flatMap(
          (c) => iod.flatMap(
            (d) => ioe.flatMap(
              (e) => iof.flatMap(
                (f0) => iog.flatMap(
                  (g) => ioh.flatMap(
                    (h) => ioi.flatMap(
                      (i) => f(a, b, c, d, e, f0, g, h, i),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Para 10 elementos
extension FlatMapN10<A, B, C, D, E, F, G, H, I, J>
on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>, IO<F>, IO<G>, IO<H>, IO<I>, IO<J>) {
  IO<K> flatmapN<K>(IO<K> Function(A, B, C, D, E, F, G, H, I, J) f) {
    var (ioa, iob, ioc, iod, ioe, iof, iog, ioh, ioi, ioj) = this;
    return ioa.flatMap(
      (a) => iob.flatMap(
        (b) => ioc.flatMap(
          (c) => iod.flatMap(
            (d) => ioe.flatMap(
              (e) => iof.flatMap(
                (f0) => iog.flatMap(
                  (g) => ioh.flatMap(
                    (h) => ioi.flatMap(
                      (i) => ioj.flatMap(
                        (j) => f(a, b, c, d, e, f0, g, h, i, j),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}