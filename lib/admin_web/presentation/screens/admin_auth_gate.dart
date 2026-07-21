import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/admin_icons.dart';

import '../theme/admin_theme.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/auth/data/models/app_user.dart';
import 'admin_login_screen.dart';
import 'admin_shell_screen.dart';

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }

        final authUser = authSnapshot.data;
        if (authUser == null) {
          return const AdminLoginScreen();
        }

        return FutureBuilder<AppUser?>(
          future: _loadAdminProfile(authUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }

            final user = profileSnapshot.data;
            if (user == null || !user.isActive || !user.isAdmin) {
              return _AccessDeniedScreen(email: authUser.email ?? '');
            }

            return AdminShellScreen(user: user);
          },
        );
      },
    );
  }

  Future<AppUser?> _loadAdminProfile(String uid) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(AppConstants.defaultSchoolId)
            .collection('users')
            .doc(uid)
            .get();

    final data = snapshot.data();
    if (data == null) return null;
    return AppUser.fromMap(data, uid: snapshot.id);
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: context.adminPalette.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AdminIcons.adminPanelSettingsOutlined,
                    color: Color(0xFFFF5E52),
                    size: 42,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Acceso administrativo no disponible',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    email.isEmpty
                        ? 'Tu cuenta no tiene permisos para entrar al panel web.'
                        : '$email no tiene rol admin activo para entrar al panel web.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.adminPalette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: FirebaseAuth.instance.signOut,
                    icon: Icon(AdminIcons.logoutRounded),
                    label: Text('Cerrar sesion'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
