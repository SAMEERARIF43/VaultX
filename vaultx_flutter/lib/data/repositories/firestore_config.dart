import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/constants/vault_constants.dart';

/// Provides explicit access to the VaultX named Cloud Firestore database.
///
/// IMPORTANT: Never use `FirebaseFirestore.instance` (which connects to `(default)`).
/// VaultX stores all records in the named database:
/// `ai-studio-8494ca94-6f4d-44cf-b5ad-d01b20e7a342`.
class FirestoreConfig {
  FirestoreConfig._();

  static FirebaseFirestore get db {
    final instance = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: VaultConstants.firestoreDatabaseId,
    );
    assert(
      instance.databaseId == VaultConstants.firestoreDatabaseId,
      'Firestore connected to wrong databaseId: ${instance.databaseId}',
    );
    return instance;
  }

  static void assertNamedDatabaseConfigured(FirebaseFirestore firestore) {
    if (firestore.databaseId != VaultConstants.firestoreDatabaseId) {
      throw StateError(
        'Refusing operation on "${firestore.databaseId}". '
        'Expected "${VaultConstants.firestoreDatabaseId}".',
      );
    }
  }
}
