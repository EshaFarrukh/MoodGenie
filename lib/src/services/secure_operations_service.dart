import '../../models/session_model.dart';
import 'backend_api_client.dart';

class SecuredRoomInfo {
  const SecuredRoomInfo({
    required this.roomId,
    this.appointmentId,
    this.canCall = false,
    this.relationshipType,
  });

  final String roomId;
  final String? appointmentId;
  final bool canCall;
  final String? relationshipType;
}

class SecureOperationsService {
  SecureOperationsService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus status, {
    String? reason,
  }) async {
    await _apiClient.postJson(
      '/api/appointments/$appointmentId/status',
      body: {
        'status': status.value,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<SecuredRoomInfo> ensureAppointmentCallRoom(
    String appointmentId, {
    bool audioOnly = false,
  }) async {
    final data = await _apiClient.postJson(
      '/api/appointments/$appointmentId/call-room',
      body: {'audioOnly': audioOnly},
    );
    return SecuredRoomInfo(
      roomId: _requireStringValue(data['roomId'], 'roomId'),
      appointmentId: _readStringValue(data['appointmentId']),
      canCall: true,
      relationshipType: 'appointment',
    );
  }

  Future<SecuredRoomInfo> ensureTherapistChatRoom({
    required String counterpartId,
  }) async {
    final data = await _apiClient.postJson(
      '/api/therapist-chats/ensure-room',
      body: {'counterpartId': counterpartId},
    );
    return SecuredRoomInfo(
      roomId: _requireStringValue(data['roomId'], 'roomId'),
      appointmentId: _readStringValue(data['appointmentId']),
      canCall: _readBoolValue(data['canCall']) ?? false,
      relationshipType: _readStringValue(data['relationshipType']),
    );
  }

  Future<SecuredRoomInfo> ensureCallRoom({
    required String counterpartId,
    String? appointmentId,
    bool audioOnly = false,
  }) async {
    final body = <String, dynamic>{
      'counterpartId': counterpartId,
      'audioOnly': audioOnly,
    };
    if (appointmentId != null) {
      body['appointmentId'] = appointmentId;
    }

    final data = await _apiClient.postJson(
      '/api/calls/ensure-room',
      body: body,
    );
    return SecuredRoomInfo(
      roomId: _requireStringValue(data['roomId'], 'roomId'),
      appointmentId: _readStringValue(data['appointmentId']),
      canCall: true,
      relationshipType: 'appointment',
    );
  }

  String? _readStringValue(dynamic value) {
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

  String _requireStringValue(dynamic value, String fieldName) {
    final normalized = _readStringValue(value);
    if (normalized == null) {
      throw Exception('Invalid $fieldName received from secure operations.');
    }
    return normalized;
  }

  bool? _readBoolValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }
}
