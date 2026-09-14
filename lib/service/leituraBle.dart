class LeituraBle {
  final String nomeDispositivo;
  final int bateria;
  final String deviceId;
  final DateTime horario;

  LeituraBle({
    required this.nomeDispositivo,
    required this.bateria,
    required this.deviceId,
    required this.horario,
  });

  Map<String, dynamic> toMap() {
    return {
      'nomeDispositivo': nomeDispositivo,
      'bateria': bateria,
      'deviceId': deviceId,
      'horario': horario,
    };
  }

  factory LeituraBle.fromMap(Map<String, dynamic> data) {
    return LeituraBle(
      nomeDispositivo: data['nomeDispositivo'],
      bateria: data['bateria'],
      deviceId: data['deviceId'],
      horario: data['horario'],
    );
  }
}
