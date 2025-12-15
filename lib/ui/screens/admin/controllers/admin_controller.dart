import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reina_nochebuena/data/models/stage_model.dart';

Future<bool> areAllJudgesDone(String stageId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('scores')
      .where('stageId', isEqualTo: stageId)
      .get();

  final judgesDone = snapshot.docs.map((d) => d['judgeId']).toSet();

  final judges = await FirebaseFirestore.instance
      .collection('judges')
      .get();

  return judgesDone.length == judges.docs.length;
}

Future<void> closeStageAndApplyTop(StageModel stage) async {
  if (stage.maxQualified == null) return;

  final participantsSnapshot = await FirebaseFirestore.instance
      .collection('participants')
      .where('isActive', isEqualTo: true)
      .orderBy('totalScore', descending: true)
      .get();

  final docs = participantsSnapshot.docs;

  for (int i = 0; i < docs.length; i++) {
    final isQualified = i < stage.maxQualified!;
    await docs[i].reference.update({
      'isQualified': isQualified,
      'isActive': isQualified,
    });
  }
}
