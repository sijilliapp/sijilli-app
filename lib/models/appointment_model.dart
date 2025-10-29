class AppointmentModel {
  final String id;
  final String title;
  final String? region;
  final String? building;
  final String privacy;
  final String status;
  final DateTime appointmentDate;
  final String hostId;
  final String? streamLink;
  final String? noteShared;
  final DateTime created;
  final DateTime updated;

  AppointmentModel({
    required this.id,
    required this.title,
    this.region,
    this.building,
    required this.privacy,
    required this.status,
    required this.appointmentDate,
    required this.hostId,
    this.streamLink,
    this.noteShared,
    required this.created,
    required this.updated,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      region: json['region'],
      building: json['building'],
      privacy: json['privacy'] ?? 'public',
      status: json['status'] ?? 'active',
      // ملاحظة: appointmentDate يأتي من قاعدة البيانات بتوقيت UTC
      // يجب تحويله إلى التوقيت المحلي عند العرض باستخدام TimezoneService.toLocal()
      appointmentDate: _parseDateTime(json['appointment_date']) ?? DateTime.now(),
      hostId: json['host'] ?? '',
      streamLink: json['stream_link'],
      noteShared: json['note_shared'],
      created: _parseDateTime(json['created']) ?? DateTime.now(),
      updated: _parseDateTime(json['updated']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is String && dateValue.isNotEmpty) {
        return DateTime.parse(dateValue);
      }
      return null;
    } catch (e) {
      print('خطأ في تحليل التاريخ: $dateValue - $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'region': region,
      'building': building,
      'privacy': privacy,
      'status': status,
      'appointment_date': appointmentDate.toIso8601String(),
      'host': hostId,
      'stream_link': streamLink,
      'note_shared': noteShared,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'region': region,
      'building': building,
      'privacy': privacy,
      'status': status,
      'appointment_date': appointmentDate.toIso8601String(),
      'host_id': hostId,
      'stream_link': streamLink,
      'note_shared': noteShared,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      region: map['region'],
      building: map['building'],
      privacy: map['privacy'] ?? 'public',
      status: map['status'] ?? 'active',
      appointmentDate: _parseDateTime(map['appointment_date']) ?? DateTime.now(),
      hostId: map['host_id'] ?? '',
      streamLink: map['stream_link'],
      noteShared: map['note_shared'],
      created: _parseDateTime(map['created']) ?? DateTime.now(),
      updated: _parseDateTime(map['updated']) ?? DateTime.now(),
    );
  }
}

