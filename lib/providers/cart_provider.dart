import 'package:flutter/foundation.dart';
import '../models/firestore_models.dart';

// Representa un producto en el carrito de compras
class CartItem {
  final String id;
  final String name;
  final double price;
  final double?
      advancePaymentAmount; // Adelanto requerido por unidad (null si no aplica)
  int quantity;
  final int stockAvailable; // Para saber si hay stock disponible

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.advancePaymentAmount,
    required this.quantity,
    required this.stockAvailable,
  });
}

// Gestor del carrito de compras usando Provider
// Maneja agregar, quitar productos y calcular totales
class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  // Cuenta el total de productos en el carrito (sumando cantidades)
  // Ejemplo: 2 mesas + 3 sillas = 5 items
  int get itemCount {
    int totalCount = 0;
    _items.forEach((key, cartItem) {
      totalCount += cartItem.quantity;
    });
    return totalCount;
  }

  // Calcula el precio total del carrito
  // precio × cantidad de cada producto
  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  // Calcula el adelanto total requerido
  // Solo se cobra adelanto en productos sin stock (por pedido)
  // Si hay stock, no hay adelanto
  double get totalAdvanceAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      // Si hay stock, no cobramos adelanto
      if (cartItem.stockAvailable > 0) return;
      // Si no hay stock, multiplicamos el adelanto por la cantidad
      if (cartItem.advancePaymentAmount != null) {
        total += cartItem.advancePaymentAmount! * cartItem.quantity;
      }
    });
    return total;
  }

  // Agrega un producto al carrito
  // Verifica que haya stock disponible antes de agregar
  // Retorna null si se agregó correctamente, o un mensaje de error
  String? addItem(Product product) {
    if (product.isInStock) {
      // Si el producto tiene stock, verificamos que no excedamos el disponible
      final existingQuantity =
          _items.containsKey(product.id) ? _items[product.id]!.quantity : 0;
      final availableStock = product.stockQuantity;

      if (existingQuantity + 1 > availableStock) {
        return '¡Lo sentimos! Solo quedan $availableStock unidades de ${product.name} en stock.';
      }
    }

    if (_items.containsKey(product.id)) {
      // Ya existe en el carrito, aumentamos la cantidad
      _items.update(
        product.id,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          name: existingCartItem.name,
          price: existingCartItem.price,
          advancePaymentAmount: product.advancePaymentAmount ??
              existingCartItem.advancePaymentAmount,
          quantity: existingCartItem.quantity + 1,
          stockAvailable: product.stockQuantity,
        ),
      );
    } else {
      // Es nuevo, lo agregamos al carrito
      _items.putIfAbsent(
        product.id,
        () => CartItem(
          id: product.id,
          name: product.name,
          price: product.price,
          advancePaymentAmount: product.advancePaymentAmount,
          quantity: 1,
          stockAvailable: product.stockQuantity,
        ),
      );
    }
    notifyListeners(); // Notifica a la UI para que se actualice
    return null;
  }

  // Reduce la cantidad de un producto en el carrito
  // Si llega a 0, lo elimina del carrito
  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          name: existingCartItem.name,
          price: existingCartItem.price,
          advancePaymentAmount: existingCartItem.advancePaymentAmount,
          quantity: existingCartItem.quantity - 1,
          stockAvailable: existingCartItem.stockAvailable,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  // Elimina completamente un producto del carrito
  // Sin importar la cantidad que tenga
  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  // Vacía completamente el carrito
  // Se usa después de finalizar una compra
  void clear() {
    _items.clear();
    notifyListeners();
  }
}
