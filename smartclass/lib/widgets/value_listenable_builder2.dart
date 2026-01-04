import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';


class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(
    BuildContext context,
    A valueA,
    B valueB,
    Widget? child,
  ) builder;

  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (_, a, __) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (_, b, __) => builder(context, a, b, null),
        );
      },
    );
  }
}
