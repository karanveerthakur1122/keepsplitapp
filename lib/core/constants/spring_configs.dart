import 'package:flutter/physics.dart';

class SpringConfigs {
  SpringConfigs._();

  static const SpringDescription defaultSpring = SpringDescription(
    mass: 1,
    stiffness: 200,
    damping: 25,
  );

  static const SpringDescription gentleSpring = SpringDescription(
    mass: 1,
    stiffness: 120,
    damping: 20,
  );

  static const SpringDescription bouncySpring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 15,
  );

  static const SpringDescription quickSpring = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 30,
  );
}
