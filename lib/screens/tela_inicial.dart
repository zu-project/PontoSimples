import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pontocerto/models/ponto.dart';
import 'package:pontocerto/services/geolocator_service.dart';
import 'package:pontocerto/services/database_service.dart';
import 'package:pontocerto/widgets/botao_registrar.dart';
import 'package:pontocerto/screens/tela_relatorio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  String _nomeColaborador = "NOME DO COLABORADOR";
  final TextEditingController _nomeController = TextEditingController();

  // Variáveis para o banner do AdMob
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _carregarPontosDoDia();
    _carregarNomeColaborador();
    _initAd(); // Inicializar o anúncio
  }

  // Inicializar o banner do AdMob
  void _initAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5008862023821727/3365906652', // Substitua pelo seu Ad Unit ID real
      size: AdSize.largeBanner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('Falha ao carregar o anúncio: $error');
          ad.dispose();
          setState(() {
            _isAdLoaded = false;
          });
        },
      ),
    );
    _bannerAd!.load(); // Carregar o anúncio
  }

  // Método para recarregar o banner
  void _reloadAd() {
    if (_bannerAd != null) {
      _bannerAd!.dispose(); // Descartar o banner atual
    }
    _initAd(); // Recriar e recarregar o banner
  }

  Future<void> _carregarNomeColaborador() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nomeColaborador = prefs.getString('nomeColaborador') ?? "NOME DO COLABORADOR";
      _nomeController.text = _nomeColaborador;
    });
  }

  Future<void> _salvarNomeColaborador(String nome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nomeColaborador', nome);
    setState(() {
      _nomeColaborador = nome;
    });
  }

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
    _reloadAd(); // Recarregar o banner ao atualizar a tela
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
      // Exibir o loading enquanto obtém a localização
      showDialog(
        context: context,
        barrierDismissible: false, // Impede que o usuário feche o diálogo clicando fora
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text("Obtendo localização..."),
                ],
              ),
            ),
          );
        },
      );

      final position = await _geolocatorService.getCurrentLocation();
      if (position != null) {
        String? cidade = await _geolocatorService.getCityFromCoordinates(
            position.latitude, position.longitude);

        // Fechar o diálogo de loading
        Navigator.of(context).pop();

        if (cidade == null || cidade.isEmpty) {
          _cidadeExibida = "Bairro Desconhecido, Estado Desconhecido";
        } else {
          _cidadeExibida = cidade;
        }
        _cidadeController.text = _cidadeExibida ?? "";
        _exibirDialogoConfirmacao(position.latitude, position.longitude);
      } else {
        // Fechar o diálogo de loading em caso de erro
        Navigator.of(context).pop();
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
  void dispose() {
    _bannerAd?.dispose(); // Liberar o anúncio ao descartar a tela
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _exibirDialogoNome,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('APP CHECK PONTO!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(_nomeColaborador.toUpperCase(), style: TextStyle(fontSize: 16, color: Colors.deepPurpleAccent)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.assignment),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaRelatorio(nomeColaborador: _nomeColaborador),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregarPontosDoDia,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    BotaoRegistrar(onPressed: _registrarPonto),
                    SizedBox(height: 20),
                    Text('Horários de Hoje: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
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
            // Adicionar o banner na parte inferior
            if (_isAdLoaded && _bannerAd != null)
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}