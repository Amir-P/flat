# Flat (Based on [Floor](https://github.com/vitusortner/floor))

**See the [project's website](https://amir-p.github.io/flat) for the full documentation.**

Flat provides a neat SQLite abstraction for your Flutter applications inspired by the [Room persistence library](https://developer.android.com/topic/libraries/architecture/room).
It comes with automatic mapping between in-memory objects and database rows while still offering full control of the database with the use of SQL.
As a consequence, it's necessary to have an understanding of SQL and SQLite in order to harvest Flat's full potential.

- null-safe
- typesafe
- reactive
- lightweight
- SQL centric
- no hidden magic
- no hidden costs
- iOS, Android, Linux, macOS, Windows

⚠️ The library is open to contributions!
Refer to [GitHub Discussions](https://github.com/Amir-P/flat/discussions) for questions, ideas, and discussions.

[![pub package](https://img.shields.io/pub/v/flat_orm.svg)](https://pub.dartlang.org/packages/flat_orm)
[![build status](https://github.com/Amir-P/flat/workflows/Continuous%20integration/badge.svg)](https://github.com/Amir-P/flat/actions)
[![codecov](https://codecov.io/gh/Amir-P/flat/branch/develop/graph/badge.svg)](https://codecov.io/gh/Amir-P/flat)

## Getting Started

### 1. Setup Dependencies

Add the runtime dependency `flat_orm` as well as the generator `flat_generator` to your `pubspec.yaml`.
The third dependency is `build_runner` which has to be included as a dev dependency just like the generator.

- `flat_orm` holds all the code you are going to use in your application.
- `flat_generator` includes the code for generating the database classes.
- `build_runner` enables a concrete way of generating source code files.

```yaml
dependencies:
  flutter:
    sdk: flutter
  flat_orm: ^1.2.0+1

dev_dependencies:
  flat_generator: ^1.3.0+1
  build_runner: ^2.1.2
```

### 2. Create an Entity

It will represent a database table as well as the scaffold of your business object.
`@entity` marks the class as a persistent class.
It's required to add a primary key to your table.
You can do so by adding the `@primaryKey` annotation to an `int` property.
There is no restriction on where you put the file containing the entity.

```dart
// entity/person.dart

import 'package:flat_orm/flat_orm.dart';

@entity
class Person {
  @primaryKey
  final int id;

  final String name;

  Person(this.id, this.name);
}
```

### 3. Create a DAO (Data Access Object)

This component is responsible for managing access to the underlying SQLite database.
The abstract class contains the method signatures for querying the database which have to return a `Future` or `Stream`.

- You can define queries by adding the `@Query` annotation to a method.
  The SQL statement has to get added in parenthesis.
  The method must return a `Future` or `Stream` of the `Entity` you're querying for.
- `@insert` marks a method as an insertion method.

```dart
// dao/person_dao.dart

import 'package:flat_orm/flat_orm.dart';

@dao
abstract class PersonDao {
  @Query('SELECT * FROM Person')
  Future<List<Person>> findAllPersons();

  @Query('SELECT * FROM Person WHERE id = :id')
  Stream<Person?> findPersonById(int id);

  @insert
  Future<void> insertPerson(Person person);
}
```

### 4. Create the Database

It has to be an abstract class which extends `FlatDatabase`.
Furthermore, it's required to add `@Database()` to the signature of the class.
Make sure to add the created entity to the `entities` attribute of the `@Database` annotation.
In order to make the generated code work, it's required to also add the listed imports.

Make sure to add `part 'database.g.dart';` beneath the imports of this file.
It's important to note that 'database' has to get exchanged with the filename of the database definition.
In this case, the file is named `database.dart`.

```dart
// database.dart

// required package imports
import 'dart:async';
import 'package:flat_orm/flat_orm.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'dao/person_dao.dart';
import 'entity/person.dart';

part 'database.g.dart'; // the generated code will be there

@Database(version: 1, entities: [Person])
abstract class AppDatabase extends FlatDatabase {
  PersonDao get personDao;
}
```

### 5. Run the Code Generator

Run the generator with `flutter packages pub run build_runner build`.
To automatically run it, whenever a file changes, use `flutter packages pub run build_runner watch`.

### 6. Use the Generated Code

For obtaining an instance of the database, use the generated `$FlatAppDatabase` class, which allows access to a database builder.
The name is being composed by `$Flat` and the database class name.
The string passed to `databaseBuilder()` will be the database file name.
For initializing the database, call `build()` and make sure to `await` the result.

In order to retrieve the `PersonDao` instance, invoking the `persoDao` getter on the database instance is enough.
Its functions can be used as shown in the following snippet.

```dart
final database = await $FlatAppDatabase.databaseBuilder('app_database.db').build();

final personDao = database.personDao;
final person = Person(1, 'Frank');

await personDao.insertPerson(person);
final result = await personDao.findPersonById(1);
```

For further examples take a look at the [example](https://github.com/Amir-P/flat/tree/develop/example) and [test](https://github.com/vitusortner/Amir-P/flat/develop/flat/test/integration) directories.

## Naming
Just like [Floor](https://github.com/vitusortner/floor), Flat is another related word to Room [Room](https://developer.android.com/topic/libraries/architecture/room) with *fl* in it!

## Bugs, Ideas, and Feedback
For bugs please use [GitHub Issues](https://github.com/Amir-P/flat/issues).
For questions, ideas, and discussions use [GitHub Discussions](https://github.com/Amir-P/flat/discussions).

## License
    Copyright 2022 The Flat and The Floor Project Authors

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
