import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/firestore_models.dart';
import '../services/firestore_service.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class ProductListView extends StatelessWidget {
  const ProductListView({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el servicio Firestore desde Provider
    final firestoreService = context.read<FirestoreService>();

    // Moneda local (Paraguay, Gs) sin decimales
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_PY',
      symbol: 'Gs',
      decimalDigits: 0,
    );

    return Scaffold(
      // StreamBuilder escucha cambios en la colección `products` y reconstruye la UI
      body: StreamBuilder<List<Product>>(
        stream: firestoreService.getProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); // muestra un indicador de carga
          }
          // Si hay error en el stream, lo mostramos en pantalla
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          // Si no hay productos, indicamos al usuario que añada uno
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay productos. ¡Añade uno!'));
          }

          final products = snapshot.data!; // lista de productos recuperados

          // Tarjetas que muestran miniatura, nombre y precio
          return GridView.builder(
            padding: const EdgeInsets.all(12.0),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12.0,
              mainAxisSpacing: 12.0,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];

              // Al presionar una tarjeta abre la pantalla de edición
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EditProductScreen(product: product),
                    ),
                  );
                },
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen del producto: usa la primera URL si existe
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            image: product.imageUrls.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(
                                      product.imageUrls.first,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.grey[200],
                          ),
                          // Icono si no hay imágenes
                          child: product.imageUrls.isEmpty
                              ? const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ),

                      // Nombre y precio del producto
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              // Formateamos el precio con el formatter local
                              currencyFormatter.format(product.price),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // Botón para añadir un nuevo producto
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddProductScreen()),
          );
        },
        tooltip: 'Añadir Producto',
        child: const Icon(Icons.add),
      ),
    );
  }
}
