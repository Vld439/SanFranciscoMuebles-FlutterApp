// Pantalla de Historial de Pedidos para Administradores
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/firestore_models.dart' as models;
import '../services/firestore_service.dart';

//Classe AdminOrderHistoryScreen que muestra el historial de pedidos archivados
class AdminOrderHistoryScreen extends StatefulWidget {
  const AdminOrderHistoryScreen({super.key});

  @override
  State<AdminOrderHistoryScreen> createState() =>
      _AdminOrderHistoryScreenState(); //Estado que nos permite manejar la selección y restauración de pedidos
}

class _AdminOrderHistoryScreenState extends State<AdminOrderHistoryScreen> {
  // Controla qué pedidos están marcados para restaurar al historial activo
  final Set<String> _selectedOrderIds = {};
  bool _isSelectionMode = false;
  final PageStorageKey _historyListKey =
      const PageStorageKey('historyList_v1_CLEAN');

  late final FirestoreService _firestoreService;

  // Formateadores que uso en toda la pantalla para fechas y precios
  final _currencyFormatter = NumberFormat.currency(
    locale: 'es_PY',
    symbol: 'Gs',
    decimalDigits: 0,
  );
  final _shortDateFormatter = DateFormat('dd/MM/yyyy');
  final _longDateFormatter = DateFormat('dd/MM/yyyy HH:mm');

  // Todos los estados posibles por los que puede pasar un pedido en el sistema
  // Esto me sirve para el dropdown cuando quiero cambiar manualmente un estado
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

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
  }

  // Manejo de selección múltiple - cuando toco prolongadamente un pedido
  // puedo seleccionar varios y restaurarlos todos de una vez
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

  // Pide confirmación antes de restaurar los pedidos seleccionados
  // y moverlos de vuelta a la lista principal de pedidos activos
  Future<void> _showRestoreConfirmationDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar Pedidos'),
        content: Text(
            '¿Estás seguro de restaurar ${_selectedOrderIds.length} pedido(s) a la lista principal?'),
        actions: [
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Sí, Restaurar'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.restoreOrders(_selectedOrderIds.toList());
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Pedidos restaurados a la lista principal.'),
            backgroundColor: Colors.green,
          ),
        );
        _clearSelection();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al restaurar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Cuando no hay selección, muestro el appbar normal del historial
  AppBar _buildRegularAppBar() {
    return AppBar(
      title: const Text('Historial de Pedidos'),
    );
  }

  // En modo selección aparece este appbar especial con contador y botón de restaurar
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
          icon: const Icon(Icons.unarchive_outlined),
          tooltip: 'Restaurar Seleccionados',
          onPressed: _showRestoreConfirmationDialog,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          _isSelectionMode ? _buildContextualAppBar() : _buildRegularAppBar(),
      body: StreamBuilder<List<models.Order>>(
        stream: _firestoreService.getOrders(archived: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error al cargar historial: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay pedidos en el historial.'));
          }

          final orders = snapshot.data!;

          return ListView.builder(
            key: _historyListKey,
            padding: const EdgeInsets.all(8.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final bool isSelected = _selectedOrderIds.contains(order.id);

              return _buildOrderCard(
                context,
                order,
                isSelected,
              );
            },
          );
        },
      ),
    );
  }

  // Construye cada tarjeta de pedido archivado con toda su información
  // Incluye selección múltiple, edición de estado y datos del cliente
  Widget _buildOrderCard(
    BuildContext context,
    models.Order order,
    bool isSelected,
  ) {
    // El subtítulo varía según el estado del pedido - priorizo las fechas importantes
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

    final ValueNotifier<bool> isEditingStatusNotifier =
        ValueNotifier<bool>(false);

    // Cuando cambio el estado en el dropdown, pido confirmación antes de guardarlo
    // Esto evita cambios accidentales que podrían afectar el flujo del pedido
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

    // Tarjeta Principal
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4.0,
      clipBehavior: Clip.antiAlias,
      color: isSelected ? const Color.fromARGB(255, 36, 19, 191) : null,
      child: DisposeNotifier(
        notifier: isEditingStatusNotifier,
        child: InkWell(
          onLongPress: () => _toggleSelection(order.id),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(order.id);
            }
          },
          child: ExpansionTile(
            key: PageStorageKey('${order.id}_history_v1_CLEAN'),
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(order.id),
                  )
                : null,
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
                    ValueListenableBuilder<bool>(
                      valueListenable: isEditingStatusNotifier,
                      builder: (innerContext, isEditing, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Estado Actual:',
                                style:
                                    Theme.of(innerContext).textTheme.bodySmall),
                            const SizedBox(height: 8),
                            isEditing
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8.0),
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
                                              value: status, child: Text(text));
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
                                        icon: const Icon(Icons.edit, size: 16),
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
                                          isEditingStatusNotifier.value = true;
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

  // Muestra la información del cliente con botones para llamar, enviar WhatsApp o copiar el teléfono
  // Los datos vienen en tiempo real de Firestore para estar siempre actualizados
  Widget _buildCustomerInfo(BuildContext context, String userId) {
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

  // Abre enlaces externos como llamadas telefónicas o WhatsApp
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print('Advertencia: No se pudo lanzar $url');
    }
  }
}

//Widget Helper para Dispose
class DisposeNotifier extends StatefulWidget {
  final ValueNotifier notifier;
  final Widget child;
  const DisposeNotifier(
      {super.key, required this.notifier, required this.child});

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
    widget.notifier.dispose();
    super.dispose();
  }
}
