import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String? currentFirebaseUid(FirebaseAuth auth) => auth.currentUser?.uid;

class FirebaseSessionChangedException implements Exception {
  const FirebaseSessionChangedException();

  @override
  String toString() =>
      'The authenticated account changed during this operation.';
}

String requireActiveFirebaseUid(FirebaseAuth auth, String? expectedUid) {
  return requireExpectedFirebaseUid(expectedUid, currentFirebaseUid(auth));
}

String requireExpectedFirebaseUid(String? expectedUid, String? activeUid) {
  if (expectedUid == null || activeUid != expectedUid) {
    throw const FirebaseSessionChangedException();
  }
  return expectedUid;
}

int stableUserIdFromUid(String uid) {
  const fnvPrime = 16777619;
  var hash = 2166136261;

  for (final codeUnit in uid.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * fnvPrime) & 0xffffffff;
  }

  return hash & 0x7fffffff;
}

int? currentStableUserId(FirebaseAuth auth) {
  final uid = currentFirebaseUid(auth);
  return uid == null ? null : stableUserIdFromUid(uid);
}

Map<String, dynamic> withFirebaseOwner(Map<String, dynamic> data, String uid) {
  return {
    ...data,
    'firebase_uid': uid,
  };
}

Query<Map<String, dynamic>> ownedQuery(
  FirebaseFirestore firestore,
  String collection,
  String uid,
) {
  return firestore.collection(collection).where('firebase_uid', isEqualTo: uid);
}
