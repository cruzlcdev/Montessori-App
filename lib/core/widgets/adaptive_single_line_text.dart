import 'package:flutter/material.dart';

class AdaptiveSingleLineText extends StatelessWidget {
  const AdaptiveSingleLineText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment:
            textAlign == TextAlign.center
                ? Alignment.center
                : Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: textAlign,
          style: style,
        ),
      ),
    );
  }
}
