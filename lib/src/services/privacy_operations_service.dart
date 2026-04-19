import 'dart:convert';
import 'dart:typed_data';

import 'backend_api_client.dart';

class DataExportPackage {
  const DataExportPackage({
    required this.jobId,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    this.moodCsvBytes,
    required this.summary,
  });

  final String jobId;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final Uint8List? moodCsvBytes;
  final Map<String, dynamic> summary;
}

class DeleteAccountResult {
  const DeleteAccountResult({required this.jobId, required this.summary});

  final String jobId;
  final Map<String, dynamic> summary;
}

class PrivacyOperationsService {
  PrivacyOperationsService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

  Future<DataExportPackage> exportMyData() async {
    final data = await _apiClient.postJson('/api/data-rights/export');
    return DataExportPackage(
      jobId: data['jobId'] as String,
      fileName: data['fileName'] as String? ?? 'moodgenie_export.json',
      mimeType: data['mimeType'] as String? ?? 'application/json',
      bytes: base64Decode(data['contentBase64'] as String? ?? ''),
      moodCsvBytes: data['moodCsvBase64'] is String
          ? base64Decode(data['moodCsvBase64'] as String)
          : null,
      summary:
          (data['summary'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
    );
  }

  Future<DeleteAccountResult> deleteMyAccount({
    required String confirmation,
  }) async {
    final data = await _apiClient.postJson(
      '/api/data-rights/delete-account',
      body: {'confirmation': confirmation},
    );
    return DeleteAccountResult(
      jobId: data['jobId'] as String,
      summary:
          (data['summary'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
    );
  }
}
