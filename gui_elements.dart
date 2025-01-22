import 'package:flutter/material.dart';

Widget createElevatedButton(
    BuildContext context,
    String label, //opis przycisku
    bool isEnabled, //warunek czy można uruchomić...
    Future<void> Function()? onPressedCallback, //... metodę.
    Color backgroundColor, //kolor przycisku
    {double fontSize = 10,
    double borderRadius = 20,
    Color foregroundColor = Colors.white,
    Color fontColor = Colors.black,
    double horizontalTextPadding = 10,
    double verticalTextPadding = 6,
    Size minimumSize = const Size(100, 35)}) {
  //styl tekstu oraz padding
  TextStyle textStyle = TextStyle(fontSize: fontSize, color: fontColor);
  EdgeInsets textPadding = EdgeInsets.symmetric(
      horizontal: horizontalTextPadding, vertical: verticalTextPadding);
  //budowa przycisku
  return ElevatedButton(
      onPressed: isEnabled ? onPressedCallback : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 4,
        minimumSize: minimumSize,
        padding: textPadding,
        textStyle: textStyle,
      ),
      child: Text(label));
}
