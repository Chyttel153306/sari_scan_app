import 'package:supabase_flutter/supabase_flutter.dart';

/// A sync failure with a message that is safe to show to the person using
/// the app (AppStore prints errors with `$error`).
class CloudSyncException implements Exception {
  const CloudSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lets multiple phones share the same SariScan store data through
/// Supabase, without changing anything about how [LocalStorageService]
/// works. The phone always works fully offline; this service is only ever
/// touched when the owner taps the Sync button in Settings.
///
/// Data model: every store gets a short, human-shareable "sync code"
/// (e.g. "7F3KQ9PL"). Sign-in is anonymous — there is no email/password
/// step for the owner — and Supabase's Row Level Security only lets a
/// signed-in identity read a store after it has joined that store with the
/// code. All reads and writes go through the RPC functions defined in
/// `sariscan_supabase_setup.sql`, which exchange the same snapshot JSON the
/// app has always produced.
class SupabaseSyncService {
  SupabaseSyncService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _notFound = 'P0002';
  static const _notMember = '42501';

  Future<void> _ensureSignedIn() async {
    if (_client.auth.currentSession != null) return;
    try {
      await _client.auth.signInAnonymously();
    } on AuthException catch (error) {
      throw CloudSyncException(
        'Could not sign in to cloud sync: ${error.message}',
      );
    }
  }

  CloudSyncException _friendly(PostgrestException error) {
    if (error.code == _notFound) {
      return const CloudSyncException(
        'No store was found for that sync code. If this phone was linked '
        'before the move to Supabase, unlink it and create a new sync code.',
      );
    }
    return CloudSyncException(error.message);
  }

  /// Calls an RPC that requires store membership. If this signed-in
  /// identity is not a member yet (for example a fresh anonymous session on
  /// a phone that still remembers its sync code), it joins with the code —
  /// the same trust step the previous Firebase version had — and retries
  /// once.
  Future<dynamic> _memberRpc(
    String syncCode,
    String function,
    Map<String, dynamic> params,
  ) async {
    await _ensureSignedIn();
    try {
      return await _client.rpc(function, params: params);
    } on PostgrestException catch (error) {
      if (error.code != _notMember) rethrow;
    }
    await _client.rpc('join_store', params: {'p_code': syncCode});
    return _client.rpc(function, params: params);
  }

  /// Creates a new cloud store with [snapshot] as its starting data and
  /// returns the new sync code.
  Future<String> createSyncCode(Map<String, dynamic> snapshot) async {
    await _ensureSignedIn();
    try {
      final code = await _client.rpc(
        'create_store',
        params: {'p_snapshot': snapshot},
      );
      return '$code';
    } on PostgrestException catch (error) {
      throw _friendly(error);
    }
  }

  /// Overwrites the cloud copy under [syncCode] with [snapshot].
  Future<DateTime> uploadSnapshot({
    required String syncCode,
    required Map<String, dynamic> snapshot,
  }) async {
    try {
      final result = await _memberRpc(syncCode, 'push_snapshot', {
        'p_code': syncCode,
        'p_snapshot': snapshot,
      });
      return DateTime.tryParse('$result')?.toLocal() ?? DateTime.now();
    } on PostgrestException catch (error) {
      throw _friendly(error);
    }
  }

  /// Downloads the cloud copy under [syncCode]. Returns null if no store
  /// exists for that code. Pass [join] when a new phone is joining with a
  /// code so it becomes a member of the store.
  Future<CloudSnapshot?> downloadSnapshot(
    String syncCode, {
    bool join = false,
  }) async {
    try {
      final dynamic result;
      if (join) {
        await _ensureSignedIn();
        result = await _client.rpc('join_store', params: {'p_code': syncCode});
      } else {
        result = await _memberRpc(syncCode, 'pull_snapshot', {
          'p_code': syncCode,
        });
      }
      if (result is! Map) return null;
      final data = result['data'];
      if (data is! Map) return null;
      return CloudSnapshot(
        data: Map<String, dynamic>.from(data),
        updatedAt: DateTime.tryParse('${result['updated_at']}')?.toLocal(),
      );
    } on PostgrestException catch (error) {
      if (error.code == _notFound) return null;
      throw _friendly(error);
    }
  }
}

/// A snapshot downloaded from the cloud, paired with when it was last
/// written so the UI can show "last synced" timestamps.
class CloudSnapshot {
  const CloudSnapshot({required this.data, required this.updatedAt});

  final Map<String, dynamic> data;
  final DateTime? updatedAt;
}