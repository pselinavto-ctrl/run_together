class RunSession {
  final String sessionId;
  final String mode;
  final double maxDistance;
  final String? leaderId;
  final DateTime createdAt;
  final String status;
  final DateTime? startTime;
  final int pausedDuration;

  RunSession({
    required this.sessionId,
    required this.mode,
    required this.maxDistance,
    this.leaderId,
    required this.createdAt,
    this.status = 'waiting',
    this.startTime,
    this.pausedDuration = 0,
  });

  factory RunSession.fromJson(Map<String, dynamic> json) {
    return RunSession(
      sessionId: json['session_id'] ?? json['sessionId'] ?? '',
      mode: json['mode'] ?? 'no_leader',
      maxDistance: (json['max_distance'] ?? json['maxDistance'] ?? 500).toDouble(),
      leaderId: json['leader_id'] ?? json['leaderId'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      status: json['status'] ?? 'waiting',
      startTime: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      pausedDuration: json['paused_duration'] ?? 0,
    );
  }

  RunSession copyWith({
    String? status,
    DateTime? startTime,
    int? pausedDuration,
    String? leaderId,
  }) {
    return RunSession(
      sessionId: sessionId,
      mode: mode,
      maxDistance: maxDistance,
      leaderId: leaderId ?? this.leaderId,
      createdAt: createdAt,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      pausedDuration: pausedDuration ?? this.pausedDuration,
    );
  }
}