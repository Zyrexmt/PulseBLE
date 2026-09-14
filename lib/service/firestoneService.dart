import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pulseble/service/leituraBle.dart';

class FirestoneService {
  final _db = FirebaseFirestore.instance;
  final String _colecao = 'leituras_ble';

  Future<void> salvarLeitura(LeituraBle leitura) async {
    await _db.collection(_colecao).add(leitura.toMap());

    Stream<List<LeituraBle>> streamLeituras() {
      return _db
          .collection(_colecao)
          .orderBy('horario', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => LeituraBle.fromMap(doc.data()))
                .toList(),
          );
    }
  }
}
