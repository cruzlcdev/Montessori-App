# Cintli Montessori

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black)
![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20Android%20%7C%20Web-0073DB?style=flat-square)
![License](https://img.shields.io/badge/License-Proprietary-FF5E52?style=flat-square)

Sistema escolar compuesto por una aplicación móvil para familias y docentes y un panel web para la administración institucional. El proyecto evolucionó de un prototipo académico a una base modular orientada a producción, con control de acceso por rol, datos en tiempo real y una interfaz adaptable.

> Este repositorio público no contiene credenciales, cuentas de servicio, archivos de configuración Firebase por plataforma ni datos personales de la institución. Las configuraciones locales y de producción deben generarse de forma independiente.

## Estado del proyecto

- **Aplicación móvil:** `0.9.0+1`
- **Panel administrativo web:** `0.7.0+1`
- **Etapa:** preproducción y validación funcional
- **Administración móvil:** deshabilitada; la gestión escolar se concentra en web
- **Notificaciones push:** planeadas, no activas
- **Firebase Storage:** integración futura para imágenes y documentos

## Productos incluidos

### Aplicación móvil

- Acceso con Firebase Authentication y perfil Firestore observado en tiempo real.
- Experiencia diferenciada para familia y docente.
- Noticias y calendario filtrados por audiencia escolar o grupos asignados.
- Boletas, estadísticas y consulta por trimestre.
- Evaluaciones docentes restringidas a grupos, alumnos y materias válidos.
- Actualizaciones automáticas mediante streams de Cloud Firestore.
- Modo claro y oscuro, diseño adaptable para iOS y Android e iconografía Lucide.
- Estados de carga con skeleton y control de conectividad.
- Recuperación de contraseña y mensajes de acceso inactivo.

### Panel administrativo web

- Resumen operativo con métricas en tiempo real.
- Gestión de noticias, audiencias, expiración y archivado.
- Gestión de calendario, fechas, horarios y grupos destinatarios.
- Administración de grupos, materias, alumnos, familias y profesores.
- Aprovisionamiento de cuentas Firebase Auth para familias y docentes.
- Vinculación de profesores con grupos y de familias con alumnos.
- Activación, inactivación, archivado y confirmaciones para acciones críticas.
- Preferencia de sesión y tema claro, oscuro o del sistema.
- Formularios, filtros, selectores y feedback diseñados para escritorio.

## Arquitectura

El código utiliza una organización modular por funcionalidad:

```text
lib/
|- admin_web/            Panel administrativo, repositorios y tema web
|- core/                 Configuración, conectividad, layout, tema y widgets
|- features/
|  |- academics/         Periodos, materias y evaluaciones
|  |- auth/              Sesión, perfiles y recuperación de acceso
|  |- calendar/          Eventos y audiencias
|  |- directory/         Grupos, alumnos y profesores
|  `- news/              Comunicados y audiencias
`- screens/              Composición de pantallas móviles
```

Flujo principal:

```text
Pantalla -> Controller / Provider -> Repository -> Firebase SDK
                                             -> Authentication
                                             -> Cloud Firestore
```

Los datos institucionales se organizan bajo `schools/{schoolId}`. Las reglas de Firestore validan autenticación, estado activo, rol, pertenencia a grupos, vinculación familiar y estructura de cada escritura.

## Stack tecnológico

| Área | Tecnología |
| --- | --- |
| Aplicación móvil | Flutter y Dart |
| Panel web | Flutter Web |
| Autenticación | Firebase Authentication |
| Base de datos principal | Cloud Firestore |
| Gestión de estado | Provider |
| Persistencia local | SharedPreferences |
| Calendario | table_calendar |
| Iconografía | lucide_flutter |
| Carga visual | skeletonizer |
| Conectividad | connectivity_plus |
| Localización | intl y flutter_localizations |

`firebase_database`, `firebase_storage` e `image_picker` permanecen como dependencias de transición o preparación futura. Cloud Firestore es la fuente principal de los módulos productivos actuales.

## Configuración local segura

### Requisitos

- Flutter compatible con Dart `^3.7.2`
- Proyecto Firebase propio
- FlutterFire CLI y Firebase CLI
- Xcode para iOS y Android Studio para Android

### Preparación

```bash
flutter pub get
flutterfire configure
```

`flutterfire configure` debe generar localmente los siguientes archivos, excluidos del repositorio:

```text
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
macos/Runner/GoogleService-Info.plist
lib/core/config/firebase_options.dart
.firebaserc
```

No deben sustituirse por archivos reales dentro de commits públicos.

### Ejecutar la aplicación móvil

```bash
flutter run
```

### Ejecutar el panel administrativo

```bash
flutter run -d chrome -t lib/admin_web/main_admin.dart
```

## Firebase

El repositorio conserva únicamente artefactos públicos y revisables:

- `firestore.rules`
- `firestore.indexes.json`
- `storage.rules`
- `firebase.json` sin identificadores de proyecto
- `.firebaserc.example`

Las reglas no sustituyen la configuración de Firebase Authentication, App Check, presupuestos, alertas ni políticas operativas requeridas antes de producción.

## Calidad y validación

```bash
flutter analyze
flutter test
flutter build web --release -t lib/admin_web/main_admin.dart
```

Antes de publicar también se debe verificar:

- ausencia de secretos y configuraciones locales;
- permisos de Firestore mediante Emulator Suite;
- navegación por roles y cuentas inactivas;
- sincronización en tiempo real;
- layouts móviles y web en diferentes resoluciones;
- consistencia de versiones móvil y web.

## Cambios principales respecto al prototipo

- Migración progresiva de módulos escolares hacia Cloud Firestore.
- Separación del panel administrativo web y la aplicación móvil.
- Administración móvil retirada del flujo principal.
- Directorio, noticias, calendario y evaluaciones con streams en tiempo real.
- Modelo de usuarios con roles, estados, grupos y alumnos vinculados.
- Reglas Firestore endurecidas por recurso y audiencia.
- Interfaz móvil y web rediseñada con soporte responsive y modo oscuro.
- Eliminación temporal del centro de notificaciones hasta integrar FCM.
- Versionado independiente para app y panel web.

## Próximas etapas

- Completar pruebas integrales con Firebase Emulator Suite.
- Definir App Check, monitoreo, respaldos y alertas de consumo.
- Incorporar backend privilegiado para deshabilitar o eliminar cuentas Auth.
- Habilitar Storage cuando exista una política de costos y contenido.
- Integrar Firebase Cloud Messaging después de definir consentimiento y audiencias.
- Preparar distribución cerrada en TestFlight y Google Play Testing.
- Realizar pruebas de aceptación con datos ficticios antes del ciclo escolar.

## Seguridad y privacidad

- No deben registrarse datos reales de estudiantes en issues, pruebas o commits.
- Las cuentas de servicio nunca deben usarse desde Flutter ni publicarse.
- Los documentos técnicos internos se mantienen fuera del repositorio público.
- Cualquier hallazgo de seguridad debe comunicarse de forma privada al titular.

## Licencia

Copyright (c) 2026 Luisdev. Todos los derechos reservados.

Este software es propietario y se publica únicamente con fines demostrativos y de portafolio. Consultar [LICENSE](LICENSE) para conocer las restricciones de uso.
