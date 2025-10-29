import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/firestore_models.dart' as models;
import '../services/firestore_service.dart';

// Pantalla para coordinar la fecha y hora de entrega cuando el pedido está listo
// El cliente selecciona cuándo quiere recibir su mueble
class ScheduleDeliveryScreen extends StatefulWidget {
  final models.Order order;
  const ScheduleDeliveryScreen({super.key, required this.order});

  @override
  State<ScheduleDeliveryScreen> createState() => _ScheduleDeliveryScreenState();
}

class _ScheduleDeliveryScreenState extends State<ScheduleDeliveryScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  // Abre el calendario para elegir la fecha - solo permito desde mañana hasta 30 días adelante
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Muestra el reloj para elegir la hora de entrega
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Valida que haya fecha y hora, combina ambas en un DateTime y actualiza el pedido
  // Cambia el estado a 'delivery_scheduled' para que aparezca en el seguimiento
  Future<void> _confirmSchedule() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona una fecha y una hora.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final firestoreService = context.read<FirestoreService>();

    // Junto la fecha y hora elegidas en un solo DateTime para guardar en Firestore
    final finalDeliveryDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      await firestoreService.updateOrder(widget.order.id, {
        'status': 'delivery_scheduled',
        'scheduledDeliveryDate': Timestamp.fromDate(finalDeliveryDateTime),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Entrega programada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al programar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final timeFormatter = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Programar Entrega')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¡Tu pedido está listo!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Por favor, selecciona una fecha y hora para la entrega. (Horario de entrega: 09:00 - 18:00)',
            ),
            const SizedBox(height: 24),

            // Selector de Fecha
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Fecha de Entrega'),
              subtitle: Text(
                _selectedDate == null
                    ? 'No seleccionada'
                    : dateFormatter.format(_selectedDate!),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectDate,
            ),
            const Divider(),

            // Selector de Hora
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Hora de Entrega'),
              subtitle: Text(
                _selectedTime == null
                    ? 'No seleccionada'
                    : timeFormatter.formatTimeOfDay(_selectedTime!),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectTime,
            ),
            const Divider(),
            const Spacer(),

            // Botón de Confirmación
            ElevatedButton(
              onPressed: _isLoading ? null : _confirmSchedule,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    )
                  : const Text('Confirmar Entrega'),
            ),
          ],
        ),
      ),
    );
  }
}
