import 'dart:async';

import 'package:flat_orm/flat_orm.dart';
import 'package:sqflite/sqlite_api.dart' as sqflite;

import 'dao/dog_dao.dart';
import 'dao/person_dao.dart';
import 'model/address.dart';
import 'model/dog.dart';
import 'model/person.dart';

part 'database.g.dart';

@Database(version: 2, entities: [Person, Dog])
abstract class TestDatabase extends FlatDatabase {
  PersonDao get personDao;

  DogDao get dogDao;
}
