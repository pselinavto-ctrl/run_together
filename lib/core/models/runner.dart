class Runner {
  final String userId;
  final String name;
  final double lat;
  final double lon;
  final DateTime updatedAt;

  Runner({
    required this.userId,
    required this.name,
    required this.lat,
    required this.lon,
    required this.updatedAt,
  });

  // Преобразование из JSON (ответ сервера)
  factory Runner.fromJson(Map<String, dynamic> json) {
    return Runner(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Преобразование в JSON (для отправки на сервер)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'lat': lat,
      'lon': lon,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Runner($userId, $name, lat: $lat, lon: $lon)';
  }
}