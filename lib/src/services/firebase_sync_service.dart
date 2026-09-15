import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lets multiple phones share the same SariScan store data through
/// Firebase, without changing anything about how [LocalStorageService]
/// works. The phone always works fully offline; this service is only ever
/// touched when the owner taps the Sync button in Settings.
///
/// Data model: every store gets a short, human-shareable "sync code"
/// (e.g. "7F3KQ9PL"). Any phone that knows the code reads and writes the
/// same Firestore document at `stores/{syncCode}`. Sign-in is anonymous —
/// there is no email/password step for the owner — Firebase Authentication
/// is only used so Firestore's security rules can require *some* signed-in
/// identity before allowing reads or writes.
class FirebaseSyncService {
  FirebaseSyncService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Avoids visually ambiguous characters (0/O, 1/I) since the code is meant
  // to be read aloud or typed by hand between phones.
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _codeLength = 8;

  Future<void> _ensureSignedIn() async {
    if (_auth.currentUser != null) return;
    await _auth.signInAnonymously();
  }

  DocumentReference<Map<String, dynamic>> _storeDoc(String syncCode) =>
      _firestore.collection('stores').doc(syncCode);

  /// Generates a new, unused sync code and creates the cloud document with
  /// [snapshot] as its starting data. Returns the new code.
  Future<String> createSyncCode(Map<String, dynamic> snapshot) async {
    await _ensureSignedIn();
    final random = Random.secure();
    for (var attempt = 0; attempt < 20; attempt++) {
      final code = List.generate(
        _codeLength,
        (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
      ).join();
      final doc = _storeDoc(code);
      final existing = await doc.get();
      if (existing.exists) continue;
      await doc.set({'data': snapshot, 'updated_at': FieldValue.serverTimestamp()});
      return code;
    }
    throw StateError('Could not generate a unique sync code. Please try again.');
  }

  /// Overwrites the cloud copy under [syncCode] with [snapshot].
  Future<DateTime> uploadSnapshot({
    required String syncCode,
    required Map<String, dynamic> snapshot,
  }) async {
    await _ensureSignedIn();
    await _storeDoc(
      syncCode,
    ).set({'data': snapshot, 'updated_at': FieldValue.serverTimestamp()});
    return DateTime.now();
  }

  /// Downloads the cloud copy under [syncCode]. Returns null if no store
  /// document exists for that code.
  Future<CloudSnapshot?> downloadSnapshot(String syncCode) async {
    await _ensureSignedIn();
    final snapshot = await _storeDoc(syncCode).get();
    if (!snapshot.exists) return null;
    final raw = snapshot.data();
    if (raw == null) return null;
    final data = raw['data'];
    if (data is! Map) return null;
    final updatedAt = raw['updated_at'];
    return CloudSnapshot(
      data: Map<String, dynamic>.from(data),
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}

/// A snapshot downloaded from the cloud, paired with when it was last
/// written so the UI can show "last synced" timestamps.
class CloudSnapshot {
  const CloudSnapshot({required this.data, required this.updatedAt});

  final Map<String, dynamic> data;
  final DateTime? updatedAt;
}