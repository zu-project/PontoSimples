class Ponto {
  int? id;
  DateTime dataHora;
  double latitude;
  double longitude;
  String cidade;

  Ponto({
    this.id,
    required this.dataHora,
    required this.latitude,
    required this.longitude,
    required this.cidade,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dataHora': dataHora.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'cidade': cidade,
    };
  }

  factory Ponto.fromMap(Map<String, dynamic> map) {
    return Ponto(
      id: map['id'],
      dataHora: DateTime.parse(map['dataHora']),
      latitude: map['latitude'],
      longitude: map['longitude'],
      cidade: map['cidade'],
    );
  }
}