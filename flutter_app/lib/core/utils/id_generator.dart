import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a short, prefixed id (e.g. `s_1a2b3c4d`).
String newId(String prefix) => '${prefix}_${_uuid.v4().substring(0, 8)}';
