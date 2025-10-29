import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:uuid/uuid.dart';

// Servicio para manejar la subida y eliminación de imágenes en Firebase Storage
// Las imágenes se organizan por carpetas de productos
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Sube múltiples imágenes desde archivos File (móvil/desktop)
  // Retorna una lista con las URLs de descarga de cada imagen subida
  Future<List<String>> uploadProductImages(
    String productId,
    List<File> images,
  ) async {
    try {
      List<String> downloadUrls = [];

      // Subimos cada imagen por separado y guardamos su URL
      for (File imageFile in images) {
        // Generamos un nombre único para evitar colisiones
        final String fileName = _uuid.v4();
        final Reference ref = _storage
            .ref()
            .child('products')
            .child(productId)
            .child('$fileName.jpg');

        // putFile es específico para objetos File
        final UploadTask uploadTask = ref.putFile(imageFile);
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        downloadUrls.add(downloadUrl);
      }

      return downloadUrls;
    } catch (e) {
      if (kDebugMode) {
        print('Error al subir múltiples imágenes: $e');
      }
      rethrow;
    }
  }

  // Sube una imagen desde bytes (útil para web)
  // Retorna la URL de descarga de la imagen
  Future<String> uploadProductImage(
    Uint8List imageBytes,
    String productId,
  ) async {
    try {
      final String fileName = _uuid.v4();
      final Reference ref = _storage
          .ref()
          .child('products')
          .child(productId)
          .child('$fileName.jpg');
      final UploadTask uploadTask = ref.putData(imageBytes);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error al subir la imagen: $e');
      }
      rethrow;
    }
  }

  // Elimina una imagen específica usando su URL
  // Útil cuando quieres eliminar solo una imagen del producto
  Future<void> deleteImageByUrl(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error al eliminar imagen por URL: $e');
    }
  }

  // Elimina todas las imágenes de un producto
  // Se usa cuando borras un producto completo
  Future<void> deleteProductImages(String productId) async {
    try {
      final ListResult result =
          await _storage.ref().child('products').child(productId).listAll();
      for (final Reference ref in result.items) {
        await ref.delete();
      }
    } catch (e) {
      print('Error al eliminar imágenes del producto: $e');
    }
  }
}
