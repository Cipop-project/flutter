// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:gen_keycodes/key_data.dart';
import 'package:gen_keycodes/utils.dart';

/// Generates the keyboard_keys.dart and keyboard_maps.dart files, based on the
/// information in the key data structure given to it.
class CodeGenerator {
  CodeGenerator(this.keyData);

  /// Given an [input] string, wraps the text at 80 characters and prepends each
  /// line with the [prefix] string. Use for generated comments.
  String wrapString(String input, String prefix) {
    final int wrapWidth = 80 - prefix.length;
    final StringBuffer result = StringBuffer();
    final List<String> words = input.split(RegExp(r'\s+'));
    String currentLine = words.removeAt(0);
    for (String word in words) {
      if ((currentLine.length + word.length) < wrapWidth) {
        currentLine += ' $word';
      } else {
        result.writeln('$prefix$currentLine');
        currentLine = '$word';
      }
    }
    if (currentLine.isNotEmpty) {
      result.writeln('$prefix$currentLine');
    }
    return result.toString();
  }

  /// Gets the generated definitions of PhysicalKeyboardKeys.
  String get physicalDefinitions {
    final StringBuffer definitions = StringBuffer();
    for (Key entry in keyData.data) {
      final String comment = wrapString('Represents the location of a '
        '"${entry.commentName}" key on a generalized keyboard. See the function '
        '[RawKeyEvent.physicalKey] for more information.', '  /// ');
      definitions.write('''

$comment  static const PhysicalKeyboardKey ${entry.constantName} = PhysicalKeyboardKey(${toHex(entry.usbHidCode, digits: 8)}, debugName: kReleaseMode ? null : '${entry.commentName}');
''');
    }
    return definitions.toString();
  }

  /// Gets the generated definitions of LogicalKeyboardKeys.
  String get logicalDefinitions {
    String escapeLabel(String label) => label.contains("'") ? 'r"$label"' : "r'$label'";
    final StringBuffer definitions = StringBuffer();
    for (Key entry in keyData.data) {
      final String comment = wrapString('Represents a logical "${entry.commentName}" key on the '
        'keyboard. See the function [RawKeyEvent.logicalKey] for more information.', '  /// ');
      if (entry.keyLabel == null) {
        definitions.write('''

$comment  static const LogicalKeyboardKey ${entry.constantName} = LogicalKeyboardKey(${toHex(entry.flutterId, digits: 11)}, debugName: kReleaseMode ? null : '${entry.commentName}');
''');
      } else {
        definitions.write('''

$comment  static const LogicalKeyboardKey ${entry.constantName} = LogicalKeyboardKey(${toHex(entry.flutterId, digits: 11)}, keyLabel: ${escapeLabel(entry.keyLabel)}, debugName: kReleaseMode ? null : '${entry.commentName}');
''');
      }
    }
    return definitions.toString();
  }

  /// This generates the map of USB HID codes to physical keys.
  String get predefinedHidCodeMap {
    final StringBuffer scanCodeMap = StringBuffer();
    for (Key entry in keyData.data) {
      scanCodeMap.writeln('    ${toHex(entry.usbHidCode)}: ${entry.constantName},');
    }
    return scanCodeMap.toString().trimRight();
  }

  /// THis generates the map of Flutter key codes to logical keys.
  String get predefinedKeyCodeMap {
    final StringBuffer keyCodeMap = StringBuffer();
    for (Key entry in keyData.data) {
      keyCodeMap.writeln('    ${toHex(entry.flutterId, digits: 10)}: ${entry.constantName},');
    }
    return keyCodeMap.toString().trimRight();
  }

  /// This generates the map of Android key codes to logical keys.
  String get androidKeyCodeMap {
    final StringBuffer androidKeyCodeMap = StringBuffer();
    for (Key entry in keyData.data) {
      if (entry.androidKeyCodes != null) {
        for (int code in entry.androidKeyCodes.cast<int>()) {
          androidKeyCodeMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return androidKeyCodeMap.toString().trimRight();
  }

  /// This generates the map of Android number pad key codes to logical keys.
  String get androidNumpadMap {
    final StringBuffer androidKeyCodeMap = StringBuffer();
    final List<Key> onlyNumpads = keyData.data.where((Key entry) {
      return entry.constantName.startsWith('numpad') && entry.keyLabel != null;
    }).toList();
    for (Key entry in onlyNumpads) {
      if (entry.androidKeyCodes != null) {
        for (int code in entry.androidKeyCodes.cast<int>()) {
          androidKeyCodeMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return androidKeyCodeMap.toString().trimRight();
  }

  /// This generates the map of Android scan codes to physical keys.
  String get androidScanCodeMap {
    final StringBuffer androidScanCodeMap = StringBuffer();
    for (Key entry in keyData.data) {
      if (entry.androidScanCodes != null) {
        for (int code in entry.androidScanCodes.cast<int>()) {
          androidScanCodeMap.writeln('  $code: PhysicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return androidScanCodeMap.toString().trimRight();
  }

  /// This generates the map of Fuchsia key codes to logical keys.
  String get fuchsiaKeyCodeMap {
    final StringBuffer fuchsiaKeyCodeMap = StringBuffer();
    for (Key entry in keyData.data) {
      if (entry.usbHidCode != null) {
        fuchsiaKeyCodeMap.writeln('  ${toHex(entry.flutterId)}: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return fuchsiaKeyCodeMap.toString().trimRight();
  }

  /// This generates the map of Fuchsia USB HID codes to physical keys.
  String get fuchsiaHidCodeMap {
    final StringBuffer fuchsiaScanCodeMap = StringBuffer();
    for (Key entry in keyData.data) {
      if (entry.usbHidCode != null) {
        fuchsiaScanCodeMap.writeln('  ${toHex(entry.usbHidCode)}: PhysicalKeyboardKey.${entry.constantName},');
      }
    }
    return fuchsiaScanCodeMap.toString().trimRight();
  }

  /// Substitutes the various maps and definitions into the template file for
  /// keyboard_key.dart.
  String generateKeyboardKeys() {
    final Map<String, String> mappings = <String, String>{
      'PHYSICAL_KEY_MAP': predefinedHidCodeMap,
      'LOGICAL_KEY_MAP': predefinedKeyCodeMap,
      'LOGICAL_KEY_DEFINITIONS': logicalDefinitions,
      'PHYSICAL_KEY_DEFINITIONS': physicalDefinitions,
    };

    final String template = File(path.join(flutterRoot.path, 'dev', 'tools', 'gen_keycodes', 'data', 'keyboard_key.tmpl')).readAsStringSync();
    return _injectDictionary(template, mappings);
  }

  /// Substitutes the various platform specific maps into the template file for
  /// keyboard_maps.dart.
  String generateKeyboardMaps() {
    final Map<String, String> mappings = <String, String>{
      'ANDROID_SCAN_CODE_MAP': androidScanCodeMap,
      'ANDROID_KEY_CODE_MAP': androidKeyCodeMap,
      'ANDROID_NUMPAD_MAP': androidNumpadMap,
      'FUCHSIA_SCAN_CODE_MAP': fuchsiaHidCodeMap,
      'FUCHSIA_KEY_CODE_MAP': fuchsiaKeyCodeMap,
    };

    final String template = File(path.join(flutterRoot.path, 'dev', 'tools', 'gen_keycodes', 'data', 'keyboard_maps.tmpl')).readAsStringSync();
    return _injectDictionary(template, mappings);
  }

  /// The database of keys loaded from disk.
  final KeyData keyData;

  static String _injectDictionary(String template, Map<String, String> dictionary) {
    String result = template;
    for (String key in dictionary.keys) {
      result = result.replaceAll('@@@$key@@@', dictionary[key]);
    }
    return result;
  }
}
