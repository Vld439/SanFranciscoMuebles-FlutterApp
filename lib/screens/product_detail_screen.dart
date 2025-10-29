import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../models/firestore_models.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';
import 'full_screen_image_viewer.dart';

// Pantalla de detalle de un producto
// Muestra imágenes, descripción, precio y permite agregar al carrito
class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_PY',
      symbol: 'Gs',
      decimalDigits: 0,
    );
    // Controlador del carrusel de imágenes (para indicadores y navegación)
    final pageController = PageController();

    // Calcula el adelanto efectivo según el stock
    // Si hay stock disponible, no se requiere adelanto
    double getEffectiveAdvance(Product product) {
      return product.stockQuantity > 0
          ? 0
          : (product.advancePaymentAmount ?? 0);
    }

    // Observamos el carrito para actualizar la disponibilidad del botón
    final cart = context.watch<CartProvider>();

    // Calculamos cuántos de este producto ya están en el carrito
    final int itemsInCart = cart.items[product.id]?.quantity ?? 0;

    // Habilito el botón de compra cuando:
    // - Es "por pedido" (no depende de stock), o
    // - Hay stock y la cantidad en el carrito aún no supera el disponible
    final bool isStockAvailable =
        !product.isInStock || (itemsInCart < product.stockQuantity);

    // Texto dinámico del botón según el tipo de producto
    final String buttonText =
        product.isInStock ? 'Añadir al Carrito' : 'Encargar (Por Pedido)';

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          // Ícono del carrito con badge que muestra la cantidad
          Consumer<CartProvider>(
            builder: (_, cart, ch) => Badge(
              label: Text(cart.itemCount.toString()),
              isLabelVisible: cart.itemCount > 0,
              child: IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carrusel de imágenes con posibilidad de ver a pantalla completa
            if (product.imageUrls.isNotEmpty)
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: product.imageUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // Abre la imagen en pantalla completa al tocar
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenImageViewer(
                                  imageUrls: product.imageUrls,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            product.imageUrls[index],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                    ? child
                                    : const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                            errorBuilder: (context, error, stack) =>
                                const Icon(Icons.error),
                          ),
                        );
                      },
                    ),
                  ),
                  // Indicadores de página (puntos) para navegar entre imágenes
                  if (product.imageUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SmoothPageIndicator(
                        controller: pageController,
                        count: product.imageUrls.length,
                        effect: WormEffect(
                          dotHeight: 8.0,
                          dotWidth: 8.0,
                          activeDotColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              )
            else
              // Si no hay imágenes, mostramos un placeholder
              Container(
                height: 300,
                color: Colors.grey[200],
                child: const Icon(
                  Icons.image_not_supported,
                  color: Colors.grey,
                  size: 100,
                ),
              ),

            // Información del producto
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormatter.format(product.price),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Muestra el adelanto solo si el producto lo requiere
                  if (getEffectiveAdvance(product) > 0)
                    Row(
                      children: [
                        Text(
                          'Adelanto requerido: ',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currencyFormatter
                              .format(getEffectiveAdvance(product)),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Descripción',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(product.description),
                  const SizedBox(height: 16),

                  // Chip de disponibilidad (En Stock o Por Pedido)
                  Chip(
                    label: Text(
                      product.isInStock
                          ? 'En Stock (${product.stockQuantity} disponibles)'
                          : 'Fabricación por Pedido',
                    ),
                    backgroundColor: product.isInStock
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceVariant,
                    labelStyle: TextStyle(
                      color: product.isInStock
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Botón fijo inferior para agregar al carrito
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            textStyle: const TextStyle(fontSize: 18),
            disabledBackgroundColor: Colors.grey[300],
          ),
          // Se deshabilita si no hay stock disponible
          onPressed: isStockAvailable
              ? () {
                  final errorMessage =
                      context.read<CartProvider>().addItem(product);

                  // Mostramos mensaje de éxito o error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        errorMessage ?? '${product.name} añadido al carrito.',
                      ),
                      backgroundColor: errorMessage != null ? Colors.red : null,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              : null, // null deshabilita el botón automáticamente
        ),
      ),
    );
  }
}
