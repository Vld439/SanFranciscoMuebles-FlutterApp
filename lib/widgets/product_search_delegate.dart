import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/firestore_models.dart';
import '../providers/cart_provider.dart';
import '../services/firestore_service.dart';
import '../screens/product_detail_screen.dart';

// Permite buscar productos por nombre
class ProductSearchDelegate extends SearchDelegate<Product?> {
  final FirestoreService firestoreService;

  ProductSearchDelegate({required this.firestoreService});

  // Formateador de moneda para mostrar precios en Gs (Paraguay)
  final currencyFormatter = NumberFormat.currency(
    locale: 'es_PY',
    symbol: 'Gs',
    decimalDigits: 0,
  );

  @override
  String get searchFieldLabel => 'Buscar muebles...'; // Texto en la barra de búsqueda

  @override
  List<Widget>? buildActions(BuildContext context) {
    // Botón para limpiar la búsqueda
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = ''; 
          showSuggestions(context); // refresca las sugerencias
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    // Botón para salir de la búsqueda (flecha hacia atrás)
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Resultados finales al confirmar la búsqueda (Enter)
    if (query.isEmpty) {
      return const Center(child: Text('Escribe algo para buscar.'));
    }

    // StreamBuilder que escucha los resultados filtrados por `searchProducts`
    return StreamBuilder<List<Product>>(
      stream: firestoreService.searchProducts(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('No se encontraron productos para "$query".'),
          );
        }

        final products = snapshot.data!; // lista de productos encontrados

        // Muestra los resultados en tarjetas (como en la vista principal)
        return GridView.builder(
          padding: const EdgeInsets.all(12.0),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 12.0,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(context, product);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Sugerencias en tiempo real mientras el usuario escribe
    if (query.isEmpty) {
      return const Center(child: Text('Busca por nombre de producto.')); // muestra mensaje en pantalla cuando no hay texto
    }

    // Reutilizamos el mismo stream de búsqueda para obtener sugerencias
    return StreamBuilder<List<Product>>(
      stream: firestoreService.searchProducts(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('No se encontraron productos para "$query".'),
          );
        }

        final suggestions = snapshot.data!;

        // Lista  para las sugerencias (imagen, nombre y precio)
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final product = suggestions[index];
            return ListTile(
              leading: product.imageUrls.isNotEmpty
                  ? Image.network(
                      product.imageUrls.first,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.image_not_supported),
              title: Text(product.name),
              subtitle: Text(currencyFormatter.format(product.price)),
              onTap: () {
                // Al pulsar una sugerencia abrimos la pantalla de detalle
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(product: product),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Widget auxiliar para no repetir código en buildResults
  Widget _buildProductCard(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product), // abre detalle del producto
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias, // recorta bordes de la tarjeta
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen principal 
            Expanded(
              child: product.imageUrls.isNotEmpty
                  ? Image.network(product.imageUrls.first, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
            ),
            // Nombre, precio y botón para añadir al carrito
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(currencyFormatter.format(product.price)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(
                        Icons.add_shopping_cart,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        // Añade el producto al carrito (provider) y muestra SnackBar
                        context.read<CartProvider>().addItem(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${product.name} añadido al carrito.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
