class RunSession {
  final String sessionId;
  final String mode;
  final double maxDistance;
  final String? leaderId;
  final DateTime createdAt;

  RunSession({
    required this.sessionId,
    required this.mode,
    required this.maxDistance,
    this.leaderId,
    required this.createdAt,
  });

  factory RunSession.fromJson(Map<String, dynamic> json) {
    return RunSession(
      sessionId: json['session_id'] ?? json['sessionId'] ?? '',
      mode: json['mode'] ?? 'no_leader',
      maxDistance: (json['max_distance'] ?? json['maxDistance'] ?? 500).toDouble(),
      leaderId: json['leader_id'] ?? json['leaderId'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'mode': mode,
      'max_distance': maxDistance,
      'leader_id': leaderId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}