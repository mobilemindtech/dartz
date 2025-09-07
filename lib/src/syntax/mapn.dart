import 'package:dartz/src/io.dart';

// MapN2
extension MapN2<A, B, C> on (IO<A>, IO<B>) {
  IO<C> mapN(C Function(A, B) f) {
    var (ioa, iob) = this;
    return ioa.flatMap((a) => iob.map((b) => f(a, b)));
  }
}

// MapN3
extension MapN3<A, B, C, D> on (IO<A>, IO<B>, IO<C>) {
  IO<D> mapN(D Function(A, B, C) f) {
    var (ioa, iob, ioc) = this;
    return ioa.flatMap(
            (a) => iob.flatMap(
                (b) => ioc.map((c) => f(a, b, c))
        )
    );
  }
}

// MapN4
extension MapN4<A, B, C, D, E> on (IO<A>, IO<B>, IO<C>, IO<D>) {
  IO<E> mapN(E Function(A, B, C, D) f) {
    var (ioa, iob, ioc, iod) = this;
    return ioa.flatMap(
            (a) => iob.flatMap(
                (b) => ioc.flatMap(
                    (c) => iod.map((d) => f(a, b, c, d))
            )
        )
    );
  }
}

// MapN5
extension MapN5<A, B, C, D, E, F> on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>) {
  IO<F> mapN(F Function(A, B, C, D, E) f) {
    var (ioa, iob, ioc, iod, ioe) = this;
    return ioa.flatMap(
            (a) => iob.flatMap(
                (b) => ioc.flatMap(
                    (c) => iod.flatMap(
                        (d) => ioe.map((e) => f(a, b, c, d, e))
                )
            )
        )
    );
  }
}

// MapN6
extension MapN6<A, B, C, D, E, F, G> on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>, IO<F>) {
  IO<G> mapN(G Function(A, B, C, D, E, F) f) {
    var (ioa, iob, ioc, iod, ioe, iof) = this;
    return ioa.flatMap(
            (a) => iob.flatMap(
                (b) => ioc.flatMap(
                    (c) => iod.flatMap(
                        (d) => ioe.flatMap(
                            (e) => iof.map((f0) => f(a, b, c, d, e, f0))
                    )
                )
            )
        )
    );
  }
}

// MapN7
extension MapN7<A, B, C, D, E, F, G, H>
on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>, IO<F>, IO<G>) {
  IO<H> mapN(H Function(A, B, C, D, E, F, G) f) {
    var (ioa, iob, ioc, iod, ioe, iof, iog) = this;
    return ioa.flatMap(
            (a) => iob.flatMap(
                (b) => ioc.flatMap(
                    (c) => iod.flatMap(
                        (d) => ioe.flatMap(
                            (e) => iof.flatMap(
                                (f0) => iog.map((g) => f(a, b, c, d, e, f0, g))
                        )
                    )
                )
            )
        )
    );
  }
}

// MapN8
extension MapN8<A, B, C, D, E, F, G, H, I>
on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>, IO<F>, IO<G>, IO<H>) {
  IO<I> mapN(I Function(A, B, C, D, E, F, G, H) f) {
    var (ioa, iob, ioc, iod, ioe, iof, iog, ioh) = this;
    return ioa.flatMap(
            (a) => iob.flatMap(
                (b) => ioc.flatMap(
                    (c) => iod.flatMap(
                        (d) => ioe.flatMap(
                            (e) => iof.flatMap(
                                (f0) => iog.flatMap(
                                    (g) => ioh.map((h) => f(a, b, c, d, e, f0, g, h))
                            )
                        )
                    )
                )
            )
        )
    );
  }
}

// MapN9
extension MapN9<A, B, C, D, E, F, G, H, I, J>
on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>, IO<F>, IO<G>, IO<H>, IO<I>) {
  IO<J> mapN(J Function(A, B, C, D, E, F, G, H, I) f) {
    var (ioa, iob, ioc, iod, ioe, iof, iog, ioh, ioi) = this;
    return ioa.flatMap(
            (a) => iob.flatMap(
                (b) => ioc.flatMap(
                    (c) => iod.flatMap(
                        (d) => ioe.flatMap(
                            (e) => iof.flatMap(
                                (f0) => iog.flatMap(
                                    (g) => ioh.flatMap(
                                        (h) => ioi.map((i) => f(a, b, c, d, e, f0, g, h, i))
                                )
                            )
                        )
                    )
                )
            )
        )
    );
  }
}

// MapN10
extension MapN10<A, B, C, D, E, F, G, H, I, J, K>
on (IO<A>, IO<B>, IO<C>, IO<D>, IO<E>, IO<F>, IO<G>, IO<H>, IO<I>, IO<J>) {
  IO<K> mapN(K Function(A, B, C, D, E, F, G, H, I, J) f) {
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
                                            (i) => ioj.map((j) => f(a, b, c, d, e, f0, g, h, i, j))
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    );
  }
}
