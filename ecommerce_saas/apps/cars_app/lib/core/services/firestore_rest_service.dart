import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../error/app_error.dart';

import 'firebase_rest_auth_service.dart';

final firestoreRestServiceProvider = Provider((ref) {
  final authState = ref.watch(authRestServiceProvider);
  return FirestoreRestService(
    projectId: 'my-store-b0723',
    apiKey: 'AIzaSyCjmGWBANCyPt3sFF6L7Cxp1N1I_w_E5Ws',
    authToken: authState.idToken,
  );
});

class FirestoreRestService {
  final String projectId;
  final String apiKey;
  final String? authToken;
  final String baseUrl;

  FirestoreRestService({
    required this.projectId,
    required this.apiKey,
    this.authToken,
  }) : baseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  // --- Core CRUD Operations ---

  Future<Map<String, dynamic>?> getDocument(String path) async {
    final url = '$baseUrl/$path?key=$apiKey';
    try {
      // Allow unauthenticated requests
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = _fromFirestore(data);
        await _saveToCache(url, result);
        return result;
      }
      // If unauthorized or error, try cache
      final cached = await _getFromCache(url);
      if (cached != null) return cached;
      throw ServerError('فشل الحصول على البيانات من الخادم (Status: ${response.statusCode})');
    } catch (e) {
      debugPrint('REST ERROR: getDocument($path) -> $e');
      final cached = await _getFromCache(url);
      if (cached != null) return cached;
      if (e is AppError) rethrow;
      throw NetworkError();
    }
  }

  Future<List<Map<String, dynamic>>> getCollection(String path, {String? queryParams}) async {
    final url = '$baseUrl/$path?key=$apiKey${queryParams != null ? '&$queryParams' : ''}';
    try {
      // Allow unauthenticated requests
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List documents = data['documents'] ?? [];
        final results = documents.map((doc) => _fromFirestore(doc)).toList();
        await _saveCollectionToCache(url, results);
        return results;
      }
      // If error (like 401 or network), try cache
      return await _getCollectionFromCache(url);
    } catch (e) {
      debugPrint('REST ERROR: getCollection($path) -> $e');
      return await _getCollectionFromCache(url);
    }
  }

  Future<void> setDocument(String path, Map<String, dynamic> data, {bool isUpdate = false}) async {
    final url = '$baseUrl/$path?key=$apiKey';
    final firestoreData = _toFirestore(data, path);
    
    // Optimistic cache update for single document
    await _saveToCache(url, data);

    // Allow unauthenticated writes, relying on Firebase Security Rules

    try {
      String requestUrl = url;
      if (isUpdate) {
        final fields = (firestoreData['fields'] as Map<String, dynamic>).keys;
        if (fields.isNotEmpty) {
          // Correctly repeat updateMask.fieldPaths for each field
          final mask = fields.map((f) => 'updateMask.fieldPaths=$f').join('&');
          requestUrl += '&$mask';
        }
      }

      final response = isUpdate 
          ? await http.patch(Uri.parse(requestUrl), body: json.encode(firestoreData), headers: _headers)
          : await http.post(Uri.parse('$baseUrl/${path.split('/').first}?key=$apiKey&documentId=${path.split('/').last}'), body: json.encode(firestoreData), headers: _headers);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw PermissionError();
      } else if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('REST ERROR: setDocument failed ${response.statusCode}: ${response.body}');
        throw ServerError('فشل حفظ البيانات (Status: ${response.statusCode})');
      } else {
        final savedData = json.decode(response.body);
        final parsed = _fromFirestore(savedData);
        await _saveToCache(url, parsed);
      }
    } catch (e) {
      debugPrint('REST ERROR: setDocument($path) -> $e');
      if (e is AppError) rethrow;
      throw NetworkError();
    }
  }

  Future<void> deleteDocument(String path) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/$path?key=$apiKey'), headers: _headers);
      if (response.statusCode != 200 && response.statusCode != 204) {
        debugPrint('REST ERROR: deleteDocument failed ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('REST ERROR: deleteDocument($path) -> $e');
    }
  }

  // --- Complex Queries ---

  Future<List<Map<String, dynamic>>> runQuery(String collectionId, Map<String, dynamic> structuredQuery) async {
    final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery?key=$apiKey';
    final body = {
      'structuredQuery': {
        'from': [{'collectionId': collectionId}],
        ...structuredQuery,
      }
    };
    // Use a hash of the body for the cache key to distinguish different reports
    final cacheKey = 'runQuery_$collectionId' + json.encode(structuredQuery).hashCode.toString();

    try {
      // Allow unauthenticated query if authToken is null, since rules may allow it
      final response = await http.post(Uri.parse(url), body: json.encode(body), headers: _headers);
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final results = data
            .where((item) => item['document'] != null)
            .map((item) => _fromFirestore(item['document']))
            .toList();
        
        await _saveCollectionToCache(cacheKey, results);
        return results;
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('REST ERROR: runQuery -> $e');
      final cached = await _getCollectionFromCache(cacheKey);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  // --- Local Caching Helpers ---

  Future<void> _saveToCache(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_$key', json.encode(data));
  }

  Future<Map<String, dynamic>?> _getFromCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_$key');
    if (cached != null) return json.decode(cached);
    return null;
  }

  Future<void> _saveCollectionToCache(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_coll_$key', json.encode(data));
  }

  Future<List<Map<String, dynamic>>> _getCollectionFromCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cache_coll_$key');
    if (cached != null) {
      final List decoded = json.decode(cached);
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // --- Data Mapping Utilities ---

  Map<String, dynamic> _fromFirestore(Map<String, dynamic> doc) {
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    final result = <String, dynamic>{};
    
    // Extract ID from full name path: projects/{project}/databases/(default)/documents/{path}/{id}
    final String name = doc['name'] ?? '';
    result['id'] = name.split('/').last;

    fields.forEach((key, value) {
      result[key] = _parseValue(value);
    });
    
    return result;
  }

  dynamic _parseValue(Map<String, dynamic> value) {
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) return int.tryParse(value['integerValue'].toString()) ?? 0;
    if (value.containsKey('doubleValue')) return (value['doubleValue'] as num?)?.toDouble() ?? 0.0;
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('timestampValue')) {
      try {
        return DateTime.parse(value['timestampValue']);
      } catch (_) {
        return DateTime.now();
      }
    }
    if (value.containsKey('mapValue')) {
      final mapFields = value['mapValue']['fields'] as Map<String, dynamic>? ?? {};
      return mapFields.map((k, v) => MapEntry(k, _parseValue(v)));
    }
    if (value.containsKey('arrayValue')) {
      final list = value['arrayValue']['values'] as List? ?? [];
      return list.map((v) => _parseValue(v)).toList();
    }
    if (value.containsKey('nullValue')) return null;
    return null;
  }

  Map<String, dynamic> _toFirestore(Map<String, dynamic> data, [String? path]) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      if (key == 'id' || key == 'name') return; 
      final mapped = _mapValue(value);
      if (mapped != null) {
        fields[key] = mapped;
      }
    });
    return {
      'fields': fields,
    };
  }

  Map<String, dynamic>? _mapValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is DateTime) return {'timestampValue': value.toUtc().toIso8601String()};
    if (value is Map<String, dynamic>) {
      final fields = <String, dynamic>{};
      value.forEach((k, v) {
        final m = _mapValue(v);
        if (m != null) fields[k] = m;
      });
      return {'mapValue': {'fields': fields}};
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map((v) => _mapValue(v)).where((v) => v != null).toList()
        }
      };
    }
    return null;
  }
}
