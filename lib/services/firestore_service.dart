import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/firestore_models.dart';
import '../providers/cart_provider.dart';
import 'storage_service.dart';

// Servicio principal para manejar todas las operaciones con Firestore
// Incluye gestión de productos, categorías, usuarios y pedidos
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  //  FUNCIONES PARA PRODUCTOS

  // Genera palabras clave para hacer búsquedas más eficientes
  // Por ejemplo, "Mesa Comedor" genera: ["m", "me", "mes", "mesa", "c", "co", "com"...]
  // Esto permite buscar productos mientras el usuario escribe
  List<String> _generateSearchKeywords(String name) {
    Set<String> keywords = {};
    List<String> words = name.toLowerCase().split(RegExp(r'\s+'));
    for (String word in words) {
      if (word.isNotEmpty) {
        // Genera todas las subcadenas posibles de cada palabra
        for (int i = 1; i <= word.length; i++) {
          keywords.add(word.substring(0, i));
        }
      }
    }
    return keywords.toList();
  }

  // Obtiene todos los productos disponibles en tiempo real
  // Cada vez que hay cambios en Firestore, se actualiza automáticamente
  Stream<List<Product>> getProducts() {
    return _db.collection('products').snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList(),
        );
  }

  // Filtra productos por categoría específica
  // Útil para mostrar solo mesas, sillas, etc.
  Stream<List<Product>> getProductsByCategory(String categoryId) {
    return _db
        .collection('products')
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList(),
        );
  }

  // Filtra productos por múltiples categorías a la vez
  // Si la lista está vacía, devuelve todos los productos
  Stream<List<Product>> getProductsByCategories(List<String> categoryIds) {
    if (categoryIds.isEmpty) {
      return getProducts();
    }
    return _db
        .collection('products')
        .where('categoryId', whereIn: categoryIds)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList(),
        );
  }

  // Busca productos por texto
  // Firestore tiene limitaciones, así que primero filtramos con la primera palabra
  // y luego refinamos la búsqueda en el cliente con el resto de palabras
  // Ejemplo: "mesa madera" → busca "mesa" en Firestore, luego filtra "madera" aquí
  Stream<List<Product>> searchProducts(String query) {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return Stream.value([]);
    }

    // Dividimos la búsqueda en palabras individuales
    List<String> searchTerms = trimmedQuery
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    if (searchTerms.isEmpty) {
      return Stream.value([]);
    }

    // Buscamos en Firestore solo con la primera palabra (limitación de Firestore)
    Query initialQuery = _db
        .collection('products')
        .where('searchKeywords', arrayContains: searchTerms.first);

    // Luego filtramos el resto de palabras en la app
    return initialQuery.snapshots().map((snapshot) {
      List<Product> products =
          snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();

      // Si hay más de una palabra, filtramos más
      if (searchTerms.length > 1) {
        products = products.where((product) {
          // El producto debe contener TODAS las palabras buscadas
          for (int i = 1; i < searchTerms.length; i++) {
            if (!product.searchKeywords.contains(searchTerms[i])) {
              return false;
            }
          }
          return true;
        }).toList();
      }

      return products;
    });
  }

  // Crea un nuevo producto en Firestore
  // Genera automáticamente las palabras clave para búsqueda
  Future<String> addProduct(Product product) async {
    List<String> keywords = _generateSearchKeywords(product.name);
    final docRef = await _db.collection('products').add({
      'name': product.name,
      'description': product.description,
      'price': product.price,
      'categoryId': product.categoryId,
      'imageUrls': product.imageUrls,
      'searchKeywords': keywords,
      'stockQuantity': product.stockQuantity,
      'advancePaymentAmount': product.advancePaymentAmount,
    });
    return docRef.id;
  }

  // Actualiza un producto existente
  // Si cambias el nombre, regenera automáticamente las palabras clave
  Future<void> updateProduct(String productId, Map<String, dynamic> data) {
    if (data.containsKey('name') && data['name'] is String) {
      data['searchKeywords'] = _generateSearchKeywords(data['name']);
    }
    if (data.containsKey('advancePaymentAmount') &&
        data['advancePaymentAmount'] is String) {
      data['advancePaymentAmount'] = double.tryParse(
        data['advancePaymentAmount'] as String,
      );
    } else if (data.containsKey('advancePaymentAmount') &&
        data['advancePaymentAmount'] != null &&
        data['advancePaymentAmount'] is! double) {
      data['advancePaymentAmount'] =
          (data['advancePaymentAmount'] as num).toDouble();
    }
    return _db.collection('products').doc(productId).update(data);
  }

  // Elimina un producto completamente
  // También borra todas sus imágenes del Storage para no desperdiciar espacio
  Future<void> deleteProduct(String productId) async {
    await StorageService().deleteProductImages(productId);
    return _db.collection('products').doc(productId).delete();
  }

  // Obtiene un documento de producto específico
  Future<DocumentSnapshot> getProductDoc(String productId) {
    return _db.collection('products').doc(productId).get();
  }

  //  FUNCIONES PARA CATEGORÍAS

  // Obtiene todas las categorías en tiempo real
  Stream<List<Category>> getCategories() {
    return _db.collection('categories').snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList(),
        );
  }

  Future<DocumentReference> addCategory(String categoryName) {
    return _db.collection('categories').add({'name': categoryName});
  }

  Future<void> updateCategory(String categoryId, String newName) {
    return _db.collection('categories').doc(categoryId).update({
      'name': newName,
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    return _db.collection('categories').doc(categoryId).delete();
  }

  //  FUNCIONES PARA USUARIOS

  // Obtiene los datos de un usuario en tiempo real
  // Se actualiza automáticamente cuando el usuario cambia su perfil
  Stream<AppUser?> getUserStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _db.collection('users').doc(uid).update(data);
  }

  // Guarda el token de notificaciones push del usuario
  // Lo usamos para enviar notificaciones cuando cambia el estado de sus pedidos
  Future<void> saveUserToken(String uid, String? token) async {
    if (token == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error al guardar token FCM para $uid: $e');
    }
  }

  //  FUNCIONES PARA PEDIDOS

  // Obtiene los pedidos activos o archivados
  // Los admins usan esto para ver todos los pedidos del sistema
  // archived=false → pedidos activos, archived=true → historial
  Stream<List<Order>> getOrders({bool archived = false}) {
    return _db
        .collection('orders')
        .where('isArchived', isEqualTo: archived) // Filtro añadido
        .orderBy('orderDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList(),
        );
  }

  // Obtiene solo los pedidos de un usuario específico
  // Los clientes usan esto para ver su historial de compras
  Stream<List<Order>> getOrdersForUser(String userId, {bool archived = false}) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('orderDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList(),
        );
  }

  // Actualiza cualquier campo de un pedido
  // Por ejemplo: cambiar estado, fecha de fabricación, etc.
  Future<void> updateOrder(String orderId, Map<String, dynamic> data) {
    if (data.containsKey('manufacturingStartDate') &&
        data['manufacturingStartDate'] is DateTime) {
      data['manufacturingStartDate'] = Timestamp.fromDate(
        data['manufacturingStartDate'],
      );
    }
    if (data.containsKey('scheduledDeliveryDate') &&
        data['scheduledDeliveryDate'] is DateTime) {
      data['scheduledDeliveryDate'] = Timestamp.fromDate(
        data['scheduledDeliveryDate'],
      );
    }
    return _db.collection('orders').doc(orderId).update(data);
  }

  // Crea un nuevo pedido y descuenta el stock automáticamente
  // Usa transacciones para asegurar que todo se haga correctamente
  // Si hay stock de un producto, lo descuenta; si no hay, se marca como "por pedido"
  // Si el pedido no requiere adelanto, va directo a "listo para entrega"
  Future<void> createOrder({
    required String userId,
    required String shippingAddress,
    required List<CartItem> items,
    required double totalPrice,
    required double totalAdvanceAmount,
  }) async {
    await _db.runTransaction((transaction) async {
      // Primero revisamos qué productos tienen stock para descontar
      final Map<String, int> stockUpdates = {};
      final List<DocumentReference> productRefsToRead = [];

      for (var item in items) {
        if (item.stockAvailable > 0) {
          final currentUpdate = stockUpdates[item.id] ?? 0;
          stockUpdates[item.id] = currentUpdate + item.quantity;
          if (currentUpdate == 0) {
            productRefsToRead.add(_db.collection('products').doc(item.id));
          }
        }
      }

      // Leemos los productos de la base de datos dentro de la transacción
      List<DocumentSnapshot> productSnapshots = [];
      if (productRefsToRead.isNotEmpty) {
        productSnapshots = await Future.wait(
          productRefsToRead.map((ref) => transaction.get(ref)).toList(),
        );
      }

      // Verificamos que haya suficiente stock y lo descontamos
      for (final productDoc in productSnapshots) {
        if (!productDoc.exists) {
          throw Exception('Producto con ID ${productDoc.id} no encontrado.');
        }
        final productData = productDoc.data() as Map<String, dynamic>;
        final currentStock = productData['stockQuantity'] ?? 0;
        final quantityNeeded = stockUpdates[productDoc.id]!;

        if (currentStock < quantityNeeded) {
          final productName = productData['name'] ?? 'Desconocido';
          throw Exception(
            'Stock insuficiente para $productName. Disponible: $currentStock, Pedido: $quantityNeeded',
          );
        }
        final newStock = currentStock - quantityNeeded;
        transaction.update(productDoc.reference, {'stockQuantity': newStock});
      }

      // Creamos el pedido con el estado inicial correcto
      final orderRef = _db.collection('orders').doc();
      transaction.set(orderRef, {
        'userId': userId,
        'shippingAddress': shippingAddress,
        'totalPrice': totalPrice,
        'orderDate': FieldValue.serverTimestamp(),
        // Si no requiere adelanto, ya está listo para entregar
        'status': totalAdvanceAmount > 0 ? 'pending' : 'ready_for_delivery',
        'isArchived': false,
        'items': items
            .map(
              (item) => {
                'productId': item.id,
                'productName': item.name,
                'quantity': item.quantity,
                'price': item.price,
              },
            )
            .toList(),
      });
    });
  }

  // Cancela un pedido y devuelve el stock a los productos
  // Usa transacciones para asegurar consistencia
  // No se puede cancelar un pedido ya cancelado o entregado
  Future<void> cancelOrderAndUpdateStock(String orderId) async {
    await _db.runTransaction((transaction) async {
      final orderRef = _db.collection('orders').doc(orderId);
      final orderSnapshot = await transaction.get(orderRef);

      if (!orderSnapshot.exists) {
        throw Exception("Pedido no encontrado (ID: $orderId).");
      }

      final orderData = orderSnapshot.data() as Map<String, dynamic>;
      final orderItems = (orderData['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [];

      final currentStatus = orderData['status'] ?? 'pending';
      if (currentStatus == 'cancelled' || currentStatus == 'delivered') {
        // Ya está cancelado o entregado, no hacemos nada
        print(
            "Intento de cancelar un pedido ya $currentStatus (ID: $orderId). No se hace nada.");
        return;
      }

      // Preparamos la devolución del stock
      final Map<DocumentReference, int> stockIncrements = {};
      final List<DocumentReference> productRefsToRead = [];

      for (var item in orderItems) {
        final productRef = _db.collection('products').doc(item.productId);
        if (!productRefsToRead.contains(productRef)) {
          productRefsToRead.add(productRef);
        }
        stockIncrements[productRef] =
            (stockIncrements[productRef] ?? 0) + item.quantity;
      }

      List<DocumentSnapshot> productSnapshots = [];
      if (productRefsToRead.isNotEmpty) {
        productSnapshots = await Future.wait(
            productRefsToRead.map((ref) => transaction.get(ref)).toList());
      }

      // Devolvemos el stock a cada producto
      for (final productDoc in productSnapshots) {
        if (!productDoc.exists) {
          print(
              "Advertencia: Producto ${productDoc.id} no encontrado al cancelar pedido $orderId. No se devuelve stock para este item.");
          continue;
        }
        final quantityToReturn = stockIncrements[productDoc.reference];
        if (quantityToReturn != null && quantityToReturn > 0) {
          transaction.update(productDoc.reference, {
            'stockQuantity': FieldValue.increment(quantityToReturn),
          });
        }
      }

      // Marcamos el pedido como cancelado
      transaction.update(orderRef, {
        'status': 'cancelled',
        'cancelledDate': FieldValue.serverTimestamp()
      });
    });
  }

  //  FUNCIONES PARA ARCHIVAR PEDIDOS

  // Mueve pedidos al historial (archivarlos)
  // Útil para limpiar la vista de pedidos activos sin borrarlos
  Future<void> archiveOrders(List<String> orderIds) async {
    final batch = _db.batch();
    for (final orderId in orderIds) {
      final docRef = _db.collection('orders').doc(orderId);
      batch.set(docRef, {'isArchived': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // Restaura pedidos desde el historial
  // Vuelven a aparecer en la vista de pedidos activos
  Future<void> restoreOrders(List<String> orderIds) async {
    final batch = _db.batch();
    for (final orderId in orderIds) {
      final docRef = _db.collection('orders').doc(orderId);
      batch.set(docRef, {'isArchived': false}, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
