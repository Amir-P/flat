import 'package:flat_generator/misc/constants.dart';
import 'package:flat_generator/value_object/field.dart';
import 'package:test/test.dart';

import '../fakes.dart';

void main() {
  final fakeFieldElement = FakeFieldElement();

  test('Get database definition with auto generate primary key', () {
    const autoGenerate = true;
    final field = Field(
      fakeFieldElement,
      'field1Name',
      'field1ColumnName',
      false,
      SqlType.integer,
      null,
    );

    final actual = field.getDatabaseDefinition(autoGenerate: autoGenerate);

    final expected =
        '`${field.columnName}` ${field.sqlType} PRIMARY KEY AUTOINCREMENT NOT NULL';
    expect(actual, equals(expected));
  });

  test('Get database definition', () {
    const autoGenerate = false;
    final field = Field(
      fakeFieldElement,
      'field1Name',
      'field1ColumnName',
      true,
      SqlType.text,
      null,
    );

    final actual = field.getDatabaseDefinition(autoGenerate: autoGenerate);

    final expected = '`${field.columnName}` ${field.sqlType}';
    expect(actual, equals(expected));
  });

  test('Get database definition with forced nullability', () {
    const autoGenerate = false;
    final field = Field(
      fakeFieldElement,
      'field1Name',
      'field1ColumnName',
      false,
      SqlType.text,
      null,
    );

    final actual = field.getDatabaseDefinition(
        autoGenerate: autoGenerate, forceNullability: true);

    final expected = '`${field.columnName}` ${field.sqlType}';
    expect(actual, equals(expected));
  });
}
