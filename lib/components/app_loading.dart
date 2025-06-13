// importは省略しています
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({
    super.key,
    this.dimension = 20,
    this.color = Colors.white,
  });

  final double dimension;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }
}