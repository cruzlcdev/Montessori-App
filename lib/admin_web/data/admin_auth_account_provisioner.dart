import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AdminAuthAccountProvisioner {
  const AdminAuthAccountProvisioner();

  Future<ProvisionedAdminAccount> createAccount({
    required String email,
    required String accountLabel,
  }) async {
    final app = await Firebase.initializeApp(
      name: 'admin-provision-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final auth = FirebaseAuth.instanceFor(app: app);

    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: _temporaryPassword(),
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase no devolvió la cuenta creada.');
      }

      return ProvisionedAdminAccount(app: app, auth: auth, user: user);
    } on FirebaseAuthException catch (error) {
      await app.delete();
      throw StateError(_creationMessage(error, accountLabel));
    } catch (_) {
      await app.delete();
      rethrow;
    }
  }

  String _temporaryPassword() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';
    final random = Random.secure();
    final suffix =
        List.generate(
          28,
          (_) => alphabet[random.nextInt(alphabet.length)],
        ).join();
    return 'Aa1!$suffix';
  }

  String _creationMessage(FirebaseAuthException error, String accountLabel) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Ese correo ya existe en Firebase Authentication, pero no está vinculado al perfil escolar. La automatización con Admin SDK resolverá esta vinculación antes de producción.';
      case 'invalid-email':
        return 'El correo de $accountLabel no tiene un formato válido.';
      case 'operation-not-allowed':
        return 'El acceso por correo y contraseña no está habilitado en Firebase Authentication.';
      case 'network-request-failed':
        return 'No se pudo conectar con Firebase. Revisa tu conexión e inténtalo nuevamente.';
      default:
        return 'No fue posible crear la cuenta de acceso de $accountLabel (${error.code}).';
    }
  }
}

class ProvisionedAdminAccount {
  const ProvisionedAdminAccount({
    required this.app,
    required this.auth,
    required this.user,
  });

  final FirebaseApp app;
  final FirebaseAuth auth;
  final User user;

  Future<bool> sendPasswordSetupEmail(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose({bool deleteUser = false}) async {
    if (deleteUser) {
      try {
        await user.delete();
      } catch (_) {
        // Conserva el error principal si Auth no permite revertir la cuenta.
      }
    }

    try {
      await auth.signOut();
    } catch (_) {
      // La app secundaria se elimina aunque su sesión ya esté cerrada.
    }
    try {
      await app.delete();
    } catch (_) {
      // La limpieza no debe ocultar el resultado de la operación principal.
    }
  }
}
