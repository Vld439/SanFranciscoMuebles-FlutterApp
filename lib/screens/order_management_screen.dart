import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/firestore_models.dart' as models;
import '../services/firestore_service.dart';
import 'admin_order_history_screen.dart';

// Pantalla de gestión de pedidos para administradores
// Permite ver, actualizar estados, programar fabricación y archivar pedidos
class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  // Control de selección múltiple para archivar pedidos
  final Set<String> _selectedOrderIds = {};
  bool _isSelectionMode = false;
  final PageStorageKey _ordersListKey =
      const PageStorageKey('ordersList_v3_CLEAN');

  // Servicios y formateadores
  final Map<String, TextEditingController> _daysControllers = {};
  late final FirestoreService _firestoreService;
  final _currencyFormatter = NumberFormat.currency(
    locale: 'es_PY',
    symbol: 'Gs',
    decimalDigits: 0,
  );
  final _shortDateFormatter = DateFormat('dd/MM/yyyy');
  final _longDateFormatter = DateFormat('dd/MM/yyyy HH:mm');

  // Estados posibles de los pedidos
  final List<String> _orderStatuses = const [
    'pending',
    'confirmed',
    'scheduled',
    'in_production',
    'ready_for_delivery',
    'delivery_scheduled',
    'shipped',
    'delivered',
    'cancelled',
  ];

  // Estados considerados "activos" (en proceso)
  static const Set<String> _activeStatuses = {
    'confirmed',
    'scheduled',
    'in_production',
  };

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
  }

  // Manejo de selección múltiple de pedidos para acciones en lote (archivar)
  void _toggleSelection(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
      _isSelectionMode = _selectedOrderIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedOrderIds.clear();
      _isSelectionMode = false;
    });
  }

  // Pide confirmación antes de archivar los pedidos seleccionados
  Future<void> _showArchiveConfirmationDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivar Pedidos'),
        content: Text(
            '¿Estás seguro de mover ${_selectedOrderIds.length} pedido(s) al historial?'),
        actions: [
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Sí, Archivar'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.archiveOrders(_selectedOrderIds.toList());
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Pedidos movidos al historial.'),
            backgroundColor: Colors.green,
          ),
        );
        _clearSelection();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al archivar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // AppBar normal cuando no hay selección activa
  AppBar _buildRegularAppBar() {
    return AppBar(
      title: const Text('Gestionar Pedidos'),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_outlined),
          tooltip: 'Historial de Pedidos',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                // Asegúrate de crear esta pantalla
                builder: (_) => const AdminOrderHistoryScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  // AppBar contextual que aparece en modo selección (muestra conteo y acción)
  AppBar _buildContextualAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      title: Text('${_selectedOrderIds.length} seleccionado(s)'),
      backgroundColor: Colors.blueGrey[700],
      actions: [
        IconButton(
          icon: const Icon(Icons.archive_outlined),
          tooltip: 'Archivar Seleccionados',
          onPressed: _showArchiveConfirmationDialog,
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Limpiamos todos los controladores de texto cuando la pantalla se destruye
    for (final controller in _daysControllers.values) {
      controller.dispose();
    }
    _daysControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //  APPBAR DINÁMICO
      appBar:
          _isSelectionMode ? _buildContextualAppBar() : _buildRegularAppBar(),

      body: StreamBuilder<List<models.Order>>(
        //  STREAM DE PEDIDOS ACTIVOS
        stream: _firestoreService.getOrders(archived: false), // Solo activos
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error al cargar pedidos: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay pedidos activos.'));
          }

          final orders = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            key: _ordersListKey, // Asigna la key aquí
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              //Comprobar si está seleccionado
              final bool isSelected = _selectedOrderIds.contains(order.id);

              // Llama a la función que construye cada tarjeta de pedido
              return _buildOrderCard(
                context,
                order,
                isSelected, // Pasa el estado de selección
              );
            },
          );
        },
      ),
    );
  }

  // Tarjeta visual de un pedido con estado, monto, items y acciones
  Widget _buildOrderCard(
    BuildContext context,
    models.Order order,
    bool isSelected, // Recibe el estado de selección
  ) {
    // Subtítulo dinámico según el estado del pedido (fechas relevantes primero)
    String subtitleText;
    if (order.status == 'delivery_scheduled' &&
        order.scheduledDeliveryDate != null) {
      subtitleText =
          'Entrega: ${_longDateFormatter.format(order.scheduledDeliveryDate!)}';
    } else if (order.status == 'scheduled' &&
        order.manufacturingStartDate != null) {
      subtitleText =
          'Fabricar el: ${_shortDateFormatter.format(order.manufacturingStartDate!)}';
    } else if (order.status == 'cancelled') {
      subtitleText = 'Cancelado';
    } else {
      subtitleText = 'Pedido el: ${_longDateFormatter.format(order.orderDate)}';
    }

    // Notificador para alternar edición del estado sin reconstruir toda la lista
    final ValueNotifier<bool> isEditingStatusNotifier =
        ValueNotifier<bool>(false);
    // Busca el controlador en el mapa. Si no existe, lo crea y lo guarda
    final TextEditingController daysController = _daysControllers.putIfAbsent(
      order.id, // La llave única es el ID del pedido
      () => TextEditingController(),
    );
    // Cuando el admin cambia el estado, confirmo antes de aplicar el cambio
    Future<void> confirmAndUpdateStatus(
        BuildContext innerContext, String? newStatus) async {
      if (newStatus == null || newStatus == order.status) {
        isEditingStatusNotifier.value = false;
        return;
      }
      final newStatusText = models.Order(
              id: '',
              userId: '',
              items: [],
              totalPrice: 0,
              orderDate: DateTime.now(),
              status: newStatus,
              shippingAddress: '')
          .statusText;

      final bool? confirmed = await showDialog<bool>(
        context: innerContext,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar Cambio de Estado'),
          content: Text(
              '¿Estás seguro de que quieres cambiar el estado a "$newStatusText"?'),
          actions: [
            TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(ctx).pop(false)),
            TextButton(
                child: const Text('Sí, Cambiar'),
                onPressed: () => Navigator.of(ctx).pop(true)),
          ],
        ),
      );

      if (confirmed == true) {
        final rootFirestoreService = context.read<FirestoreService>();
        final rootMessenger = ScaffoldMessenger.of(context);
        try {
          await rootFirestoreService
              .updateOrder(order.id, {'status': newStatus});
          if (!innerContext.mounted) return;
          rootMessenger.showSnackBar(SnackBar(
              content: Text('Estado actualizado a "$newStatusText".'),
              backgroundColor: Colors.green));
        } catch (e) {
          if (!innerContext.mounted) return;
          rootMessenger.showSnackBar(SnackBar(
              content: Text('Error al actualizar estado: $e'),
              backgroundColor: Colors.red));
        } finally {
          if (innerContext.mounted) {
            isEditingStatusNotifier.value = false;
          }
        }
      } else {
        isEditingStatusNotifier.value = false;
      }
    }

    // Tarjeta principal del pedido
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4.0,
      clipBehavior: Clip.antiAlias,
      //Color si está seleccionado
      color: isSelected ? const Color.fromARGB(255, 36, 19, 191) : null,

      child: DisposeNotifier(
        notifiers: [isEditingStatusNotifier], // <-- Solo el notifier de edición
        //Envolvido en InkWell para selección
        child: InkWell(
          onLongPress: () => _toggleSelection(order.id),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(order.id);
            }
          },
          child: ExpansionTile(
            key: PageStorageKey('${order.id}_v3_CLEAN'),
            // Checkbox visible sólo en modo selección
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(order.id),
                  )
                : null,

            // El resto de la tarjeta sigue igual
            title: Row(
              children: [
                Chip(
                  label: Text(order.statusText,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: order.statusColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 2.0),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _currencyFormatter.format(order.totalPrice),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Text(subtitleText),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerInfo(context, order.userId),
                    const Divider(height: 24),
                    Text('Dirección de Envío:',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(order.shippingAddress),
                    const Divider(height: 24),
                    Text('Artículos del Pedido:',
                        style: Theme.of(context).textTheme.bodySmall),
                    ...order.items.map((item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(item.productName,
                              style: const TextStyle(fontSize: 14)),
                          trailing: Text(
                              '${item.quantity} x ${_currencyFormatter.format(item.price)}',
                              style: const TextStyle(fontSize: 14)),
                        )),
                    const Divider(height: 24),
                    // Muestra días estimados sólo si el pedido sigue activo
                    if (_activeStatuses.contains(order.status) &&
                        order.estimatedDays != null) ...[
                      Text('Días Estimados de Fabricación:',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        '${order.estimatedDays} días',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                    ],

                    if (order.status == 'pending')
                      _buildPendingOrderActions(
                          context, order, _firestoreService, daysController)
                    else
                      ValueListenableBuilder<bool>(
                        valueListenable: isEditingStatusNotifier,
                        builder: (innerContext, isEditing, child) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Estado Actual:',
                                  style: Theme.of(innerContext)
                                      .textTheme
                                      .bodySmall),
                              const SizedBox(height: 8),
                              isEditing
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        border: Border.all(
                                            color: Theme.of(innerContext)
                                                .colorScheme
                                                .primary),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: order.status,
                                          isExpanded: true,
                                          items: _orderStatuses.map((status) {
                                            final text = models.Order(
                                                    id: '',
                                                    userId: '',
                                                    items: [],
                                                    totalPrice: 0,
                                                    orderDate: DateTime.now(),
                                                    status: status,
                                                    shippingAddress: '')
                                                .statusText;
                                            return DropdownMenuItem(
                                                value: status,
                                                child: Text(text));
                                          }).toList(),
                                          onChanged: (String? newStatus) {
                                            confirmAndUpdateStatus(
                                                innerContext, newStatus);
                                          },
                                        ),
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Chip(
                                          label: Text(order.statusText,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12)),
                                          backgroundColor: order.statusColor,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0, vertical: 2.0),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        const Spacer(),
                                        OutlinedButton.icon(
                                          icon:
                                              const Icon(Icons.edit, size: 16),
                                          label: const Text('Editar'),
                                          style: OutlinedButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              foregroundColor:
                                                  Theme.of(innerContext)
                                                      .colorScheme
                                                      .secondary,
                                              side: BorderSide(
                                                  color: Theme.of(innerContext)
                                                      .colorScheme
                                                      .secondary
                                                      .withOpacity(0.5))),
                                          onPressed: () {
                                            isEditingStatusNotifier.value =
                                                true;
                                          },
                                        )
                                      ],
                                    ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Acciones disponibles cuando el pedido está pendiente (cancelar/programar/confirmar)
  Widget _buildPendingOrderActions(
    BuildContext context,
    models.Order order,
    FirestoreService firestoreService,
    TextEditingController daysController,
  ) {
    final messenger = ScaffoldMessenger.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acciones del Pedido:',
            style: Theme.of(context).textTheme.bodySmall),
        TextField(
          key: PageStorageKey('${order.id}_days_field_v3_CLEAN'),
          controller: daysController,
          decoration: const InputDecoration(
            labelText: 'Días estimados de fabricación',
            hintText: 'Requerido para Confirmar o Programar',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                  visualDensity: VisualDensity.compact),
              child: const Text('Cancelar'),
              onPressed: () async {
                final bool? confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cancelar Pedido'),
                    content: const Text('¿Estás seguro?'),
                    actions: [
                      TextButton(
                          child: const Text('No'),
                          onPressed: () => Navigator.of(ctx).pop(false)),
                      TextButton(
                          child: const Text('Sí, Cancelar',
                              style: TextStyle(color: Colors.red)),
                          onPressed: () => Navigator.of(ctx).pop(true)),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await firestoreService.cancelOrderAndUpdateStock(order.id);
                    if (!context.mounted) return;
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Pedido cancelado por admin.')));
                  } catch (e) {
                    if (!context.mounted) return;
                    messenger.showSnackBar(SnackBar(
                        content: Text('Error al cancelar: $e'),
                        backgroundColor: Colors.red));
                  }
                }
              },
            )),
            const SizedBox(width: 8),
            Expanded(
                child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  visualDensity: VisualDensity.compact),
              child: const Text('Programar'),
              onPressed: () async {
                final daysStr = daysController.text;
                final days = int.tryParse(daysStr);
                if (days == null || days <= 0) {
                  _showErrorSnackBar(
                      context, 'Ingresa un número válido de días estimados.');
                  return;
                }
                final DateTime? selectedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (selectedDate != null) {
                  try {
                    await firestoreService.updateOrder(
                      order.id,
                      {
                        'status': 'scheduled',
                        'estimatedDays': days,
                        'manufacturingStartDate':
                            Timestamp.fromDate(selectedDate),
                      },
                    );
                    if (!context.mounted) return;
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Pedido programado.'),
                        backgroundColor: Colors.cyan));
                  } catch (e) {
                    if (!context.mounted) return;
                    messenger.showSnackBar(SnackBar(
                        content: Text('Error al programar: $e'),
                        backgroundColor: Colors.red));
                  }
                }
              },
            )),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size(double.infinity, 36),
              visualDensity: VisualDensity.compact),
          child: const Text('Confirmar (Iniciar ya)'),
          onPressed: () async {
            final daysStr = daysController.text;
            final days = int.tryParse(daysStr);
            if (days == null || days <= 0) {
              _showErrorSnackBar(
                  context, 'Ingresa un número válido de días estimados.');
              return;
            }
            try {
              await firestoreService.updateOrder(
                order.id,
                {
                  'status': 'confirmed',
                  'estimatedDays': days,
                  'manufacturingStartDate': FieldValue.delete(),
                },
              );
              if (!context.mounted) return;
              messenger.showSnackBar(const SnackBar(
                  content: Text('Pedido confirmado.'),
                  backgroundColor: Colors.green));
            } catch (e) {
              if (!context.mounted) return;
              messenger.showSnackBar(SnackBar(
                  content: Text('Error al confirmar: $e'),
                  backgroundColor: Colors.red));
            }
          },
        ),
      ],
    );
  }

  // Helper para mostrar SnackBar de error
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3)),
    );
  }

  // Sección con la información del cliente y accesos rápidos (llamar/WhatsApp/copiar)
  Widget _buildCustomerInfo(BuildContext context, String userId) {
    // _firestoreService ya está disponible como variable de la clase
    return StreamBuilder<models.AppUser?>(
      stream: _firestoreService.getUserStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Text('Cargando datos del cliente...',
                  style: TextStyle(fontStyle: FontStyle.italic)));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Text('Cliente no encontrado',
              style: TextStyle(color: Colors.red));
        }

        final user = snapshot.data!;
        final phoneNumber = user.phoneNumber ?? 'No disponible';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Cliente: ${user.displayName ?? 'Sin Nombre'} (ID: ${user.uid.substring(0, 6)}...)',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text('Email: ${user.email ?? 'No disponible'}',
                style: Theme.of(context).textTheme.bodySmall),
            Text('Teléfono: $phoneNumber',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.outlined(
                    icon: const Icon(Icons.call_outlined),
                    tooltip: 'Llamar al cliente',
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    onPressed: phoneNumber != 'No disponible'
                        ? () => _launchURL('tel:$phoneNumber')
                        : null),
                IconButton.outlined(
                    icon: const Icon(Icons.message_outlined),
                    tooltip: 'Enviar WhatsApp',
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    onPressed: phoneNumber != 'No disponible'
                        ? () => _launchURL('https://wa.me/$phoneNumber')
                        : null),
                IconButton.outlined(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'Copiar número de teléfono',
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    onPressed: phoneNumber != 'No disponible'
                        ? () {
                            Clipboard.setData(ClipboardData(text: phoneNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Número copiado'),
                                    duration: Duration(seconds: 1)));
                          }
                        : null),
              ],
            ),
          ],
        );
      },
    );
  }

  // Abre un URL externo (teléfono/WhatsApp) usando la app correspondiente
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print('Advertencia: No se pudo lanzar $url');
    }
  }
}

//  Widget Helper para Dispose (O)
class DisposeNotifier extends StatefulWidget {
  // Aceptará una lista de cualquier tipo de Notifier
  final List<ChangeNotifier> notifiers;
  final Widget child;

  const DisposeNotifier({
    super.key,
    required this.notifiers,
    required this.child,
  });

  @override
  State<DisposeNotifier> createState() => _DisposeNotifierState();
}

class _DisposeNotifierState extends State<DisposeNotifier> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    // Hace un bucle y elimina CADA notifier en la lista
    for (final notifier in widget.notifiers) {
      notifier.dispose();
    }
    super.dispose();
  }
}
