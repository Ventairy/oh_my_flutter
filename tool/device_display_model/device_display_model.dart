import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

part 'src/device_display_model_collector.dart';
part 'src/device_display_model_command.dart';
part 'src/device_display_model_candidates.dart';
part 'src/device_display_model_encoding.dart';
part 'src/device_display_model_generator.dart';
part 'src/device_display_model_models.dart';
part 'src/device_display_model_pipeline.dart';
part 'src/device_display_model_trainer.dart';
part 'src/device_display_model_validator.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await _DeviceDisplayModelCommand().run(arguments);
}
