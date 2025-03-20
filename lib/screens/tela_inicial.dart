import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pontocerto/models/ponto.dart';
import 'package:pontocerto/services/geolocator_service.dart';
import 'package:pontocerto/services/database_service.dart';
import 'package:pontocerto/widgets/botao_registrar.dart';
import 'package:pontocerto/screens/tela_relatorio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class TelaInicial extends StatefulWidget {
  @override
  _TelaInicialState createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  final GeolocatorService _geolocatorService = GeolocatorService();
  final DatabaseService _databaseService = DatabaseService();
  List<Ponto> pontosDoDia = [];
  String? _cidadeExibida; // Variável para armazenar a cidade a ser exibida
  final TextEditingController _cidadeController = TextEditingController(); // Controlador para o campo de texto

  @override
  void initState() {
    super.initState();
    _carregarPontosDoDia();
  }

  Future<void> _carregarPontosDoDia() async {
    DateTime hoje = DateTime.now();
    List<Ponto> pontos = await _databaseService.listarPontosPorData(hoje);
    setState(() {
      pontosDoDia = pontos;
    });
  }

  Future<void> _registrarPonto() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isDenied) {
        _exibirMensagem('Permissão de localização negada.');
        return;
      }
    }
    if (status.isPermanentlyDenied) {
      _exibirMensagem('Permissão de localização negada permanentemente. Abra as configurações do app.');
      openAppSettings();
      return;
    }

    if (status.isGranted) {
      final position = await _geolocatorService.getCurrentLocation();
      if (position != null) {
        String? cidade = await _geolocatorService.getCityFromCoordinates(
            position.latitude, position.longitude);

        if (cidade == null || cidade.isEmpty) {
          _cidadeExibida = "Bairro Desconhecido, Estado Desconhecido"; // Mensagem padrão
        } else {
          _cidadeExibida = cidade; // Usar o valor obtido da geolocalização
        }
        _cidadeController.text = _cidadeExibida ?? ""; // Inicializar o campo de texto com o valor obtido

        // Exibir um diálogo para o usuário confirmar ou editar a cidade
        _exibirDialogoConfirmacao(position.latitude, position.longitude);

      } else {
        _exibirMensagem('Não foi possível obter a localização.');
      }
    }
  }


  Future<void> _exibirDialogoConfirmacao(double latitude, double longitude) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar Localização'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('A localização detectada é:'),
              Text(_cidadeExibida ?? "Localização Desconhecida"),
              TextField(
                controller: _cidadeController,
                decoration: InputDecoration(labelText: 'Digite a cidade (opcional):'),
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
              child: Text('Confirmar'),
              onPressed: () async {
                // Salvar o ponto com a cidade digitada pelo usuário (se houver)
                final ponto = Ponto(
                  dataHora: DateTime.now(),
                  latitude: latitude,
                  longitude: longitude,
                  cidade: _cidadeController.text.isNotEmpty ? _cidadeController.text : _cidadeExibida ?? "Localização Desconhecida",
                );
                await _databaseService.inserirPonto(ponto);
                _carregarPontosDoDia();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  void _exibirMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Horário de Ponto - Flavio Zuicker',
          style: TextStyle(fontSize: 20), // Ajuste o tamanho da fonte aqui
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.assignment),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TelaRelatorio()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(  // ADICIONADO AQUI
        onRefresh: _carregarPontosDoDia,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              BotaoRegistrar(onPressed: _registrarPonto),
              SizedBox(height: 20),
              Text('Horários de Hoje:'),
              Expanded(
                child: ListView.builder(
                  itemCount: pontosDoDia.length,
                  itemBuilder: (context, index) {
                    final ponto = pontosDoDia[index];
                    return ListTile(
                      title: Text(DateFormat('HH:mm:ss').format(ponto.dataHora)),
                      subtitle: Text('${ponto.cidade} - ${ponto.latitude}, ${ponto.longitude}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}