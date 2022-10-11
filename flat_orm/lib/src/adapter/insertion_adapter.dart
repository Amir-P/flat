import 'dart:async';

import 'package:flat_annotation/flat_annotation.dart';
import 'package:flat_orm/src/extension/on_conflict_strategy_extensions.dart';
import 'package:sqflite/sqlite_api.dart';

class InsertionAdapter<T> {
  final DatabaseExecutor _database;
  final String _entityName;
  final Map<String, Object?> Function(T) _valueMapper;
  final StreamController<Set<String>>? _changeListener;

  InsertionAdapter(
    final DatabaseExecutor database,
    final String entityName,
    final Map<String, Object?> Function(T) valueMapper, [
    final StreamController<Set<String>>? changeListener,
  ])  : assert(entityName.isNotEmpty),
        _database = database,
        _entityName = entityName,
        _valueMapper = valueMapper,
        _changeListener = changeListener;

  Future<void> insert(
    final T item,
    final OnConflictStrategy onConflictStrategy,
  ) async {
    await _insert(item, onConflictStrategy);
  }

  Future<void> insertList(
    final List<T> items,
    final OnConflictStrategy onConflictStrategy,
  ) async {
    if (items.isEmpty) return;
    final batch = _database.batch();
    for (final item in items) {
      batch.insert(
        _entityName,
        _valueMapper(item),
        conflictAlgorithm: onConflictStrategy.asSqfliteConflictAlgorithm(),
      );
    }
    await batch.commit(noResult: true);
    _changeListener?.add({_entityName});
  }

  Future<int> insertAndReturnId(
    final T item,
    final OnConflictStrategy onConflictStrategy,
  ) {
    return _insert(item, onConflictStrategy);
  }

  Future<List<int>> insertListAndReturnIds(
    final List<T> items,
    final OnConflictStrategy onConflictStrategy,
  ) async {
    if (items.isEmpty) return [];
    final batch = _database.batch();
    for (final item in items) {
      batch.insert(
        _entityName,
        _valueMapper(item),
        conflictAlgorithm: onConflictStrategy.asSqfliteConflictAlgorithm(),
      );
    }
    final result = (await batch.commit(noResult: false)).cast<int>();
    if (result.isNotEmpty) _changeListener?.add({_entityName});
    return result;
  }

  Future<int> _insert(
    final T item,
    final OnConflictStrategy onConflictStrategy,
  ) async {
    final result = await _database.insert(
      _entityName,
      _valueMapper(item),
      conflictAlgorithm: onConflictStrategy.asSqfliteConflictAlgorithm(),
    );
    // We will add the event no matter the result coming from insertion method
    // check https://github.com/tekartik/sqflite/issues/871
    _changeListener?.add({_entityName});
    return result;
  }
}
