import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pontocerto/models/ponto.dart';
import 'package:pontocerto/services/geolocator_service.dart';
import 'package:pontocerto/services/database_service.dart';
import 'package:pontocerto/widgets/botao_registrar.dart';
import 'package:pontocerto/screens/tela_relatorio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Adicionar esta importação

class TelaInicial extends StatefulWidget {
  @override
  _TelaInicialState createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  final GeolocatorService _geolocatorService = GeolocatorService();
  final DatabaseService _databaseService = DatabaseService();
  List<Ponto> pontosDoDia = [];
  String? _cidadeExibida;
  final TextEditingController _cidadeController = TextEditingController();
  String _nomeColaborador = "NOME DO COLABORADOR"; // Variável para o nome do colaborador
  final TextEditingController _nomeController = TextEditingController(); // Controlador para edição do nome

  @override
  void initState() {
    super.initState();
    _carregarPontosDoDia();
    _carregarNomeColaborador(); // Carregar o nome salvo ao iniciar
  }

  // Carregar o nome do colaborador salvo
  Future<void> _carregarNomeColaborador() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nomeColaborador = prefs.getString('nomeColaborador') ?? "NOME DO COLABORADOR";
      _nomeController.text = _nomeColaborador;
    });
  }

  // Salvar o nome do colaborador
  Future<void> _salvarNomeColaborador(String nome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nomeColaborador', nome);
    setState(() {
      _nomeColaborador = nome;
    });
  }

  // Exibir diálogo para editar o nome
  Future<void> _exibirDialogoNome() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Editar Nome do Colaborador'),
          content: TextField(
            controller: _nomeController,
            decoration: InputDecoration(labelText: 'Digite o nome'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Salvar'),
              onPressed: () {
                if (_nomeController.text.isNotEmpty) {
                  _salvarNomeColaborador(_nomeController.text);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
          _cidadeExibida = "Bairro Desconhecido, Estado Desconhecido";
        } else {
          _cidadeExibida = cidade;
        }
        _cidadeController.text = _cidadeExibida ?? "";

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
        title: GestureDetector(
          onTap: _exibirDialogoNome, // Abrir diálogo ao clicar no texto
          child: Text(
            'Horário de Ponto - $_nomeColaborador',
            style: TextStyle(fontSize: 20),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.assignment),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaRelatorio(nomeColaborador: _nomeColaborador), // Passar o nome para TelaRelatorio
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
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