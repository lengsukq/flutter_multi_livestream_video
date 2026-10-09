import 'failure.dart';

/// Validates untrusted protocol objects before domain models consume them.
class JsonReader {
  JsonReader(this.value, {this.path = r'$'});
  final Map<String, Object?> value;
  final String path;

  T required<T>(String field) {
    final result = value[field];
    if (result is T) return result;
    throw RealtimeException(
      code: RealtimeErrorCode.invalidResponse,
      message: 'Invalid response field $path.$field; expected $T.',
      operation: 'decode',
      details: {'field': '$path.$field'},
    );
  }

  T? optional<T>(String field) {
    if (value[field] == null) return null;
    return required<T>(field);
  }

  List<T> list<T>(String field, {bool optional = false}) {
    if (optional && value[field] == null) return List<T>.unmodifiable([]);
    final items = required<List<Object?>>(field);
    return List<T>.unmodifiable([
      for (var index = 0; index < items.length; index++)
        JsonReader({
          'value': items[index],
        }, path: '$path.$field[$index]').required<T>('value'),
    ]);
  }

  List<T> objects<T>(
    String field,
    T Function(Map<String, dynamic>) read, {
    bool optional = false,
  }) {
    if (optional && value[field] == null) return List<T>.unmodifiable([]);
    final items = required<List<Object?>>(field);
    return List<T>.unmodifiable([
      for (var index = 0; index < items.length; index++)
        _objectAt('$path.$field[$index]', items[index], read),
    ]);
  }

  T _objectAt<T>(
    String location,
    Object? input,
    T Function(Map<String, dynamic>) read,
  ) {
    if (input is! Map<String, dynamic>) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidResponse,
        message: 'Invalid response object at $location.',
        details: {'field': location},
      );
    }
    try {
      return read(input);
    } on RealtimeException catch (error, stack) {
      final details = error.details;
      final field = details is Map ? details['field'] : null;
      final resolved = field is String && field.startsWith(r'$')
          ? location + field.substring(1)
          : location;
      throw RealtimeException(
        code: RealtimeErrorCode.invalidResponse,
        message: 'Invalid response field $resolved.',
        cause: error,
        stackTrace: stack,
        operation: 'decode',
        details: {'field': resolved},
      );
    }
  }

  DateTime? optionalDateTime(String field) =>
      value[field] == null ? null : dateTime(field);

  T enumValue<T extends Enum>(String field, List<T> values) {
    final name = required<String>(field);
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw RealtimeException(
      code: RealtimeErrorCode.invalidResponse,
      message: 'Invalid response enum at $path.$field.',
      details: {'field': '$path.$field'},
    );
  }

  DateTime dateTime(String field) {
    final parsed = DateTime.tryParse(required<String>(field));
    if (parsed != null) return parsed;
    throw RealtimeException(
      code: RealtimeErrorCode.invalidResponse,
      message: 'Invalid date at $path.$field.',
      details: {'field': '$path.$field'},
    );
  }

  T decode<T>(T Function() parse) {
    try {
      return parse();
    } catch (error, stack) {
      if (error is RealtimeException) rethrow;
      throw RealtimeException(
        code: RealtimeErrorCode.invalidResponse,
        message: 'Invalid response object at $path.',
        operation: 'decode',
        cause: error,
        stackTrace: stack,
        details: {'field': path},
      );
    }
  }
}

/// Recursively freezes JSON values used by command and protocol snapshots.
Object? freezeJson(Object? value) => switch (value) {
  Map<Object?, Object?>() => Map<String, Object?>.unmodifiable({
    for (final entry in value.entries)
      entry.key as String: freezeJson(entry.value),
  }),
  List<Object?>() => List<Object?>.unmodifiable(value.map(freezeJson)),
  _ => value,
};
