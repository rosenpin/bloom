import 'package:flutter/widgets.dart';

abstract final class AppRadii {
  static const double large = 28;
  static const double medium = 20;
  static const double small = 14;

  static const BorderRadius largeBorder = BorderRadius.all(
    Radius.circular(large),
  );
  static const BorderRadius mediumBorder = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius smallBorder = BorderRadius.all(
    Radius.circular(small),
  );
}
