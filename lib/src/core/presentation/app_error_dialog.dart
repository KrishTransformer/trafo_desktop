import 'package:flutter/material.dart';

import '../network/api_exception.dart';

class AppErrorDialog extends StatelessWidget {
  const AppErrorDialog({required this.title, required this.message, super.key});

  final String title;
  final String message;

  static Future<void> show(
    BuildContext context, {
    String title = 'Something went wrong',
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AppErrorDialog(title: title, message: message),
    );
  }

  static Future<void> showApiException(
    BuildContext context,
    ApiException exception,
  ) {
    return show(context, message: exception.message);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
