/*import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/colors.dart';

class UserHeader extends StatefulWidget {
  final String userEmail;

  const UserHeader({
    super.key,
    required this.userEmail,
  });

  @override
  State<UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<UserHeader> {
  late String _userName;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _userName = _auth.currentUser?.displayName ?? 
                _auth.currentUser?.email?.split('@').first ?? 
                'Usuario';
  }

  Future<void> _updateUserName() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempName = _userName;
        return AlertDialog(
          title: const Text('Editar nombre'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: _userName),
            onChanged: (value) => tempName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (tempName.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre no puede estar vacío')),
                  );
                  return;
                }
                Navigator.pop(context, tempName.trim());
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName != _userName) {
      try {
        await currentUser.updateDisplayName(newName);
        setState(() => _userName = newName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nombre actualizado correctamente')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.primaryRed,
            child: Text(
              _userName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(AppIcons.edit, size: 18),
                    color: AppColors.primaryBlue,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _updateUserName,
                  ),
                ],
              ),
              Text(
                widget.userEmail,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}*/
