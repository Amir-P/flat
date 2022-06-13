import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:flat_generator/misc/extension/field_element_extension.dart';
import 'package:flat_generator/processor/embedded_processor.dart';
import 'package:flat_generator/processor/error/queryable_processor_error.dart';
import 'package:flat_generator/processor/field_processor.dart';
import 'package:flat_generator/processor/queryable_processor.dart';
import 'package:flat_generator/value_object/embedded.dart';
import 'package:flat_generator/value_object/field.dart';
import 'package:flat_generator/value_object/queryable.dart';
import 'package:flat_generator/value_object/type_converter.dart';
import 'package:test/test.dart';

import '../dart_type.dart';
import '../test_utils.dart';

void main() {
  test('Process Queryable', () async {
    final classElement = await createClassElement('''
      class Person {
        final int id;
      
        final String name;
        
        @embedded
        final Address address;
      
        Person(this.id, this.name, this.address);
      }
      
      class Address {
        final String city;
        
        final String street;
        
        Address(this.city, this.street);
      }
    ''');

    final actual = TestProcessor(classElement).process();

    final fields = classElement.fields
        .where((fieldElement) => !fieldElement.isEmbedded())
        .map((fieldElement) => FieldProcessor(fieldElement, null).process())
        .toList();
    final embedded = classElement.fields
        .where((fieldElement) => fieldElement.isEmbedded())
        .map((fieldElement) => EmbeddedProcessor(fieldElement, {}).process())
        .toList();
    const constructor =
        "Person(row['id'] as int, row['name'] as String, Address(row['city'] as String, row['street'] as String))";
    final expected = TestQueryable(
      classElement,
      fields,
      embedded,
      constructor,
    );
    expect(actual, equals(expected));
  });

  group('type converters', () {
    test('process queryable with external type converter', () async {
      final typeConverter = TypeConverter(
        'TypeConverter',
        await dateTimeDartType,
        await intDartType,
        TypeConverterScope.database,
      );
      final classElement = await createClassElement('''
      class Order {
        final int id;

        final DateTime dateTime;
        
        @embedded
        final Product product;

        Order(this.id, this.dateTime, this.product);
      }
      
      class Product {
        final DateTime productionDate;
      
        Product(this.productionDate);
      }
    ''');

      final actual = TestProcessor(classElement, {typeConverter}).process();

      final idField = FieldProcessor(classElement.fields[0], null).process();
      final dateTimeField =
          FieldProcessor(classElement.fields[1], typeConverter).process();
      final fields = [idField, dateTimeField];
      final embedded = [
        EmbeddedProcessor(classElement.fields[2], {typeConverter}).process()
      ];
      const constructor =
          "Order(row['id'] as int, _typeConverter.decode(row['dateTime'] as int), Product(_typeConverter.decode(row['productionDate'] as int)))";
      final expected = TestQueryable(
        classElement,
        fields,
        embedded,
        constructor,
      );
      expect(actual, equals(expected));
    });

    test('process queryable with local type converter', () async {
      final classElement = await createClassElement('''
      @TypeConverters([DateTimeConverter])
      class Order {
        final int id;

        final DateTime dateTime;

        Order(this.id, this.dateTime);
      }

      class DateTimeConverter extends TypeConverter<DateTime, int> {
        @override
        DateTime decode(int databaseValue) {
          return DateTime.fromMillisecondsSinceEpoch(databaseValue);
        }

        @override
        int encode(DateTime value) {
          return value.millisecondsSinceEpoch;
        }
      }
    ''');

      final actual = TestProcessor(classElement).process();

      final typeConverter = TypeConverter(
        'DateTimeConverter',
        await dateTimeDartType,
        await intDartType,
        TypeConverterScope.queryable,
      );
      final idField = FieldProcessor(classElement.fields[0], null).process();
      final dateTimeField =
          FieldProcessor(classElement.fields[1], typeConverter).process();
      final fields = [idField, dateTimeField];
      const constructor =
          "Order(row['id'] as int, _dateTimeConverter.decode(row['dateTime'] as int))";
      final expected = TestQueryable(
        classElement,
        fields,
        [],
        constructor,
      );
      expect(actual, equals(expected));
    });

    test('process queryable and prefer local type converter over external',
        () async {
      final classElement = await createClassElement('''
      @TypeConverters([DateTimeConverter])
      class Order {
        final int id;

        final DateTime dateTime;

        @embedded
        final Product product;

        Order(this.id, this.dateTime, this.product);
      }
      
      @TypeConverters([EmbeddedDateTimeConverter])
      class Product {
        final DateTime productionDate;
      
        Product(this.productionDate);
      }

      class DateTimeConverter extends TypeConverter<DateTime, int> {
        @override
        DateTime decode(int databaseValue) {
          return DateTime.fromMillisecondsSinceEpoch(databaseValue);
        }

        @override
        int encode(DateTime value) {
          return value.millisecondsSinceEpoch;
        }
      }
      
      class EmbeddedDateTimeConverter extends TypeConverter<DateTime, int> {
        @override
        DateTime decode(int databaseValue) {
          return DateTime.fromMillisecondsSinceEpoch(databaseValue);
        }

        @override
        int encode(DateTime value) {
          return value.millisecondsSinceEpoch;
        }
      }
    ''');

      final actual = TestProcessor(classElement).process();

      final typeConverter = TypeConverter(
        'DateTimeConverter',
        await dateTimeDartType,
        await intDartType,
        TypeConverterScope.queryable,
      );
      final embeddedTypeConverter = TypeConverter(
        'EmbeddedDateTimeConverter',
        await dateTimeDartType,
        await intDartType,
        TypeConverterScope.embedded,
      );
      final idField = FieldProcessor(classElement.fields[0], null).process();
      final dateTimeField =
          FieldProcessor(classElement.fields[1], typeConverter).process();
      final embedded = [
        EmbeddedProcessor(classElement.fields[2], {embeddedTypeConverter})
            .process()
      ];
      final fields = [idField, dateTimeField];
      const constructor =
          "Order(row['id'] as int, _dateTimeConverter.decode(row['dateTime'] as int), Product(_embeddedDateTimeConverter.decode(row['productionDate'] as int)))";
      final expected = TestQueryable(
        classElement,
        fields,
        embedded,
        constructor,
      );
      expect(actual, equals(expected));
    });

    test('prefer the closest suitable type converter', () async {
      final classElement = await createClassElement('''
      @TypeConverters([DateTimeConverter, NullableDateTimeConverter])
      class Product {
        final DateTime date1;
        
        @TypeConverters([NullableDateTimeConverter, DateTimeConverter])
        final DateTime? date2;
        
        @TypeConverters([DateTimeConverter, NullableDateTimeConverter])
        final DateTime? date3;
        
        Product(this.date1, this.date2, this.date3);
      }
      
      class DateTimeConverter extends TypeConverter<DateTime, int> {
        @override
        DateTime decode(int databaseValue) {
          return DateTime.now();
        }

        @override
        int encode(DateTime value) {
          return 0;
        }
      }
      
      class NullableDateTimeConverter extends TypeConverter<DateTime?, int?> {
        @override
        DateTime? decode(int databaseValue) {
          return DateTime.now();
        }

        @override
        int? encode(DateTime? value) {
          return 0;
        }
      }
    ''');
      final actual = TestProcessor(classElement).process();
      const constructor =
          "Product(_dateTimeConverter.decode(row['date1'] as int), row['date2'] == null ? null : _dateTimeConverter.decode(row['date2'] as int), _nullableDateTimeConverter.decode(row['date3'] as int?))";
      expect(actual.constructor, constructor);
    });
  });

  group('Field inheritance', () {
    test('Inherits fields from abstract parent class', () async {
      final classElement = await createClassElement('''
      class TestEntity extends AbstractEntity {
        final String name;
      
        TestEntity(int id, this.name) : super(id);
      }
      
      abstract class AbstractEntity {
        @primaryKey
        final int id;
      
        AbstractEntity(this.id);
      }           
    ''');

      final actual = TestProcessor(classElement).process();
      final fieldNames = actual.fields.map((field) => field.name).toList();

      final expectedFieldNames = ['id', 'name'];
      const expectedConstructor =
          "TestEntity(row['id'] as int, row['name'] as String)";
      expect(fieldNames, containsAll(expectedFieldNames));
      expect(actual.constructor, equals(expectedConstructor));
    });

    test('Inherits fields from abstract parent class', () async {
      final classElement = await createClassElement('''
        class TestEntity extends AnotherAbstractEntity {
          final String name;
        
          TestEntity(int id, double foo, Person person, this.name) : super(id, foo, person);
        }
        
        abstract class AnotherAbstractEntity extends AbstractEntity {
          final double foo;
          
          @Embedded('person_')
          final Person person;
        
          AnotherAbstractEntity(int id, this.foo, this.person) : super(id);
        }
        
        abstract class AbstractEntity {
          @primaryKey
          final int id;
        
          AbstractEntity(this.id);
        }
        
        class Person {
          final String name;
          
          Person(this.name);
        }               
    ''');

      final actual = TestProcessor(classElement).process();
      final fieldNames = actual.fields.map((field) => field.name).toList();

      final expectedFieldNames = ['id', 'foo', 'name'];
      const expectedConstructor =
          "TestEntity(row['id'] as int, row['foo'] as double, Person(row['person_name'] as String), row['name'] as String)";
      expect(fieldNames, containsAll(expectedFieldNames));
      expect(actual.constructor, equals(expectedConstructor));
    });

    test('Inherits fields from superclass', () async {
      final classElement = await createClassElement('''
        class TestEntity extends SuperClassEntity {
          final String name;
        
          TestEntity(int id, this.name) : super(id);
        }
        
        class SuperClassEntity {
          @primaryKey
          final int id;
        
          SuperClassEntity(this.id);
        }                 
    ''');

      final actual = TestProcessor(classElement).process();
      final fieldNames = actual.fields.map((field) => field.name).toList();

      final expectedFieldNames = ['id', 'name'];
      const expectedConstructor =
          "TestEntity(row['id'] as int, row['name'] as String)";
      expect(fieldNames, containsAll(expectedFieldNames));
      expect(actual.constructor, equals(expectedConstructor));
    });

    test('Inherits fields from superclass', () async {
      final classElement = await createClassElement('''
        class TestEntity implements InterfaceEntity {
          @primaryKey
          @override
          final int id;
          final String name;
        
          TestEntity(this.id, this.name);
        }
        
        class InterfaceEntity {
          final int id;
        
          InterfaceEntity(this.id);
        }                 
    ''');

      final actual = TestProcessor(classElement).process();
      final fieldNames = actual.fields.map((field) => field.name).toList();

      final expectedFieldNames = ['id', 'name'];
      const expectedConstructor =
          "TestEntity(row['id'] as int, row['name'] as String)";
      expect(fieldNames, containsAll(expectedFieldNames));
      expect(actual.constructor, equals(expectedConstructor));
    });

    test('Throws when queryable inherits from mixin', () async {
      final classElement = await createClassElement('''
        class TestEntity with TestMixin {
          final int id;
        
          TestEntity(this.id);
        }
        
        class TestMixin {
          String name;
        }      
    ''');

      final actual = () => TestProcessor(classElement).process();

      final error = QueryableProcessorError(classElement).prohibitedMixinUsage;
      expect(actual, throwsInvalidGenerationSourceError(error));
    });
  });

  test('Ignore special fields', () async {
    final classElement = await createClassElement('''
      class Person {
        final int id;
      
        final String name;
        
        @embedded
        final Address address;
        
        String get label => '\$id: \$name'
    
        set printwith(String prefix) => print(prefix+name);
  
        Person(this.id, this.name, this.address);
        
        static String foo = 'foo';
        
        @override
        int get hashCode => id.hashCode ^ name.hashCode;
      }
      
      class Address {
        final String city;
       
        String get label => '\$city'
        
        set printwith(String prefix) => print(prefix+name);
 
        Address(this.city);
        
        static String bar = 'bar';
        
        @override
        int get hashCode => city.hashCode;
      }
    ''');

    final entity = TestProcessor(classElement).process();

    final entityFields = entity.fields.map((field) => field.name).toList();
    final embeddedFields =
        entity.embedded.first.fields.map((field) => field.name).toList();

    expect(entityFields, ['id', 'name']);
    expect(embeddedFields, ['city']);
  });

  group('Constructors', () {
    test('generate simple constructor', () async {
      final classElement = await createClassElement('''
      class Person {
        final int id;
      
        final String name;
      
        Person(this.id, this.name);
      }
    ''');

      final actual = TestProcessor(classElement).process().constructor;

      const expected = "Person(row['id'] as int, row['name'] as String)";
      expect(actual, equals(expected));
    });

    test('generate constructor with named argument', () async {
      final classElement = await createClassElement('''
      class Person {
        final int id;
      
        final String name;
        
        final String bar;
      
        Person(this.id, this.name, {required this.bar});
      }
    ''');

      final actual = TestProcessor(classElement).process().constructor;

      const expected =
          "Person(row['id'] as int, row['name'] as String, bar: row['bar'] as String)";
      expect(actual, equals(expected));
    });

    test('generate constructor with boolean arguments', () async {
      final classElement = await createClassElement('''
      class Person {
        final int id;
      
        final String name;
      
        final bool bar;
      
        final bool? foo;
      
        Person(this.id, this.name, {required this.bar, this.foo});
      }
    ''');

      final actual = TestProcessor(classElement).process().constructor;

      const expected =
          "Person(row['id'] as int, row['name'] as String, bar: (row['bar'] as int) != 0, foo: row['foo'] == null ? null : (row['foo'] as int) != 0)";
      expect(actual, equals(expected));
    });

    test('generate constructor with named arguments', () async {
      final classElement = await createClassElement('''
      class Person {
        final int id;
      
        final String name;
        
        final String bar;
      
        Person({required this.id, required this.name, required this.bar});
      }
    ''');

      final actual = TestProcessor(classElement).process().constructor;

      const expected =
          "Person(id: row['id'] as int, name: row['name'] as String, bar: row['bar'] as String)";
      expect(actual, equals(expected));
    });

    test('generate constructor with optional argument', () async {
      final classElement = await createClassElement('''
      class Person {
        final int id;
      
        final String name;
        
        final String? bar;
      
        Person(this.id, this.name, [this.bar]);
      }
    ''');

      final actual = TestProcessor(classElement).process().constructor;

      const expected =
          "Person(row['id'] as int, row['name'] as String, row['bar'] as String?)";
      expect(actual, equals(expected));
    });

    test('generate constructor with optional arguments', () async {
      final classElement = await createClassElement('''
      class Person {
        final int? id;
      
        final String? name;
        
        final String? bar;
      
        Person([this.id, this.name, this.bar]);
      }
    ''');

      final actual = TestProcessor(classElement).process().constructor;

      const expected =
          "Person(row['id'] as int?, row['name'] as String?, row['bar'] as String?)";
      expect(actual, equals(expected));
    });

    group('nullability', () {
      test('generates constructor with only nullable types', () async {
        final classElement = await createClassElement('''
          class Person {
            final int? id;
            
            final double? doubleId; 
          
            final String? name;
            
            final bool? bar;
            
            final Uint8List? blob;
            
            @embedded
            final Address? address;
          
            Person(this.id, this.doubleId, this.name, this.bar, this.blob, this.address);
          }
          
          class Address {
            final String? city;
            
            final String? street;
            
            Address(this.city, this.street);
          }
        ''');

        final actual = TestProcessor(classElement).process().constructor;

        const expected =
            "Person(row['id'] as int?, row['doubleId'] as double?, row['name'] as String?, row['bar'] == null ? null : (row['bar'] as int) != 0, row['blob'] as Uint8List?, row['city'] != null || row['street'] != null ? Address(row['city'] as String?, row['street'] as String?) : null)";
        expect(actual, equals(expected));
      });

      test('generates constructor with only non-nullable types', () async {
        final classElement = await createClassElement('''
          class Person {
            final int id;
            
            final double doubleId; 
          
            final String name;
            
            final bool bar;
            
            final Uint8List blob;
            
            @embedded
            final Address address;
          
            Person(this.id, this.doubleId, this.name, this.bar, this.blob, this.address);
          }
          
          class Address {
            final String city;
           
            final String street;
 
            Address(this.city, this.street);
          }
        ''');

        final actual = TestProcessor(classElement).process().constructor;

        const expected =
            "Person(row['id'] as int, row['doubleId'] as double, row['name'] as String, (row['bar'] as int) != 0, row['blob'] as Uint8List, Address(row['city'] as String, row['street'] as String))";
        expect(actual, equals(expected));
      });
    });
  });

  group('@Ignore', () {
    test('ignore field not present in constructor', () async {
      final classElement = await createClassElement('''
      class Person {
        final int id;
      
        final String name;
        
        @ignore
        String? foo;
      
        Person(this.id, this.name);
      }
    ''');

      final actual = TestProcessor(classElement)
          .process()
          .fields
          .map((field) => field.name);

      const expected = 'foo';
      expect(actual, isNot(contains(expected)));
    });

    test('ignore field present in constructor', () async {
      final classElement = await createClassElement('''
      class Person {
        final int id;
      
        final String name;
        
        @ignore
        String? foo;
      
        Person(this.id, this.name, [this.foo = 'foo']);
      }
    ''');

      final actual = TestProcessor(classElement).process().constructor;

      const expected = "Person(row['id'] as int, row['name'] as String)";
      expect(actual, equals(expected));
    });
  });
}

class TestQueryable extends Queryable {
  TestQueryable(
    ClassElement classElement,
    List<Field> fields,
    List<Embedded> embedded,
    String constructor,
  ) : super(classElement, '', fields, embedded, constructor);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestQueryable &&
          runtimeType == other.runtimeType &&
          classElement == other.classElement &&
          const ListEquality<Field>().equals(fields, other.fields) &&
          constructor == other.constructor;

  @override
  int get hashCode =>
      classElement.hashCode ^
      fields.hashCode ^
      embedded.hashCode ^
      constructor.hashCode;

  @override
  String toString() {
    return 'TestQueryable{classElement: $classElement, name: $name, fields: $fields, embedded: $embedded, constructor: $constructor}';
  }
}

class TestProcessor extends QueryableProcessor<TestQueryable> {
  TestProcessor(
    ClassElement classElement, [
    Set<TypeConverter>? typeConverters,
  ]) : super(classElement, typeConverters ?? {});

  @override
  TestQueryable process() {
    final fields = getFields();
    final embedded = getEmbedded();

    return TestQueryable(
      classElement,
      fields,
      embedded,
      getConstructor([...fields, ...embedded]),
    );
  }
}
