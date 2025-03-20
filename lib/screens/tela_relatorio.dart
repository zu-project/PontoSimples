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
import 'package:excel/excel.dart'; // Importe a biblioteca excel

class TelaRelatorio extends StatefulWidget {
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

  Future<void> _selecionarDataInicio(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: _firstDate,
      lastDate: _lastDate,
    );
    if (picked != null && picked != _dataInicio)
      setState(() {
        _dataInicio = picked;
        _carregarPontos();
      });
  }

  Future<void> _selecionarDataFim(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataFim,
      firstDate: _firstDate,
      lastDate: _lastDate,
    );
    if (picked != null && picked != _dataFim)
      setState(() {
        _dataFim = picked;
        _carregarPontos();
      });
  }

  Future<void> _mostrarDialogoEdicao(BuildContext context, Ponto ponto) async {
    DateTime dataHora = ponto.dataHora;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Editar Horário'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Data e Hora Atual: ${DateFormat('dd/MM/yyyy HH:mm').format(ponto.dataHora)}'),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  // Mostrar DatePicker para selecionar a data
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: dataHora,
                    firstDate: _firstDate,
                    lastDate: _lastDate,
                  );
                  if (pickedDate != null) {
                    // Mostrar TimePicker para selecionar a hora
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(dataHora),
                      builder: (BuildContext context, Widget? child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        );
                      },
                    );
                    if (pickedTime != null) {
                      setState(() {
                        // Combine a data e a hora selecionadas
                        dataHora = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: Text('Alterar Data e Hora'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Deletar'),
              onPressed: () {
                _deletarPonto(ponto);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Salvar'),
              onPressed: () {
                _salvarPontoEditado(ponto, dataHora);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletarPonto(Ponto ponto) async {
    final db = await _databaseService.database;
    await db.delete(
      'pontos',
      where: 'id = ?',
      whereArgs: [ponto.id],
    );
    _carregarPontos();
  }

  Future<void> _salvarPontoEditado(Ponto ponto, DateTime novaDataHora) async {
    final db = await _databaseService.database;
    await db.update(
      'pontos',
      {'dataHora': novaDataHora.toIso8601String()},
      where: 'id = ?',
      whereArgs: [ponto.id],
    );
    ponto.dataHora = novaDataHora;
    _carregarPontos();
  }

  Map<String, Duration> calcularHorasTrabalhadasNoDia(List<Ponto> pontos) {
    Duration totalHorasTrabalhadas = Duration();
    if (pontos.length % 2 == 0) { // Garante que haja um número par de pontos (entrada e saída)
      for (int i = 0; i < pontos.length; i += 2) {
        DateTime entrada = pontos[i].dataHora;
        DateTime saida = pontos[i + 1].dataHora;
        totalHorasTrabalhadas += saida.difference(entrada);
      }
    } else {
      // Tratar caso ímpar (pode ser um erro ou uma situação específica)
      print('Aviso: Número ímpar de pontos em um dia. Ignorando o último ponto.');
      for (int i = 0; i < pontos.length - 1; i += 2) {
        DateTime entrada = pontos[i].dataHora;
        DateTime saida = pontos[i + 1].dataHora;
        totalHorasTrabalhadas += saida.difference(entrada);
      }
    }

    // Calcular horas extras (considerando 8 horas como jornada normal)
    Duration jornadaNormal = Duration(hours: 8);
    // Removendo a condição para permitir horas extras negativas
    Duration horasExtras = totalHorasTrabalhadas - jornadaNormal;

    return {
      'horasTrabalhadas': totalHorasTrabalhadas,
      'horasExtras': horasExtras,
    };
  }

  Future<void> _gerarPdf() async {
    final pdf = pw.Document();

    // Definir o cabeçalho da tabela
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

    // Criar a tabela
    List<List<String>> dadosTabela = [];
    Duration totalHorasPeriodo = Duration();
    Duration totalHorasExtrasPeriodo = Duration(); // Inicializar o total de horas extras do período

    _pontosAgrupados.forEach((data, pontos) {
      List<String> linha = [DateFormat('dd/MM/yyyy').format(data)];

      // Preencher os horários de entrada e saída
      for (int i = 0; i < 6; i++) { // 3 entradas e 3 saídas = 6
        if (i < pontos.length) {
          linha.add(DateFormat('HH:mm').format(pontos[i].dataHora));
        } else {
          linha.add(''); // Preencher com vazio se não houver ponto
        }
      }

      // Calcular as horas trabalhadas e extras no dia
      Map<String, Duration> resultados = calcularHorasTrabalhadasNoDia(pontos);
      Duration horasTrabalhadasNoDia = resultados['horasTrabalhadas']!;
      Duration horasExtrasNoDia = resultados['horasExtras']!;

      totalHorasPeriodo += horasTrabalhadasNoDia;
      totalHorasExtrasPeriodo += horasExtrasNoDia; // Acumular o total de horas extras

      // Adicionar o total de horas do dia e horas extras
      String horasFormatadas = "${horasTrabalhadasNoDia.inHours}:${(horasTrabalhadasNoDia.inMinutes % 60).toString().padLeft(2, '0')}";
      // Use o sinal de menos se as horas extras forem negativas
      String horasExtrasFormatadas = (horasExtrasNoDia.isNegative ? "-" : "") + "${horasExtrasNoDia.inHours.abs()}:${(horasExtrasNoDia.inMinutes % 60).toString().padLeft(2, '0')}";
      linha.add(horasFormatadas);
      linha.add(horasExtrasFormatadas);

      dadosTabela.add(linha);
    });

    // Calcula o total de horas extras formatadas ANTES de construir o PDF
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
            pw.Text(
              'Período de busca: ${DateFormat('dd/MM/yyyy').format(_dataInicio)} - ${DateFormat('dd/MM/yyyy').format(_dataFim)}',
              style: pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              data: <List<String>>[
                cabecalho, // Cabeçalho da tabela
                ...dadosTabela, // Dados da tabela
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('TOTAL DO PERÍODO: ${totalHorasPeriodo.inHours}:${(totalHorasPeriodo.inMinutes % 60).toString().padLeft(2, '0')}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            // Use a string formatada que já calculamos
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
        }));


    // Salvar o PDF
    try {
      final bytes = await pdf.save();

      // Get the device's document directory
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/relatorio_ponto.pdf');

      // Write the file
      await file.writeAsBytes(bytes);

      // Share the PDF
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

    // Definir o cabeçalho da tabela
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

    // Adicionar o cabeçalho à planilha
    for (int i = 0; i < cabecalho.length; i++) {
      sheetObject.cell(CellIndex.indexByString("${String.fromCharCode(65 + i)}1")).value = cabecalho[i]; // A = 65
    }

    // Adicionar os dados à planilha e calcular o total
    int linhaAtual = 2;
    Duration totalHorasPeriodo = Duration();
    Duration totalHorasExtrasPeriodo = Duration(); // Inicializar o total de horas extras do período

    _pontosAgrupados.forEach((data, pontos) {
      sheetObject.cell(CellIndex.indexByString("A$linhaAtual")).value = DateFormat('dd/MM/yyyy').format(data);

      // Preencher os horários de entrada e saída
      for (int i = 0; i < 6; i++) { // 3 entradas e 3 saídas = 6
        if (i < pontos.length) {
          sheetObject.cell(CellIndex.indexByString("${String.fromCharCode(66 + i)}$linhaAtual")).value = DateFormat('HH:mm').format(pontos[i].dataHora);
        } else {
          sheetObject.cell(CellIndex.indexByString("${String.fromCharCode(66 + i)}$linhaAtual")).value = '';// Preencher com vazio se não houver ponto
        }
      }

      // Calcular as horas trabalhadas e extras no dia
      Map<String, Duration> resultados = calcularHorasTrabalhadasNoDia(pontos);
      Duration horasTrabalhadasNoDia = resultados['horasTrabalhadas']!;
      Duration horasExtrasNoDia = resultados['horasExtras']!;

      totalHorasPeriodo += horasTrabalhadasNoDia;
      totalHorasExtrasPeriodo += horasExtrasNoDia; // Acumular o total de horas extras

      // Adicionar o total de horas do dia e horas extras à planilha
      String horasFormatadas = "${horasTrabalhadasNoDia.inHours}:${(horasTrabalhadasNoDia.inMinutes % 60).toString().padLeft(2, '0')}";
      // Use o sinal de menos se as horas extras forem negativas
      String horasExtrasFormatadas = (horasExtrasNoDia.isNegative ? "-" : "") + "${horasExtrasNoDia.inHours.abs()}:${(horasExtrasNoDia.inMinutes % 60).toString().padLeft(2, '0')}";

      sheetObject.cell(CellIndex.indexByString("H$linhaAtual")).value = horasFormatadas; // Coluna H (TOTAL)
      sheetObject.cell(CellIndex.indexByString("I$linhaAtual")).value = horasExtrasFormatadas; // Coluna I (HORAS EXTRAS)


      linhaAtual++;
    });

    // Adicionar o total de horas do período ao final do relatório
    sheetObject.cell(CellIndex.indexByString("A$linhaAtual")).value = 'TOTAL DO PERÍODO:';
    String totalPeriodoFormatado = "${totalHorasPeriodo.inHours}:${(totalHorasPeriodo.inMinutes % 60).toString().padLeft(2, '0')}";
    sheetObject.cell(CellIndex.indexByString("H$linhaAtual")).value = totalPeriodoFormatado; // Coluna H (TOTAL)

    // Adicionar o total de horas extras do período ao final do relatório
    sheetObject.cell(CellIndex.indexByString("A${linhaAtual + 1}")).value = 'TOTAL DE HORAS EXTRAS:';
    // Use o sinal de menos se as horas extras forem negativas
    String totalExtrasFormatado = (totalHorasExtrasPeriodo.isNegative ? "-" : "") + "${totalHorasExtrasPeriodo.inHours.abs()}:${(totalHorasExtrasPeriodo.inMinutes % 60).toString().padLeft(2, '0')}";
    sheetObject.cell(CellIndex.indexByString("H${linhaAtual + 1}")).value = totalExtrasFormatado; // Coluna H (TOTAL)


    // Salvar o Excel
    try {
      List<int>? bytes = excel.save();
      if (bytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/relatorio_ponto.xlsx');
        await file.writeAsBytes(bytes);

        // Compartilhar o Excel
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
                Text(
                    'Data Inicial: ${DateFormat('dd/MM/yyyy').format(_dataInicio)}'),
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
                  onPressed: () => _gerarPdf(),
                  child: Text('Gerar PDF'),
                ),
                ElevatedButton(
                  onPressed: () => _gerarExcel(),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: pontosDoDia.length,
                        itemBuilder: (context, index) {
                          final ponto = pontosDoDia[index];
                          return InkWell(
                            onTap: () {
                              _mostrarDialogoEdicao(context, ponto);
                            },
                            child: ListTile(
                              title: Text(DateFormat('HH:mm').format(ponto.dataHora)),
                              subtitle: Text('${ponto.cidade}'),
                            ),
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