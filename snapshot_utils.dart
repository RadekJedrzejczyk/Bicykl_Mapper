import 'package:screenshot/screenshot.dart'; //obsługa screenshot'ów
import 'dart:typed_data'; //uint
import 'package:flutter/material.dart';

class Snapshoter {
  static Future<Uint8List> snapshotTarget(
      dynamic state, dynamic toScreenshot) async {
    ScreenshotController screenshotController = ScreenshotController();
    BuildContext context = state.context;

    // Capture the screenshot asynchronously
    Uint8List? capturedImage = await screenshotController.captureFromWidget(
      InheritedTheme.captureAll(
        context,
        Material(child: toScreenshot),
      ),
      delay: Duration(milliseconds: 100),
      context: context,
    );

    if (capturedImage != null) {
      return capturedImage;
    } else {
      // Handle error or return a default value
      throw 'Error capturing screenshot';
    }
  }
}
