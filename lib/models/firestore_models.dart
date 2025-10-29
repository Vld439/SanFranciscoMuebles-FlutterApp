import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Modelo para las categorías de productos
// Ejemplo: Mesas, Sillas, Escritorios, etc.
class Category {
  final String id;
  final String name;

  Category({required this.id, required this.name});

  // Convierte un documento de Firestore en un objeto Category
  factory Category.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Category(id: doc.id, name: data['name'] ?? '');
  }
}

// Modelo para los productos del catálogo
// Incluye información de precio, stock, imágenes y adelantos
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId; // Referencia a la categoría
  final List<String> imageUrls; // URLs de las imágenes en Storage
  final List<String> searchKeywords; // Palabras clave para búsqueda
  final int stockQuantity; // 0 = por pedido, >0 = entrega inmediata
  final double? advancePaymentAmount; // Adelanto requerido (null si no aplica)

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.imageUrls,
    this.searchKeywords = const [],
    this.stockQuantity = 0,
    this.advancePaymentAmount,
  });

  // Verifica si el producto tiene stock disponible para entrega inmediata
  bool get isInStock => stockQuantity > 0;

  // Convierte un documento de Firestore en un objeto Product
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      categoryId: data['categoryId'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
      stockQuantity: data['stockQuantity'] ?? 0,
      advancePaymentAmount: (data['advancePaymentAmount'] as num?)?.toDouble(),
    );
  }
}

// Modelo para los usuarios de la aplicación
// Incluye tanto clientes como administradores
class AppUser {
  final String uid; // ID único de Firebase Auth
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? shippingAddress; // Dirección de entrega
  final String? phoneNumber;
  final String role; // 'client' o 'admin'
  final String? fcmToken; // Token para notificaciones push

  AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.shippingAddress,
    this.phoneNumber,
    this.role = 'client',
    this.fcmToken,
  });

  // Convierte un documento de Firestore en un objeto AppUser
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'],
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      shippingAddress: data['shippingAddress'],
      phoneNumber: data['phoneNumber'],
      role: data['role'] ?? 'client',
      fcmToken: data['fcmToken'],
    );
  }
}

// Representa un producto individual dentro de un pedido
// Guarda la información del momento de la compra (precio puede cambiar después)
class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  // Convierte el item a Map para guardarlo en Firestore
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
    };
  }

  // Crea un OrderItem desde un Map de Firestore
  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity']?.toInt() ?? 0,
      price: map['price']?.toDouble() ?? 0.0,
    );
  }
}

// Modelo para un pedido completo
// Incluye seguimiento de estado, fechas de fabricación y entrega
class Order {
  final String id;
  final String userId; // Cliente que hizo el pedido
  final List<OrderItem> items; // Productos del pedido
  final double totalPrice;
  final DateTime orderDate; // Fecha en que se creó el pedido
  final String
      status; // Estado actual (pending, confirmed, in_production, etc.)
  final String shippingAddress; // Dirección de entrega
  final int? estimatedDays; // Días estimados de fabricación
  final DateTime? manufacturingStartDate; // Cuándo se empezó a fabricar
  final DateTime? scheduledDeliveryDate; // Fecha programada de entrega

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalPrice,
    required this.orderDate,
    required this.status,
    required this.shippingAddress,
    this.estimatedDays,
    this.manufacturingStartDate,
    this.scheduledDeliveryDate,
  });

  // Convierte un documento de Firestore en un objeto Order
  factory Order.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      userId: data['userId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
      orderDate: (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      shippingAddress: data['shippingAddress'] ?? 'No especificada',
      estimatedDays: data['estimatedDays'],
      manufacturingStartDate:
          (data['manufacturingStartDate'] as Timestamp?)?.toDate(),
      scheduledDeliveryDate:
          (data['scheduledDeliveryDate'] as Timestamp?)?.toDate(),
    );
  }

  // Retorna el color apropiado según el estado del pedido
  // Útil para mostrar chips de estado con colores consistentes
  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'scheduled':
        return Colors.cyan;
      case 'in_production':
        return Colors.purple;
      case 'ready_for_delivery':
        return Colors.pink;
      case 'delivery_scheduled':
        return Colors.lightGreen;
      case 'shipped':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Retorna el texto en español del estado del pedido
  // Para mostrar al usuario en lugar del código interno
  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmado';
      case 'scheduled':
        return 'Programado Fab.';
      case 'in_production':
        return 'En Producción';
      case 'ready_for_delivery':
        return 'Listo para Entrega';
      case 'delivery_scheduled':
        return 'Entrega Programada';
      case 'shipped':
        return 'Enviado';
      case 'delivered':
        return 'Entregado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }
}
