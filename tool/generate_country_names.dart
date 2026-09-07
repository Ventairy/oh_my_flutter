import 'dart:io';

import 'country_names/country_names_generator.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.any((argument) => argument != '--check')) {
    throw const FormatException('Usage: fvm dart run tool/generate_country_names.dart [--check]');
  }
  stdout.writeln(await CountryNamesGenerator().run(Directory.current, check: arguments.contains('--check')));
}
