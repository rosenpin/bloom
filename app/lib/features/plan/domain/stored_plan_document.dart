import 'package:programming_engine/programming_engine.dart' as engine;

import '../../../data/db/app_database.dart';

final class StoredPlanDocument {
  const StoredPlanDocument({required this.row, required this.plan});

  final StoredPlan row;
  final engine.Plan plan;
}
