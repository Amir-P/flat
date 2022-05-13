import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:flat_annotation/flat_annotation.dart';

extension DartObjectExtension on DartObject {
  /// get the String representation of the enum value,
  /// or `null` if the enum was not valid
  String? toEnumValueString(List enumValues) {
    final enumIndex = (type as InterfaceType)
        .element
        .fields
        .where((element) => element.isEnumConstant)
        .toList()
        .indexWhere((element) => element.computeConstantValue() == this);
    if (enumIndex == -1) {
      return null;
    } else {
      return enumValues[enumIndex].toString();
    }
  }

  /// get the ForeignKeyAction this enum represents,
  /// or the result of `null` if the enum did not contain a valid value
  ForeignKeyAction? toForeignKeyAction() {
    final enumValueString = toEnumValueString(ForeignKeyAction.values);
    if (enumValueString == null) {
      return null;
    } else {
      return ForeignKeyAction.values.singleWhereOrNull(
          (foreignKeyAction) => foreignKeyAction.toString() == enumValueString);
    }
  }
}
