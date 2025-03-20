import 'package:pontocerto/models/ponto.dart';

class Relatorio {
  DateTime data;
  List<Ponto> pontos;
  double totalHorasTrabalhadas;

  Relatorio({
    required this.data,
    required this.pontos,
    required this.totalHorasTrabalhadas,
  });
}