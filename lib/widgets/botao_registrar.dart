import 'package:flutter/material.dart';

class BotaoRegistrar extends StatelessWidget {
  final VoidCallback onPressed;

  const BotaoRegistrar({Key? key, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text('REGISTRAR HORÁRIO'),
    );
  }
}
