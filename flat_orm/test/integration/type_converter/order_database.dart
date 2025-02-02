import 'dart:async';

import 'package:flat_orm/flat_orm.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'order.dart';
import 'order_dao.dart';
import 'type_converter.dart';

part 'order_database.g.dart';

@Database(version: 1, entities: [Order])
@TypeConverters([DateTimeConverter])
abstract class OrderDatabase extends FlatDatabase {
  OrderDao get orderDao;
}
