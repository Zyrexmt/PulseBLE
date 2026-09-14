import 'package:flutter/material.dart';

class DeviceConnectDialog extends StatelessWidget {
  const DeviceConnectDialog({
    super.key,
    required this.nomeDispositivo,
    required this.bateria,
    required this.onSalvar,
    required this.onCancelar,
  });

  final String nomeDispositivo;
  final int bateria;
  final VoidCallback onSalvar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.circular(16),
      ),
      title: Text(nomeDispositivo),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            bateria > 20 ? Icons.battery_full : Icons.battery_alert,
            color: bateria > 20 ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8,),
          Text('Bateria: $bateria', style: TextStyle(fontSize: 16),)
        ],
      ),

      actions: [
        TextButton(onPressed: onCancelar, child: const Text('Cancelar')),
        FilledButton(onPressed: onSalvar, child: const Text('Salvar'))
      ],
    );
  }
}
