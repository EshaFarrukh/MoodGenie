import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  const BackendApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class BackendApiClient {
  BackendApiClient({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? httpClient,
    bool? debugModeOverride,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _httpClient = httpClient ?? http.Client(),
       _debugModeOverride = debugModeOverride;

  static const String _backendConfigCollection = 'app_config';
  static const String _backendConfigDoc = 'mobile';
  static const String _backendUrlFromDartDefine = String.fromEnvironment(
    'BACKEND_URL',
  );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final bool? _debugModeOverride;

  String? _cachedBaseUrl;

  static String _defaultLocalBackendUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:3000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:3000';
    }
  }

  static String normalizeBackendUrl(String? rawUrl, {String? fallbackUrl}) {
    final normalizedUrl = rawUrl?.trim();
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      final sanitized = normalizedUrl.endsWith('/')
          ? normalizedUrl.substring(0, normalizedUrl.length - 1)
          : normalizedUrl;
      return sanitized;
    }
    return fallbackUrl ?? _defaultLocalBackendUrl();
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1' ||
        normalized.startsWith('127.');
  }

  static bool _isAndroidEmulatorHost(String host) {
    return host.trim() == '10.0.2.2';
  }

  static bool _isPrivateIpv4Host(String host) {
    final segments = host.trim().split('.');
    if (segments.length != 4) {
      return false;
    }

    final octets = segments.map(int.tryParse).toList();
    if (octets.any((value) => value == null || value < 0 || value > 255)) {
      return false;
    }

    final first = octets[0]!;
    final second = octets[1]!;
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  static bool _isAllowedInsecureHost(String host) {
    return _isLoopbackHost(host) ||
        _isAndroidEmulatorHost(host) ||
        _isPrivateIpv4Host(host);
  }

  static String enforceSafeBackendUrl(
    String rawUrl, {
    bool? debugModeOverride,
  }) {
    final sanitized = normalizeBackendUrl(rawUrl);
    final uri = Uri.tryParse(sanitized);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      throw const BackendApiException(
        'BACKEND_URL must be a valid absolute URL.',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') {
      return sanitized;
    }

    final isDebugBuild = debugModeOverride ?? kDebugMode;
    if (scheme == 'http' && isDebugBuild && _isAllowedInsecureHost(uri.host)) {
      return sanitized;
    }

    throw BackendApiException(
      'Insecure backend URL blocked. Use HTTPS for non-local environments and all release/profile builds.',
      code: 'insecure_backend_url',
    );
  }

  Future<String> getBaseUrl({bool refresh = false}) async {
    if (!refresh && _cachedBaseUrl != null) {
      return _cachedBaseUrl!;
    }

    final dartDefineUrl = _backendUrlFromDartDefine.trim();
    if (dartDefineUrl.isNotEmpty) {
      final resolved = enforceSafeBackendUrl(
        dartDefineUrl,
        debugModeOverride: _debugModeOverride,
      );
      _cachedBaseUrl = resolved;
      return resolved;
    }

    var resolved = _defaultLocalBackendUrl();

    try {
      final doc = await _firestore
          .collection(_backendConfigCollection)
          .doc(_backendConfigDoc)
          .get();
      final overrideUrl = doc.data()?['backendUrl'];
      if (overrideUrl is String && overrideUrl.trim().isNotEmpty) {
        resolved = enforceSafeBackendUrl(
          overrideUrl,
          debugModeOverride: _debugModeOverride,
        );
      }
    } on BackendApiException {
      rethrow;
    } catch (_) {
      // Fall back to the local/default backend URL when remote config is
      // unavailable. The caller will surface connection issues.
    }

    _cachedBaseUrl = enforceSafeBackendUrl(
      resolved,
      debugModeOverride: _debugModeOverride,
    );
    return resolved;
  }

  Future<Map<String, String>> _requestHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final user = _auth.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _requestHeaders();
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: jsonEncode(body ?? const <String, dynamic>{}),
        )
        .timeout(timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _requestHeaders();
    final response = await _httpClient
        .get(Uri.parse('$baseUrl$path'), headers: headers)
        .timeout(timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _requestHeaders();
    final response = await _httpClient
        .put(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: jsonEncode(body ?? const <String, dynamic>{}),
        )
        .timeout(timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final baseUrl = await getBaseUrl();
    final headers = await _requestHeaders();
    final response = await _httpClient
        .delete(Uri.parse('$baseUrl$path'), headers: headers)
        .timeout(timeout);
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final responseBody = response.body.trim();
    Map<String, dynamic> payload = const <String, dynamic>{};

    if (responseBody.isNotEmpty) {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    final errorMessage = _coerceResponseString(payload['error']);
    final errorCode = _coerceResponseString(payload['code']);
    throw BackendApiException(
      errorMessage ?? 'Request failed.',
      statusCode: response.statusCode,
      code: errorCode,
    );
  }

  String? _coerceResponseString(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }
}
