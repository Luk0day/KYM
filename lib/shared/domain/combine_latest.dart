import 'dart:async';

/// Combina duas streams: emite sempre que uma delas muda, depois que as duas
/// já emitiram ao menos uma vez. Erros de qualquer uma passam adiante. Dart
/// puro, para não depender do rxdart.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A a, B b) combine,
) => _combine<R>([a, b], (v) => combine(v[0] as A, v[1] as B));

/// Igual a [combineLatest2], para três streams.
Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(A a, B b, C c) combine,
) => _combine<R>([a, b, c], (v) => combine(v[0] as A, v[1] as B, v[2] as C));

Stream<R> _combine<R>(
  List<Stream<Object?>> sources,
  R Function(List<Object?> values) combine,
) {
  late StreamController<R> controller;
  final subscriptions = <StreamSubscription<Object?>>[];
  final values = List<Object?>.filled(sources.length, null);
  final ready = List<bool>.filled(sources.length, false);
  var finished = 0;

  controller = StreamController<R>(
    onListen: () {
      for (var i = 0; i < sources.length; i++) {
        subscriptions.add(
          sources[i].listen(
            (value) {
              values[i] = value;
              ready[i] = true;
              if (ready.every((r) => r)) {
                controller.add(combine(List<Object?>.of(values)));
              }
            },
            onError: controller.addError,
            onDone: () {
              finished++;
              if (finished == sources.length) controller.close();
            },
          ),
        );
      }
    },
    onCancel: () => Future.wait([for (final s in subscriptions) s.cancel()]),
  );
  return controller.stream;
}
