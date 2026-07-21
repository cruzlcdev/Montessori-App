import 'dart:io';

import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/app_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:prototipo_2/features/news/data/repositories/firestore_news_repository.dart';
import 'package:prototipo_2/features/news/presentation/controllers/news_controller.dart';

class CreateNewsScreen extends StatefulWidget {
  const CreateNewsScreen({super.key, this.controller});

  final NewsController? controller;

  @override
  State<CreateNewsScreen> createState() => _CreateNewsScreenState();
}

class _CreateNewsScreenState extends State<CreateNewsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  late final NewsController _controller;
  late final bool _ownsController;

  File? _selectedImage;
  DateTime? _expirationDate;
  bool _isUploading = false;
  bool _isCheckingPermission = true;
  bool _sendToWholeSchool = true;

  final Map<String, bool> _selectedGroups = {
    'comunidad_infantil': false,
    'casa_ninos': false,
    'taller_1': false,
    'taller_2': false,
    'comunidad_adolescente': false,
  };

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        NewsController(repository: FirestoreNewsRepository());
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    if (_ownsController) {
      await _controller.loadAdminStatus();
    }

    if (mounted) {
      setState(() => _isCheckingPermission = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
    });
  }

  Future<void> _submitNews() async {
    if (!_controller.isAdmin) {
      _showSnackBar('No tienes permisos para crear noticias');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final targetGroupIds =
        _sendToWholeSchool
            ? const ['all']
            : _selectedGroups.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList(growable: false);

    if (targetGroupIds.isEmpty) {
      _showSnackBar('Selecciona toda la escuela o al menos un grupo');
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _controller.createNews(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        targetGroupIds: targetGroupIds,
        expiresAt: _expirationDate,
        image: _selectedImage,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('No se pudo crear la noticia. Intenta nuevamente.');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _selectExpirationDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );

    if (pickedTime == null) return;

    setState(() {
      _expirationDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crear Noticia')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_controller.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Noticias')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No tienes permisos para crear noticias.',
              style: TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Noticia'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.save),
            onPressed: _isUploading ? null : _submitNews,
          ),
        ],
      ),
      body:
          _isUploading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Imagen de la noticia (opcional)',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Puedes crear la noticia sin imagen. La carga de imágenes requiere Storage activo.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey[400]!,
                              width: 1,
                            ),
                          ),
                          child:
                              _selectedImage != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                  : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        AppIcons.image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Agregar imagen',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título de la noticia*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Este campo es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'Contenido de la noticia*',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Este campo es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Dirigido a:*',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Toda la escuela'),
                        subtitle: const Text(
                          'Visible para administradores, profesores y padres.',
                        ),
                        value: _sendToWholeSchool,
                        onChanged: (value) {
                          setState(() {
                            _sendToWholeSchool = value;
                          });
                        },
                      ),
                      if (!_sendToWholeSchool)
                        ..._selectedGroups.keys.map((group) {
                          return CheckboxListTile(
                            title: Text(_getGroupName(group)),
                            value: _selectedGroups[group],
                            onChanged: (value) {
                              setState(() {
                                _selectedGroups[group] = value ?? false;
                              });
                            },
                          );
                        }),
                      if (!_sendToWholeSchool)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Solo lo verán usuarios vinculados a los grupos seleccionados.',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: Text(
                          _expirationDate == null
                              ? 'No establecer fecha de expiración'
                              : 'Expira: ${DateFormat('dd/MM/yyyy HH:mm').format(_expirationDate!)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(AppIcons.calendarToday),
                          onPressed: _selectExpirationDate,
                        ),
                        onTap: _selectExpirationDate,
                      ),
                      if (_expirationDate != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _expirationDate = null);
                          },
                          child: const Text('Eliminar fecha de expiración'),
                        ),
                    ],
                  ),
                ),
              ),
    );
  }

  String _getGroupName(String groupId) {
    const groupNames = {
      'comunidad_infantil': 'Comunidad Infantil',
      'casa_ninos': 'Casa de Niños',
      'taller_1': 'Taller 1',
      'taller_2': 'Taller 2',
      'comunidad_adolescente': 'Comunidad Adolescente',
    };
    return groupNames[groupId] ?? groupId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }
}
