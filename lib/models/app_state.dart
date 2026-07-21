// Importa la librería foundation de Flutter, necesaria para usar ChangeNotifier
import 'package:flutter/foundation.dart';

// Clase AppState que extiende de ChangeNotifier, lo que permite
// notificar a los widgets que estén escuchando cuando cambie su estado.
class AppState with ChangeNotifier {
  // Variables privadas para manejar el estado de la aplicación
  int _selectedTerm = 1;             // Periodo/Trimestre seleccionado (1, 2 o 3)
  String _selectedStudentId = '';    // ID del estudiante seleccionado
  String _selectedStudentName = '';  // Nombre del estudiante seleccionado
  String _selectedGroupId = '';      // ID del grupo seleccionado

  // Getters públicos para acceder a las variables privadas
  int get selectedTerm => _selectedTerm;
  String get selectedStudentId => _selectedStudentId;
  String get selectedStudentName => _selectedStudentName;
  String get selectedGroupId => _selectedGroupId;

  // Método para cambiar el trimestre seleccionado.
  // Solo permite valores entre 1 y 3.
  void changeTerm(int newTerm) {
    if (newTerm >= 1 && newTerm <= 3) {
      _selectedTerm = newTerm;
      notifyListeners(); // Notifica a los widgets que usan este estado.
    }
  }

  // Método para establecer el contexto de un estudiante (ID, nombre y grupo).
  void setStudentContext({
    required String studentId,
    required String studentName,
    required String groupId,
  }) {
    _selectedStudentId = studentId;
    _selectedStudentName = studentName;
    _selectedGroupId = groupId;
    notifyListeners(); // Actualiza la UI con los nuevos valores.
  }

  // Método para limpiar el contexto del estudiante (resetea a valores vacíos).
  void clearStudentContext() {
    _selectedStudentId = '';
    _selectedStudentName = '';
    _selectedGroupId = '';
    notifyListeners(); // Notifica a la UI que los valores fueron reseteados.
  }
}
