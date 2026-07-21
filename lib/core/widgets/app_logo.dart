import 'package:flutter/material.dart';
import 'package:prototipo_2/core/theme/colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color? subtitleColor;

  const AppLogo({super.key, required this.size, this.subtitleColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Texto "Cinti" con colores individuales
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Letra C - Rojo
            Text(
              'C',
              style: TextStyle(
                fontFamily: 'LettersForLearners',
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryRed,
              ),
            ),
            // Letra i - Verde
            Text(
              'i',
              style: TextStyle(
                fontFamily: 'LettersForLearners',
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            // Letra n - Amarillo
            Text(
              'n',
              style: TextStyle(
                fontFamily: 'LettersForLearners',
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryYellow,
              ),
            ),
            // Letra t - Azul fuerte
            Text(
              't',
              style: TextStyle(
                fontFamily: 'LettersForLearners',
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            // Letra l - Turquesa
            Text(
              'l',
              style: TextStyle(
                fontFamily: 'LettersForLearners',
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTurquoise,
              ),
            ),
            // Letra i - Naranja
            Text(
              'i',
              style: TextStyle(
                fontFamily: 'LettersForLearners',
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryOrange,
              ),
            ),
          ],
        ),
        // Texto "Montessori"
        Text(
          'Montessori',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: size * 0.2,
            fontWeight: FontWeight.bold,
            color: subtitleColor ?? Colors.white,
          ),
        ),
      ],
    );
  }
}
