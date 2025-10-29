import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/firestore_models.dart';
import '../providers/cart_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

// Pantalla del carrito de compras
// Muestra los productos agregados y permite confirmar el pedido
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  // Confirma el pedido y lo envía a Firestore
  // Verifica que el usuario tenga dirección de envío antes de proceder
  Future<void> _confirmOrder(BuildContext context) async {
    final cartProvider = context.read<CartProvider>();
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context); // Guardamos antes del async

    final user = authService.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Error: Usuario no autenticado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Verificamos que el usuario tenga dirección de envío configurada
    final appUser = await firestoreService.getUserStream(user.uid).first;
    final shippingAddress = appUser?.shippingAddress;

    if (shippingAddress == null || shippingAddress.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, añade una dirección de envío en tu perfil antes de pedir.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Creamos el pedido en Firestore
      await firestoreService.createOrder(
        userId: user.uid,
        shippingAddress: shippingAddress,
        items: cartProvider.items.values.toList(),
        totalPrice: cartProvider.totalAmount,
        totalAdvanceAmount: cartProvider.totalAdvanceAmount,
      );

      // Limpiamos el carrito después de crear el pedido
      cartProvider.clear();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('¡Pedido realizado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop(); // Volvemos a la pantalla anterior
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al crear el pedido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_PY',
      symbol: 'Gs',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Carrito')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: cart.items.length,
              itemBuilder: (ctx, i) {
                final cartItem = cart.items.values.toList()[i];
                return Dismissible(
                  // Deslizar para eliminar (swipe to delete)
                  key: ValueKey(cartItem.id),
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 4,
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) {
                    // Pedimos confirmación antes de eliminar
                    return showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Estás seguro?'),
                        content: Text(
                          '¿Quieres eliminar ${cartItem.name} del carrito?',
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('No'),
                            onPressed: () {
                              Navigator.of(ctx).pop(false);
                            },
                          ),
                          TextButton(
                            child: const Text('Sí'),
                            onPressed: () {
                              Navigator.of(ctx).pop(true);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    context.read<CartProvider>().removeItem(cartItem.id);
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(cartItem.name),
                        subtitle: Text(
                          'Total: ${currencyFormatter.format(cartItem.price * cartItem.quantity)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botón para reducir cantidad
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () => context
                                  .read<CartProvider>()
                                  .removeSingleItem(cartItem.id),
                            ),
                            Text('${cartItem.quantity} x'),
                            // Botón para aumentar cantidad
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                // Recreamos un producto para validar stock
                                final productToAdd = Product(
                                  id: cartItem.id,
                                  name: cartItem.name,
                                  price: cartItem.price,
                                  stockQuantity: cartItem.stockAvailable,
                                  description: '',
                                  categoryId: '',
                                  imageUrls: [],
                                  advancePaymentAmount:
                                      cartItem.advancePaymentAmount,
                                );
                                final errorMessage = context
                                    .read<CartProvider>()
                                    .addItem(productToAdd);
                                // Si hay error (stock insuficiente), mostramos mensaje
                                if (errorMessage != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(errorMessage),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Muestra el total del pedido
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text('Total', style: TextStyle(fontSize: 20)),
                    Chip(
                      label: Text(
                        currencyFormatter.format(cart.totalAmount),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).primaryTextTheme.titleLarge?.color,
                        ),
                      ),
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Solo muestra el adelanto si hay productos por pedido
                if (cart.totalAdvanceAmount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Adelanto requerido',
                          style: TextStyle(fontSize: 16)),
                      Chip(
                        label: Text(
                          currencyFormatter.format(cart.totalAdvanceAmount),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).primaryTextTheme.titleLarge?.color,
                          ),
                        ),
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: (cart.items.isEmpty)
                      ? null
                      : () => _confirmOrder(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('REALIZAR PEDIDO'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
