import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

// Visor de imágenes a pantalla completa con soporte de zoom y gestos.
class FullScreenImageViewer extends StatelessWidget {
  // Lista de URLs de las imágenes a mostrar
  final List<String> imageUrls;

  // Índice inicial (página) que se mostrará al abrir el visor
  final int initialIndex;

  const FullScreenImageViewer({ // constructor
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Scaffold con AppBar oscuro para que la imagen destaque
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // PhotoViewGallery construye páginas dinámicamente según `imageUrls`
      body: PhotoViewGallery.builder(
        itemCount: imageUrls.length,
        // Controlador de páginas para abrir en `initialIndex`
        pageController: PageController(initialPage: initialIndex),
        builder: (context, index) {
          // Cada entrada configura un PhotoView con la imagen de red
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(imageUrls[index]),
            // Escala inicial para contener la imagen dentro de la pantalla
            initialScale: PhotoViewComputedScale.contained,
            // Hero tag para animaciones cuando se abre desde una miniatura
            heroAttributes: PhotoViewHeroAttributes(tag: imageUrls[index]),
          );
        },
        // scroll con rebote
        scrollPhysics: const BouncingScrollPhysics(),
        // Fondo negro para resaltar las imágenes
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
