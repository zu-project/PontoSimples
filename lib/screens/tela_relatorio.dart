import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pontocerto/models/ponto.dart';
import 'package:pontocerto/services/database_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';

class TelaRelatorio extends StatefulWidget {
  final String nomeColaborador;

  TelaRelatorio({required this.nomeColaborador});

  @override
  _TelaRelatorioState createState() => _TelaRelatorioState();
}

class _TelaRelatorioState extends State<TelaRelatorio> {
  DateTime _dataInicio = DateTime.now().subtract(Duration(days: 30));
  DateTime _dataFim = DateTime.now();
  DateTime _firstDate = DateTime(2000);
  DateTime _lastDate = DateTime(2025, 12, 31);
  Map<DateTime, List<Ponto>> _pontosAgrupados = {};
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _carregarPontos();
  }

  Future<void> _carregarPontos() async {
    Map<DateTime, List<Ponto>> pontosAgrupados = {};
    DateTime dataAtual = _dataInicio;

    while (dataAtual.isBefore(_dataFim.add(Duration(days: 1)))) {
      List<Ponto> pontosDoDia = await _databaseService.listarPontosPorData(dataAtual);
      if (pontosDoDia.isNotEmpty) {
        pontosAgrupados[DateTime(dataAtual.year, dataAtual.month, dataAtual.day)] = pontosDoDia;
      }
      dataAtual = dataAtual.add(Duration(days: 1));
    }

    setState(() {
      _pontosAgrupados = pontosAgrupados;
    });
  }

  Map<String, Duration> calcularHorasTrabalhadasNoDia(List<Ponto> pontos) {
    Duration totalHorasTrabalhadas = Duration();
    if (pontos.length % 2 == 0) {
      for (int i = 0; i < pontos.length; i += 2) {
        DateTime entrada = pontos[i].dataHora;
        DateTime saida = pontos[i + 1].dataHora;
        totalHorasTrabalhadas += saida.difference(entrada);
      }
    } else {
      print('Aviso: Número ímpar de pontos em um dia. Ignorando o último ponto.');
      for (int i = 0; i < pontos.length - 1; i += 2) {
        DateTime entrada = pontos[i].dataHora;
        DateTime saida = pontos[i + 1].dataHora;
        totalHorasTrabalhadas += saida.difference(entrada);
      }
    }

    Duration jornadaNormal = Duration(hours: 8);
    Duration horasExtras = totalHorasTrabalhadas - jornadaNormal;

    return {
      'horasTrabalhadas': totalHorasTrabalhadas,
      'horasExtras': horasExtras,
    };
  }

  Future<void> _gerarPdf() async {
    final pdf = pw.Document();

    List<String> cabecalho = [
      'Data',
      'Entrada 1',
      'Saída 1',
      'Entrada 2',
      'Saída 2',
      'Entrada 3',
      'Saída 3',
      'TOTAL',
      'HORAS\nEXTRAS'
    ];

    List<List<String>> dadosTabela = [];
    Duration totalHorasPeriodo = Duration();
    Duration totalHorasExtrasPeriodo = Duration();

    _pontosAgrupados.forEach((data, pontos) {
      List<String> linha = [DateFormat('dd/MM/yyyy').format(data)];
      for (int i = 0; i < 6; i++) {
        if (i < pontos.length) {
          linha.add(DateFormat('HH:mm').format(pontos[i].dataHora));
        } else {
          linha.add('');
        }
      }
      Map<String, Duration> resultados = calcularHorasTrabalhadasNoDia(pontos);
      Duration horasTrabalhadasNoDia = resultados['horasTrabalhadas']!;
      Duration horasExtrasNoDia = resultados['horasExtras']!;
      totalHorasPeriodo += horasTrabalhadasNoDia;
      totalHorasExtrasPeriodo += horasExtrasNoDia;
      String horasFormatadas = "${horasTrabalhadasNoDia.inHours}:${(horasTrabalhadasNoDia.inMinutes % 60).toString().padLeft(2, '0')}";
      String horasExtrasFormatadas = (horasExtrasNoDia.isNegative ? "-" : "") + "${horasExtrasNoDia.inHours.abs()}:${(horasExtrasNoDia.inMinutes % 60).toString().padLeft(2, '0')}";
      linha.add(horasFormatadas);
      linha.add(horasExtrasFormatadas);
      dadosTabela.add(linha);
    });

    String totalHorasExtrasFormatadas = (totalHorasExtrasPeriodo.isNegative ? "-" : "") + "${totalHorasExtrasPeriodo.inHours.abs()}:${(totalHorasExtrasPeriodo.inMinutes % 60).toString().padLeft(2, '0')}";

    pdf.addPage(pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text('RELATÓRIO DE PONTO', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Colaborador: ${widget.nomeColaborador}', style: pw.TextStyle(fontSize: 14)),
            pw.Text(
              'Período de busca: ${DateFormat('dd/MM/yyyy').format(_dataInicio)} - ${DateFormat('dd/MM/yyyy').format(_dataFim)}',
              style: pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              data: <List<String>>[cabecalho, ...dadosTabela],
            ),
            pw.SizedBox(height: 20),
            pw.Text('TOTAL DO PERÍODO: ${totalHorasPeriodo.inHours}:${(totalHorasPeriodo.inMinutes % 60).toString().padLeft(2, '0')}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('TOTAL DE HORAS EXTRAS: $totalHorasExtrasFormatadas', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        );
      },
    ));

    pdf.addPage(pw.MultiPage(
      build: (pw.Context context) {
        return [
          pw.Footer(title: pw.Text("Elaborado por F.Zu Project.")),
        ];
      },
    ));

    try {
      final bytes = await pdf.save();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/relatorio_ponto.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Relatório de Ponto');
    } catch (e) {
      print('Erro ao gerar ou compartilhar o PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar ou compartilhar o PDF: $e')),
      );
    }
  }

  Future<void> _gerarExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    List<String> cabecalho = [
      'Data',
      'Entrada 1',
      'Saída 1',
      'Entrada 2',
      'Saída 2',
      'Entrada 3',
      'Saída 3',
      'TOTAL',
      'HORAS\nEXTRAS'
    ];

    sheetObject.cell(CellIndex.indexByString("A1")).value = TextCellValue("RELATÓRIO DE PONTO");
    sheetObject.cell(CellIndex.indexByString("A2")).value = TextCellValue("Colaborador: ${widget.nomeColaborador}");
    sheetObject.cell(CellIndex.indexByString("A3")).value = TextCellValue(
      "Período de busca: ${DateFormat('dd/MM/yyyy').format(_dataInicio)} - ${DateFormat('dd/MM/yyyy').format(_dataFim)}",
    );

    for (int i = 0; i < cabecalho.length; i++) {
      sheetObject.cell(CellIndex.indexByString("${String.fromCharCode(65 + i)}5")).value = TextCellValue(cabecalho[i]);
    }

    int linhaAtual = 6;
    Duration totalHorasPeriodo = Duration();
    Duration totalHorasExtrasPeriodo = Duration();

    _pontosAgrupados.forEach((data, pontos) {
      sheetObject.cell(CellIndex.indexByString("A$linhaAtual")).value = TextCellValue(DateFormat('dd/MM/yyyy').format(data));
      for (int i = 0; i < 6; i++) {
        if (i < pontos.length) {
          sheetObject.cell(CellIndex.indexByString("${String.fromCharCode(66 + i)}$linhaAtual")).value = TextCellValue(DateFormat('HH:mm').format(pontos[i].dataHora));
        } else {
          sheetObject.cell(CellIndex.indexByString("${String.fromCharCode(66 + i)}$linhaAtual")).value = TextCellValue('');
        }
      }
      Map<String, Duration> resultados = calcularHorasTrabalhadasNoDia(pontos);
      Duration horasTrabalhadasNoDia = resultados['horasTrabalhadas']!;
      Duration horasExtrasNoDia = resultados['horasExtras']!;
      totalHorasPeriodo += horasTrabalhadasNoDia;
      totalHorasExtrasPeriodo += horasExtrasNoDia;
      String horasFormatadas = "${horasTrabalhadasNoDia.inHours}:${(horasTrabalhadasNoDia.inMinutes % 60).toString().padLeft(2, '0')}";
      String horasExtrasFormatadas = (horasExtrasNoDia.isNegative ? "-" : "") + "${horasExtrasNoDia.inHours.abs()}:${(horasExtrasNoDia.inMinutes % 60).toString().padLeft(2, '0')}";
      sheetObject.cell(CellIndex.indexByString("H$linhaAtual")).value = TextCellValue(horasFormatadas);
      sheetObject.cell(CellIndex.indexByString("I$linhaAtual")).value = TextCellValue(horasExtrasFormatadas);
      linhaAtual++;
    });

    sheetObject.cell(CellIndex.indexByString("A$linhaAtual")).value = TextCellValue('TOTAL DO PERÍODO:');
    String totalPeriodoFormatado = "${totalHorasPeriodo.inHours}:${(totalHorasPeriodo.inMinutes % 60).toString().padLeft(2, '0')}";
    sheetObject.cell(CellIndex.indexByString("H$linhaAtual")).value = TextCellValue(totalPeriodoFormatado);

    sheetObject.cell(CellIndex.indexByString("A${linhaAtual + 1}")).value = TextCellValue('TOTAL DE HORAS EXTRAS:');
    String totalExtrasFormatado = (totalHorasExtrasPeriodo.isNegative ? "-" : "") + "${totalHorasExtrasPeriodo.inHours.abs()}:${(totalHorasExtrasPeriodo.inMinutes % 60).toString().padLeft(2, '0')}";
    sheetObject.cell(CellIndex.indexByString("H${linhaAtual + 1}")).value = TextCellValue(totalExtrasFormatado);

    try {
      List<int>? bytes = excel.save();
      if (bytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/relatorio_ponto.xlsx');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Relatório de Ponto (Excel)');
      } else {
        print('Erro ao gerar o arquivo Excel: Bytes nulos.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar o arquivo Excel: Bytes nulos.')),
        );
      }
    } catch (e) {
      print('Erro ao gerar ou compartilhar o Excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar ou compartilhar o Excel: $e')),
      );
    }
  }

  Future<void> _selecionarDataInicio(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: _firstDate,
      lastDate: _lastDate,
    );
    if (picked != null && picked != _dataInicio) {
      setState(() {
        _dataInicio = picked;
        _carregarPontos();
      });
    }
  }

  Future<void> _selecionarDataFim(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataFim,
      firstDate: _firstDate,
      lastDate: _lastDate,
    );
    if (picked != null && picked != _dataFim) {
      setState(() {
        _dataFim = picked;
        _carregarPontos();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Relatório de Ponto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Text('Data Inicial: ${DateFormat('dd/MM/yyyy').format(_dataInicio)}'),
                ElevatedButton(
                  onPressed: () => _selecionarDataInicio(context),
                  child: Text('Selecionar'),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Text('Data Final: ${DateFormat('dd/MM/yyyy').format(_dataFim)}'),
                ElevatedButton(
                  onPressed: () => _selecionarDataFim(context),
                  child: Text('Selecionar'),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: _gerarPdf,
                  child: Text('Gerar PDF'),
                ),
                ElevatedButton(
                  onPressed: _gerarExcel,
                  child: Text('Gerar Excel'),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _pontosAgrupados.length,
                itemBuilder: (context, index) {
                  DateTime data = _pontosAgrupados.keys.elementAt(index);
                  List<Ponto> pontosDoDia = _pontosAgrupados[data]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(data),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: pontosDoDia.length,
                        itemBuilder: (context, index) {
                          final ponto = pontosDoDia[index];
                          return ListTile(
                            title: Text(DateFormat('HH:mm').format(ponto.dataHora)),
                            subtitle: Text('${ponto.cidade}'),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}