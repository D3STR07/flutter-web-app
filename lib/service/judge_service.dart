import 'package:cloud_firestore/cloud_firestore.dart';

class JudgeService {
  final _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getJudgeByCode(String code) async {
    final snapshot = await _db
        .collection('jueces')
        .where('codigo', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data();
  }
}
