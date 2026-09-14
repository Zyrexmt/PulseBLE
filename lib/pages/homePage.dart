import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pulseble/service/firestoneService.dart';
import 'package:pulseble/service/leituraBle.dart';
import 'package:pulseble/widgets/deviceConnect.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final _firestoreService = FirestoreService();
  bool _conectando = false;

  @override  
  void initState() {
    super.initState();
  }

  void _iniciarScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _conectar(BluetoothDevice device) async {
    setState(() => _conectando = true);
    FlutterBluePlus.stopScan();

    try {
      await device.connect(timeout: Duration(seconds: 10), license: License.nonprofit);
      final servicos = await device.discoverServices();

      int bateria = 0;
      for (final servico in servicos) {
        if(servico.uuid.toString().toLowerCase().contains('180f')) {
          for (final caracteristica in servico.characteristics) {
            if (caracteristica.uuid.toString().toLowerCase().contains('2a19')) {
              final valor = await caracteristica.read();
              if (valor.isNotEmpty) bateria = valor.first;
            }
          }
        }
      }

      final nome = device.platformName.isNotEmpty ? device.platformName : 'Dispositivo sem nome';
      if(!mounted) return;
      setState(() {
        _conectando = false;
      });
      _mostrarPopup(device: device, nome: nome, bateria: bateria);
    } catch (e) {
      setState(() {
        _conectando = false;
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao conectar: $e')));
      }
    }
  }

  void _mostrarPopup({required BluetoothDevice device, required String nome, required int bateria}) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => DeviceConnectDialog(nomeDispositivo: nome, bateria: bateria, onSalvar: () async {
      await _firestoreService.salvarLeitura(LeituraBle(nomeDispositivo: nome, bateria: bateria, deviceId: device.remoteId.toString(), horario: DateTime.now()));
      await device.disconnect();
      if(mounted) Navigator.of(context).pop();
    }, onCancelar: () async {
      await device.disconnect();
      if(mounted) Navigator.of(context).pop();
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivos disponíveis')),
      floatingActionButton: FloatingActionButton(
        onPressed: _iniciarScan,
        child: const Icon(Icons.refresh),
      ),
      body: Stack(
        children: [
          StreamBuilder<List<ScanResult>>(
            stream: FlutterBluePlus.scanResults,
            initialData: const [],
            builder: (context, snapshot) {
              final resultados = snapshot.data!
                  .where((r) => r.device.platformName.isNotEmpty)
                  .toList();
 
              if (resultados.isEmpty) {
                return const Center(child: Text('Procurando dispositivos...'));
              }
 
              return ListView.builder(
                itemCount: resultados.length,
                itemBuilder: (context, i) {
                  final r = resultados[i];
                  return ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(r.device.platformName),
                    subtitle: Text(r.device.remoteId.toString()),
                    trailing: Text('${r.rssi} dBm'),
                    onTap: _conectando ? null : () => _conectar(r.device),
                  );
                },
              );
            },
          ),
          if (_conectando)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Conectando...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}