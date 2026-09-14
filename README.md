# PulseBLE — Guia de Setup Completo

**PulseBLE** é um aplicativo Flutter que detecta dispositivos Bluetooth Low Energy (BLE) próximos, captura o nome do dispositivo e o nível de bateria em tempo real, e salva todas as informações no Firebase Realtime Database para monitoramento centralizado.

---

## 📋 Pré-requisitos

- Flutter 3.0+
- Dart 2.17+
- Android 12+ (API 31+) ou iOS 13+
- Conta Firebase ativa
- `flutterfire_cli` instalado (`dart pub global activate flutterfire_cli`)

---

## 1️⃣ Instalação de Pacotes

Execute os comandos abaixo na raiz do seu projeto:

```bash
flutter pub add firebase_core
flutter pub add cloud_firestore
flutter pub add flutter_blue_plus
flutter pub add permission_handler
```

**Nota**: O pacote `permission_handler` é opcional mas recomendado para solicitar permissões de forma mais robusta em Android 12+.

---

## 2️⃣ Configuração Firebase

### Passo 1: Gerar arquivo de configuração

```bash
flutterfire configure
```

Este comando cria o arquivo `lib/firebase_options.dart` automaticamente. Selecione:
- Plataformas: Android e iOS
- Projeto Firebase já existente (ou crie um novo no console)

### Passo 2: Verificar inicialização no `main.dart`

Certifique-se de que `Firebase.initializeApp()` é chamado antes de qualquer uso:

```dart
import 'firebase_core/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}
```

---

## 3️⃣ Permissões — Android

Em `android/app/src/main/AndroidManifest.xml`, adicione as permissões **antes** da tag `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <!-- Permissões de Bluetooth e Localização -->
  <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
  <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

  <application>
    <!-- seu conteúdo aqui -->
  </application>
</manifest>
```

### Verificar SDK mínima

Em `android/app/build.gradle`, confirme que:

```gradle
android {
    defaultConfig {
        minSdkVersion 21  // flutter_blue_plus recomenda 21+
        targetSdkVersion 33
    }
}
```

### Permissões em Tempo de Execução (Android 12+)

O `flutter_blue_plus` solicita automaticamente as permissões ao iniciar o scan. Se isso não acontecer, adicione manualmente com `permission_handler`:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestBluetoothPermissions() async {
  final status = await Permission.bluetoothScan.request();
  if (status.isDenied) {
    print('Permissão de Bluetooth negada');
  }
}
```

---

## 4️⃣ Permissões — iOS

Em `ios/Runner/Info.plist`, dentro da tag `<dict>` principal, adicione:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Este app usa Bluetooth para conectar com seus dispositivos e monitorar bateria</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>Este app usa Bluetooth para conectar com seus dispositivos e monitorar bateria</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>A localização é necessária para escanear dispositivos Bluetooth próximos</string>
```

### iOS 13+: Modo Background

Se quiser monitoramento em background, em `ios/Podfile`, descomente:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_LOCATION=1',
      ]
    end
  end
end
```

---

## 5️⃣ Estrutura de Arquivos

Organize seu projeto `lib/` assim:

```
lib/
 ├── main.dart                              # inicialização + MaterialApp
 ├── models/
 │   └── leitura_ble.dart                   # modelo de dados (serializável)
 ├── services/
 │   ├── firestore_service.dart             # salvar/ler leituras no Firebase
 │   └── ble_service.dart                   # scan e conexão BLE
 ├── screens/
 │   └── home_screen.dart                   # lista de dispositivos + ações
 └── widgets/
     └── device_card.dart                   # card individual do dispositivo
```

---

## 6️⃣ Arquivo de Modelo (`models/leitura_ble.dart`)

```dart
class LeituraBLE {
  final String id;
  final String nomeDispositivo;
  final int nivelBateria;
  final String enderecoMAC;
  final DateTime dataLeitura;
  final int sinalRSSI;

  LeituraBLE({
    required this.id,
    required this.nomeDispositivo,
    required this.nivelBateria,
    required this.enderecoMAC,
    required this.dataLeitura,
    required this.sinalRSSI,
  });

  // Converter para Map (salvar no Firestore)
  Map<String, dynamic> toMap() {
    return {
      'nomeDispositivo': nomeDispositivo,
      'nivelBateria': nivelBateria,
      'enderecoMAC': enderecoMAC,
      'dataLeitura': dataLeitura.toIso8601String(),
      'sinalRSSI': sinalRSSI,
    };
  }

  // Converter de Map (ler do Firestore)
  factory LeituraBLE.fromMap(Map<String, dynamic> map, String id) {
    return LeituraBLE(
      id: id,
      nomeDispositivo: map['nomeDispositivo'] ?? 'Desconhecido',
      nivelBateria: map['nivelBateria'] ?? 0,
      enderecoMAC: map['enderecoMAC'] ?? '',
      dataLeitura: DateTime.parse(map['dataLeitura'] ?? DateTime.now().toIso8601String()),
      sinalRSSI: map['sinalRSSI'] ?? 0,
    );
  }
}
```

---

## 7️⃣ Serviço Firestore (`services/firestore_service.dart`)

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leitura_ble.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _colecao = 'leituras_ble';

  // Salvar uma leitura
  Future<void> salvarLeitura(LeituraBLE leitura) async {
    try {
      await _db
          .collection(_colecao)
          .doc(leitura.id)
          .set(leitura.toMap(), SetOptions(merge: true));
      print('✅ Leitura salva: ${leitura.nomeDispositivo}');
    } catch (e) {
      print('❌ Erro ao salvar: $e');
      rethrow;
    }
  }

  // Recuperar todas as leituras
  Future<List<LeituraBLE>> obterLeituras() async {
    try {
      final snapshot = await _db.collection(_colecao).get();
      return snapshot.docs
          .map((doc) => LeituraBLE.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar leituras: $e');
      return [];
    }
  }

  // Stream em tempo real
  Stream<List<LeituraBLE>> obterLeituras() {
    return _db.collection(_colecao).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => LeituraBLE.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  // Deletar uma leitura
  Future<void> deletarLeitura(String id) async {
    try {
      await _db.collection(_colecao).doc(id).delete();
      print('✅ Leitura deletada');
    } catch (e) {
      print('❌ Erro ao deletar: $e');
      rethrow;
    }
  }
}
```

---

## 8️⃣ Serviço BLE (`services/ble_service.dart`)

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEService {
  final FlutterBluePlus _ble = FlutterBluePlus();

  // Iniciar scan
  Future<void> iniciarScan({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      await _ble.startScan(timeout: timeout);
      print('🔍 Scan iniciado');
    } catch (e) {
      print('❌ Erro ao iniciar scan: $e');
      rethrow;
    }
  }

  // Parar scan
  Future<void> pararScan() async {
    try {
      await _ble.stopScan();
      print('⏹️ Scan parado');
    } catch (e) {
      print('❌ Erro ao parar scan: $e');
    }
  }

  // Stream de dispositivos encontrados
  Stream<List<ScanResult>> get resultadosScan => _ble.scanResults;

  // Conectar a um dispositivo
  Future<void> conectar(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      print('✅ Conectado em: ${device.remoteId}');
    } catch (e) {
      print('❌ Erro ao conectar: $e');
      rethrow;
    }
  }

  // Ler nível de bateria (UUID padrão GATT: 0x180F / 0x2A19)
  Future<int> lerNivelBateria(BluetoothDevice device) async {
    try {
      final servicos = await device.discoverServices();
      
      for (var servico in servicos) {
        if (servico.uuid.toString().toLowerCase() == '0000180f-0000-1000-8000-00805f9b34fb') {
          // Serviço de bateria encontrado
          for (var caracteristica in servico.characteristics) {
            if (caracteristica.uuid.toString().toLowerCase() == '00002a19-0000-1000-8000-00805f9b34fb') {
              // Característica de nível de bateria
              final valor = await caracteristica.read();
              if (valor.isNotEmpty) {
                return valor[0]; // Valor de 0-100%
              }
            }
          }
        }
      }
      return 0; // Bateria não disponível
    } catch (e) {
      print('⚠️ Erro ao ler bateria: $e');
      return 0;
    }
  }

  // Desconectar
  Future<void> desconectar(BluetoothDevice device) async {
    try {
      await device.disconnect();
      print('🔌 Desconectado de: ${device.remoteId}');
    } catch (e) {
      print('❌ Erro ao desconectar: $e');
    }
  }
}
```

---

## 9️⃣ Home Screen (`screens/home_screen.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../services/firestore_service.dart';
import '../models/leitura_ble.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BLEService _bleService = BLEService();
  final FirestoreService _firestoreService = FirestoreService();
  
  bool _scanning = false;
  List<ScanResult> _dispositivos = [];

  @override
  void dispose() {
    _bleService.pararScan();
    super.dispose();
  }

  void _iniciarScan() async {
    setState(() => _scanning = true);
    _dispositivos.clear();
    
    await _bleService.iniciarScan();
    
    _bleService.resultadosScan.listen((results) {
      setState(() => _dispositivos = results);
    });

    Future.delayed(const Duration(seconds: 10), () {
      setState(() => _scanning = false);
    });
  }

  void _salvarDispositivo(ScanResult device) async {
    await _bleService.conectar(device.device);
    
    final bateria = await _bleService.lerNivelBateria(device.device);
    
    final leitura = LeituraBLE(
      id: device.device.remoteId.toString(),
      nomeDispositivo: device.advertisementData.localName.isNotEmpty
          ? device.advertisementData.localName
          : 'Dispositivo ${device.device.remoteId}',
      nivelBateria: bateria,
      enderecoMAC: device.device.remoteId.toString(),
      dataLeitura: DateTime.now(),
      sinalRSSI: device.rssi,
    );

    await _firestoreService.salvarLeitura(leitura);
    
    await _bleService.desconectar(device.device);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Dispositivo salvo com sucesso!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PulseBLE'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _scanning ? null : _iniciarScan,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(_scanning ? 'Escanneando...' : 'Iniciar Scan'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _dispositivos.length,
              itemBuilder: (context, index) {
                final device = _dispositivos[index];
                return ListTile(
                  title: Text(device.advertisementData.localName.isNotEmpty
                      ? device.advertisementData.localName
                      : 'Sem nome'),
                  subtitle: Text('RSSI: ${device.rssi}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () => _salvarDispositivo(device),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 🔋 Sobre Leitura de Bateria

O código lê a bateria pelo serviço GATT **padrão**:
- **Serviço UUID**: `0000180F-0000-1000-8000-00805f9b34fb` (Battery Service)
- **Característica**: `00002A19-0000-1000-8000-00805f9b34fb` (Battery Level)

### ⚠️ Casos Especiais

Alguns fabricantes usam **UUIDs proprietários** em vez do padrão:
- **Apple AirPods**: Usa UUID proprietário, não expõe bateria via GATT padrão
- **Alguns smartwatches Samsung**: Podem exigir app oficial
- **Fones genéricos**: Alguns não implementam Battery Service

### Como inspecionar?

Use o app **[nRF Connect](https://www.nordicsemiconductor.com/products/nrf-connect-for-mobile/)** (Android/iOS) para:
1. Conectar ao dispositivo
2. Ver todos os UUIDs disponíveis
3. Identificar o UUID real da bateria

Depois atualize o código em `ble_service.dart` com o UUID correto.

---

## 🧪 Testando

### ✅ Checklist

- [ ] Bluetooth ligado no aparelho
- [ ] Localização ligada (obrigatório para Android 12+)
- [ ] Aplicativo com permissões concedidas
- [ ] Firebase configurado e conectando
- [ ] Pelo menos um dispositivo BLE próximo

### ❌ Problemas Comuns

| Problema | Solução |
|----------|---------|
| **"Permission denied"** | Verifique `AndroidManifest.xml` e conceda permissões manualmente |
| **Bateria sempre 0** | Device usa UUID proprietário — use nRF Connect para inspecionar |
| **Firestore não recebe dados** | Verifique regras de segurança no Firebase Console |
| **App trava ao conectar** | Adicione timeout e tratamento de erro em `conectar()` |
| **iOS não encontra dispositivos** | Verifique `Info.plist` e teste em aparelho real (emulador não funciona) |

---

## 📱 Deployment

### Android

```bash
flutter build apk --release
# ou para teste:
flutter run --release
```

### iOS

```bash
flutter build ios --release
# Depois abra em Xcode e siga o fluxo de assinatura
```

---

## 📚 Referências

- [FlutterBluePlus Docs](https://pub.dev/packages/flutter_blue_plus)
- [Cloud Firestore Docs](https://firebase.flutter.dev/docs/firestore/overview/)
- [Bluetooth GATT Specs](https://www.bluetooth.com/specifications/gatt/)
- [nRF Connect App](https://www.nordicsemiconductor.com/products/nrf-connect-for-mobile/)

---

## 🚀 Próximos Passos

1. **Implementar autenticação** (Firebase Auth)
2. **Adicionar gráficos** de bateria ao longo do tempo
3. **Notificações** quando bateria está baixa
4. **Sincronização** com smartwatch nativo
5. **Modo background** contínuo

---

**Desenvolvido com ❤️ usando Flutter + Firebase**
