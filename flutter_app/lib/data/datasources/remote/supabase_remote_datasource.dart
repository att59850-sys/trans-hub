import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/failures.dart';
import 'remote_datasource.dart';

/// [RemoteDataSource] backed by Supabase's PostgREST API over `dio` (TH-009/013).
///
/// This talks to the auto-generated REST endpoints (`/rest/v1/<table>`) using
/// the project anon key. Row-Level Security (TH-012) enforces access server
/// side; the user's auth JWT (when present) is forwarded as a bearer token.
///
/// It is only instantiated when [AppConfig.hasRemoteBackend] is true; otherwise
/// the app uses [NoopRemoteDataSource] and stays fully offline.
class SupabaseRemoteDataSource implements RemoteDataSource {
  SupabaseRemoteDataSource(this._config, {Dio? dio, String? Function()? token})
      : _token = token ?? (() => null),
        _dio = dio ?? _buildDio(_config);

  static Dio _buildDio(AppConfig config) => Dio(
        BaseOptions(
          baseUrl: '${config.supabaseUrl}/rest/v1',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

  final AppConfig _config;
  final Dio _dio;
  final String? Function() _token;

  Map<String, String> get _headers {
    final jwt = _token();
    return {
      'apikey': _config.supabaseAnonKey,
      'Authorization': 'Bearer ${jwt ?? _config.supabaseAnonKey}',
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=representation',
    };
  }

  @override
  bool get isConfigured => _config.hasRemoteBackend;

  @override
  Future<List<Map<String, dynamic>>> fetchAll(
    String table, {
    int sinceMillis = 0,
  }) async {
    try {
      final query = <String, dynamic>{'select': '*'};
      if (sinceMillis > 0) {
        // Incremental pull by updated_at (ISO timestamp column on the server).
        final since =
            DateTime.fromMillisecondsSinceEpoch(sinceMillis, isUtc: true)
                .toIso8601String();
        query['updated_at'] = 'gte.$since';
      }
      final res = await _dio.get<List<dynamic>>(
        '/$table',
        queryParameters: query,
        options: Options(headers: _headers),
      );
      return (res.data ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on DioException catch (e) {
      throw NetworkFailure('Fetch $table failed: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> upsert(
    String table,
    Map<String, dynamic> row,
  ) async {
    try {
      final res = await _dio.post<List<dynamic>>(
        '/$table',
        data: [row],
        options: Options(headers: _headers),
      );
      final list = res.data ?? const [];
      return list.isEmpty ? row : Map<String, dynamic>.from(list.first as Map);
    } on DioException catch (e) {
      throw NetworkFailure('Upsert $table failed: ${e.message}');
    }
  }

  @override
  Future<void> delete(String table, String id) async {
    try {
      await _dio.delete<void>(
        '/$table',
        queryParameters: {'id': 'eq.$id'},
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw NetworkFailure('Delete $table failed: ${e.message}');
    }
  }
}
