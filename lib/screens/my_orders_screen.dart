import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/firestore_models.dart' as models;
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'schedule_delivery_screen.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// Pantalla de pedidos del cliente
// Muestra el historial de pedidos con opciones para cancelar y ver detalles de pago
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  // Datos bancarios para que el cliente haga la transferencia del anticipo
  static const String bankAccountNumber = "81-5731859";
  static const String otherBanksAccountNumber = "815731859";
  static const String bankName = "Banco Familiar";
  static const String accountHolder = "CARLOS FERNANDO ISASI DEANDRADE";
  static const String accountCedula = "6121553";
  static const String contactWhatsapp = "+595985996792";

  // Estos estados significan que el pedido está en proceso activo
  static const Set<String> _activeStatuses = {
    'confirmed',
    'scheduled',
    'in_production',
  };

  // Pide confirmación antes de cancelar - si confirma, devuelve el stock automáticamente
  Future<void> _showCancelConfirmationDialog(
    BuildContext context,
    models.Order order,
  ) async {
    final firestoreService = context.read<FirestoreService>();
    final messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Pedido'),
        content: const Text(
          '¿Estás seguro de que quieres cancelar este pedido? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text(
              'Sí, Cancelar',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await firestoreService.cancelOrderAndUpdateStock(order.id);

        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Pedido cancelado.'),
              backgroundColor: Colors.orange),
        );
      } catch (e) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
              content: Text('Error al cancelar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // Abre enlaces externos como WhatsApp
  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir el enlace: $url'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();
    final userId = authService.currentUser!.uid;

    final currencyFormatter = NumberFormat.currency(
      locale: 'es_PY',
      symbol: 'Gs',
      decimalDigits: 0,
    );
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final shortDateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Pedidos')),
      body: StreamBuilder<List<models.Order>>(
        stream: firestoreService.getOrdersForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar pedidos: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Aún no has realizado ningún pedido.'),
            );
          }

          final orders = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];

              //  Lógica para determinar el texto del subtítulo
              String subtitleText;
              if (order.status == 'delivery_scheduled' &&
                  order.scheduledDeliveryDate != null) {
                subtitleText =
                    'Entrega: ${dateFormatter.format(order.scheduledDeliveryDate!)}';
              } else if (order.status == 'scheduled' &&
                  order.manufacturingStartDate != null) {
                subtitleText =
                    'Fabricar el: ${shortDateFormatter.format(order.manufacturingStartDate!)}';
              } else if (order.status == 'pending') {
                subtitleText =
                    'Pedido el: ${dateFormatter.format(order.orderDate)}';
              } else if (order.status == 'cancelled') {
                subtitleText = 'Cancelado'; // Texto simple para cancelado
              } else if (_activeStatuses.contains(order.status) &&
                  order.estimatedDays != null) {
                subtitleText = 'Fabricación: ~${order.estimatedDays} días';
              } else {
                subtitleText =
                    'Pedido el: ${dateFormatter.format(order.orderDate)}';
              }

              // Determino qué acciones están disponibles según el estado
              bool canCancel = order.status == 'pending';
              bool canSchedule = order.status == 'ready_for_delivery';
              bool requiresPaymentInfo = order.status == 'pending';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                elevation: 3.0,
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Chip(
                        label: Text(
                          order.statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: order.statusColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          currencyFormatter.format(order.totalPrice),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(subtitleText),
                  // Botón para programar la entrega solo cuando el pedido está listo
                  trailing: canSchedule
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: order.statusColor,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Programar',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    ScheduleDeliveryScreen(order: order),
                              ),
                            );
                          },
                        )
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Instrucciones de pago si el pedido está pendiente
                          if (requiresPaymentInfo)
                            _buildPaymentInstructions(
                              context,
                              order,
                              firestoreService,
                              currencyFormatter,
                            ),

                          const Divider(height: 16),
                          Text(
                            'Enviado a:',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(order.shippingAddress),
                          const Divider(height: 16),
                          Text(
                            'Artículos del Pedido:',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          ...order.items.map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                item.productName,
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: Text(
                                '${item.quantity} x ${currencyFormatter.format(item.price)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          // Botón de cancelar solo cuando está pendiente
                          if (canCancel) ...[
                            const Divider(height: 16),
                            Center(
                              child: OutlinedButton.icon(
                                icon:
                                    const Icon(Icons.cancel_outlined, size: 18),
                                label: const Text('Cancelar Pedido'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade700),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _showCancelConfirmationDialog(
                                  context,
                                  order,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Muestra las instrucciones de pago con los datos bancarios cuando el pedido
  // requiere un anticipo del 50% para iniciar la fabricación
  Widget _buildPaymentInstructions(
    BuildContext context,
    models.Order order,
    FirestoreService firestoreService,
    NumberFormat currencyFormatter,
  ) {
    return FutureBuilder<double>(
      future: _calculateTotalAdvance(order.items, firestoreService),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Text(
                "Calculando adelanto...",
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ),
          );
        }
        final totalAdvance = snapshot.hasError ? 0.0 : (snapshot.data ?? 0.0);

        // Si no requiere adelanto, solo muestro un mensaje de agradecimiento
        if (totalAdvance <= 0) {
          return Container(
            margin: const EdgeInsets.only(top: 8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              '¡Gracias por tu pedido! Comunicate conmigo para coordinar el pago. ',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
            ),
          );
        }

        final String formattedAdvance = currencyFormatter.format(totalAdvance);

        // Contenedor con todas las instrucciones de pago
        return Container(
          margin: const EdgeInsets.only(top: 8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.yellow.shade50,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pago Pendiente para Confirmar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para iniciar la fabricación, por favor realiza una transferencia por $formattedAdvance a:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              _buildCopyableRow(context, "Titular:", accountHolder),
              _buildCopyableRow(context, "CI/RUC:", accountCedula),
              _buildCopyableRow(context, "Banco:", bankName),
              _buildCopyableRow(
                  context, "Nº Cta (Familiar):", bankAccountNumber),
              _buildCopyableRow(
                  context, "Nº Cta (Otros):", otherBanksAccountNumber),
              const SizedBox(height: 8),
              Text(
                'Luego, envía tu comprobante a nuestro WhatsApp:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.message_outlined, size: 18),
                  label: const Text(
                    'Enviar Comprobante/Negocia pago en efectivo por WhatsApp',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green.shade800,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    _launchURL(context, 'https://wa.me/$contactWhatsapp');
                  },
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar Datos Transferencia'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade100,
                    foregroundColor: Colors.orange.shade900,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    final bankData = "Titular: $accountHolder\n"
                        "CI/RUC: $accountCedula\n"
                        "Banco: $bankName\n"
                        "Nº Cta (Familiar): $bankAccountNumber\n"
                        "Nº Cta (Otros Bancos): $otherBanksAccountNumber\n"
                        "Monto Adelanto: $formattedAdvance";
                    Clipboard.setData(ClipboardData(text: bankData));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Datos de transferencia copiados.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Calcula el anticipo total sumando el 50% de cada producto que lo requiere
  Future<double> _calculateTotalAdvance(
    List<models.OrderItem> items,
    FirestoreService firestoreService,
  ) async {
    double totalAdvance = 0;
    try {
      for (var item in items) {
        final productDoc = await firestoreService.getProductDoc(item.productId);
        if (productDoc.exists) {
          final productData = productDoc.data() as Map<String, dynamic>;
          final advance =
              (productData['advancePaymentAmount'] as num?)?.toDouble();
          if (advance != null && advance > 0) {
            totalAdvance += advance * item.quantity;
          }
        } else {
          print(
              "Advertencia: Producto ${item.productId} no encontrado al calcular adelanto.");
        }
      }
    } catch (e) {
      print("Error calculando adelanto total: $e");
      return 0;
    }
    return totalAdvance;
  }

  // Fila con un dato que se puede copiar tocándola - muestra un icono sutil de copiar
  Widget _buildCopyableRow(BuildContext context, String label, String value) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copiado.'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.copy, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// Extensión para acceder a documentos de productos desde FirestoreService
extension FirestoreServiceProductDoc on FirestoreService {
  Future<DocumentSnapshot> getProductDoc(String productId) {
    try {
      final FirebaseFirestore dbInstance = (this as dynamic)._db;
      return dbInstance.collection('products').doc(productId).get();
    } catch (e) {
      print("Error accessing _db in extension: $e");
      rethrow;
    }
  }
}
