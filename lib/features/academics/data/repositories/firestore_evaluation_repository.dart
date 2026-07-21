import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/evaluation_model.dart';
import 'evaluation_repository.dart';

class FirestoreEvaluationRepository implements EvaluationRepository {
  FirestoreEvaluationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('evaluations');
  }

  @override
  Stream<EvaluationModel?> watchEvaluation({
    required String schoolId,
    required String evaluationId,
  }) {
    return _collection(schoolId).doc(evaluationId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return EvaluationModel.fromFirestore(snapshot);
    });
  }

  @override
  Future<EvaluationModel?> getEvaluation({
    required String schoolId,
    required String evaluationId,
  }) async {
    final snapshot = await _collection(schoolId).doc(evaluationId).get();
    if (!snapshot.exists) return null;
    return EvaluationModel.fromFirestore(snapshot);
  }

  @override
  Stream<List<EvaluationModel>> watchEvaluationsByGroupTerm({
    required String schoolId,
    required String groupId,
    required int termNumber,
  }) {
    return _collection(
      schoolId,
    ).where('groupId', isEqualTo: groupId).snapshots().map((snapshot) {
      return snapshot.docs
          .map(EvaluationModel.fromFirestore)
          .where((evaluation) => evaluation.termNumber == termNumber)
          .toList();
    });
  }

  @override
  Stream<List<EvaluationModel>> watchEvaluationsByIds({
    required String schoolId,
    required List<String> evaluationIds,
  }) {
    final ids = evaluationIds.toSet().toList(growable: false);
    if (ids.isEmpty) return Stream.value(const []);

    return Stream.multi((controller) {
      final evaluations = <String, EvaluationModel>{};
      final subscriptions = <StreamSubscription>[];

      void emit() => controller.add(evaluations.values.toList());

      for (final evaluationId in ids) {
        final subscription = _collection(
          schoolId,
        ).doc(evaluationId).snapshots().listen((snapshot) {
          if (snapshot.exists) {
            evaluations[evaluationId] = EvaluationModel.fromFirestore(snapshot);
          } else {
            evaluations.remove(evaluationId);
          }
          emit();
        }, onError: controller.addError);
        subscriptions.add(subscription);
      }

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  @override
  Future<void> saveEvaluation(EvaluationModel evaluation) {
    return _collection(
      evaluation.schoolId,
    ).doc(evaluation.id).set(evaluation.toSaveMap(), SetOptions(merge: true));
  }
}
