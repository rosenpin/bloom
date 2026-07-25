// Smoke test for the codegen toolchain: freezed + json_serializable + riverpod.
// Delete once real models exist.
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'codegen_smoke.freezed.dart';
part 'codegen_smoke.g.dart';

@freezed
abstract class SmokeModel with _$SmokeModel {
  const factory SmokeModel({required String id, @Default(0) int count}) = _SmokeModel;

  factory SmokeModel.fromJson(Map<String, dynamic> json) => _$SmokeModelFromJson(json);
}

@riverpod
SmokeModel smoke(Ref ref) => const SmokeModel(id: 'ok');
