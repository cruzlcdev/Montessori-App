import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/core/theme/colors.dart';
import 'package:prototipo_2/features/auth/presentation/controllers/current_user_controller.dart';

// Pantalla inicial (Splash) que muestra animaciones antes de entrar al login
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controlador para animar el logo principal (desplazamiento hacia arriba)
  late AnimationController _logoSlideController;
  late Animation<Offset> _logoSlideAnimation;

  // Controladores para animar cada letra de "Cintli"
  late List<AnimationController> _letterControllers;

  // Controlador y animaciones para el texto "Montessori"
  late AnimationController _montessoriController;
  late Animation<double> _montessoriScale;
  late Animation<double> _montessoriOpacity;

  final String _title = 'Cintli'; // Texto animado
  bool _initialized = false; // Marca cuando Firebase está listo
  bool _navigationTriggered =
      false; // Evita que la navegación se ejecute dos veces
  bool _showLoading = false; // Activa el indicador de "Cargando..."

  @override
  void initState() {
    super.initState();
    _initializeAnimations(); // Configura todas las animaciones
    _initializeApp(); // Inicializa Firebase y luego arranca las animaciones
  }

  // Configura todos los controladores de animaciones
  void _initializeAnimations() {
    _logoSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    // Genera un controlador por cada letra de "Cintli"
    _letterControllers = List.generate(_title.length, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 520),
      );
    });

    // Animación de desplazamiento hacia arriba del logo
    _logoSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -2.5), // Mueve el logo hacia arriba
    ).animate(
      CurvedAnimation(parent: _logoSlideController, curve: Curves.easeInOut),
    );

    // Animaciones para el texto "Montessori"
    _montessoriController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _montessoriScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _montessoriController, curve: Curves.elasticOut),
    );

    _montessoriOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _montessoriController, curve: Curves.easeIn),
    );
  }

  // Inicializa Firebase antes de arrancar la app
  Future<void> _initializeApp() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      if (!mounted) return;
      setState(() => _initialized = true);
      _startLetterAnimations(); // Una vez listo, inicia animaciones de letras
    } catch (e) {
      // Aquí se podría manejar un error de inicialización
    }
  }

  // Reproduce en secuencia: letras -> Montessori -> loading -> logo arriba -> login
  void _startLetterAnimations() {
    for (int i = 0; i < _letterControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (!mounted) return;
        _letterControllers[i].forward(); // Animamos cada letra una por una
        if (i == _letterControllers.length - 1) {
          // Cuando termina la última letra...
          Future.delayed(const Duration(milliseconds: 350), () {
            if (!mounted) return;
            _montessoriController.forward(); // Muestra "Montessori"

            Future.delayed(const Duration(milliseconds: 550), () {
              if (!mounted) return;
              setState(() {
                _showLoading = true; // Activa "Cargando..."
              });

              Future.delayed(const Duration(milliseconds: 450), () {
                if (!mounted) return;
                _logoSlideController.forward().then((_) {
                  _navigateAfterProfileCheck();
                });
              });
            });
          });
        }
      });
    }
  }

  // Decide una sola vez si entra al Home o regresa al login.
  Future<void> _navigateAfterProfileCheck() async {
    if (_navigationTriggered) return;
    _navigationTriggered = true;

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
      return;
    }

    final currentUserController = context.read<CurrentUserController>();
    final profileAlreadyLoaded =
        currentUserController.user?.uid == authUser.uid &&
        !currentUserController.isLoading;
    if (!profileAlreadyLoaded) {
      await currentUserController.loadCurrentUser(authUser: authUser);
    }

    if (!mounted) return;
    if (currentUserController.hasAppAccess) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  void dispose() {
    // Liberamos todos los controladores
    _logoSlideController.dispose();
    _montessoriController.dispose();
    for (final controller in _letterControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si Firebase aún no está listo, mostrar pantalla de carga
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.brandBlueSurface,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.brandBlueSurface,
      body: Center(
        child:
            _showLoading
                ? _buildLoading() // Muestra "Cargando..."
                : SlideTransition(
                  position:
                      _logoSlideAnimation, // Aplica animación de desplazamiento
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAnimatedLogo(size: 130), // Letras "Cintli"
                      const SizedBox(height: 10),
                      _buildAnimatedMontessori(size: 130), // Texto "Montessori"
                    ],
                  ),
                ),
      ),
    );
  }

  // Construye animación de cada letra de "Cintli"
  Widget _buildAnimatedLogo({required double size}) {
    List<String> letters = ['C', 'i', 'n', 't', 'l', 'i'];
    List<Color> colors = [
      AppColors.primaryRed,
      AppColors.primaryGreen,
      AppColors.primaryYellow,
      AppColors.primaryBlue,
      AppColors.primaryTurquoise,
      AppColors.primaryOrange,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(letters.length, (index) {
        final controller = _letterControllers[index];

        final scale = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.elasticOut),
        );

        final rotation = Tween<double>(begin: -1.0, end: 0.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
        );

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: rotation.value,
              child: Transform.scale(
                scale: scale.value,
                child: Text(
                  letters[index],
                  style: TextStyle(
                    fontFamily: 'LettersForLearners',
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.bold,
                    color: colors[index], // Cada letra con color diferente
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // Construye animación de "Montessori" (aparece y crece)
  Widget _buildAnimatedMontessori({required double size}) {
    return FadeTransition(
      opacity: _montessoriOpacity,
      child: ScaleTransition(
        scale: _montessoriScale,
        child: Text(
          'Montessori',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: size * 0.2,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Widget de loading (Cargando...)
  Widget _buildLoading() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
        SizedBox(height: 20),
        Text(
          'Cargando...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Lato',
          ),
        ),
      ],
    );
  }
}
