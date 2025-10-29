import 'package:app_muebles/widgets/product_search_delegate.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/firestore_models.dart';
import '../providers/cart_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';
import 'profile_screen.dart';
import '../models/firestore_models.dart' as models;

// Pantalla principal para clientes/compradores
// Muestra el catálogo de productos con filtros y acceso al carrito
class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  // Guardo las categorías seleccionadas para filtrar los productos que se muestran
  List<String> _selectedCategoryIds = [];

  late final FirestoreService _firestoreService;
  late final AuthService _authService;
  late final String _userId;

  final _currencyFormatter = NumberFormat.currency(
    locale: 'es_PY',
    symbol: 'Gs',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _authService = context.read<AuthService>();
    _userId = _authService.currentUser!.uid;
  }

  // Abre el panel deslizante desde abajo donde el cliente puede seleccionar
  // múltiples categorías para filtrar los productos del catálogo
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StreamBuilder<List<Category>>(
          stream: _firestoreService.getCategories(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final categories = snapshot.data!;
            final tempSelectedIds = List<String>.from(_selectedCategoryIds);

            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
                return FractionallySizedBox(
                  heightFactor: 0.6,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Filtrar por Categoría',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final isSelected = tempSelectedIds.contains(
                                category.id,
                              );

                              return CheckboxListTile(
                                title: Text(category.name),
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      tempSelectedIds.add(category.id);
                                    } else {
                                      tempSelectedIds.remove(category.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            TextButton(
                              child: const Text('Limpiar'),
                              onPressed: () {
                                setDialogState(() {
                                  tempSelectedIds.clear();
                                });
                              },
                            ),
                            const Spacer(),
                            ElevatedButton(
                              child: const Text('Aplicar'),
                              onPressed: () {
                                setState(() {
                                  _selectedCategoryIds = tempSelectedIds;
                                });
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Abre WhatsApp con un mensaje predefinido para cotizar pedidos personalizados
  // El cliente puede solicitar muebles que no están en el catálogo
  Future<void> _launchWhatsApp() async {
    const String phoneNumber = '+595985996792';
    const String message = 'Hola, me gustaría cotizar un pedido personalizado.';

    final String encodedMessage = Uri.encodeComponent(message);

    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$phoneNumber?text=$encodedMessage',
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(
          whatsappUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir WhatsApp. ¿Está instalado?'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al intentar abrir WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('San Francisco Muebles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ProductSearchDelegate(
                  firestoreService: _firestoreService,
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _selectedCategoryIds.isEmpty
                  ? Icons.filter_list_outlined
                  : Icons.filter_list,
            ),
            tooltip: 'Filtrar',
            onPressed: _showFilterBottomSheet,
          ),
          IconButton(
            icon: Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
                return Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode);
              },
            ),
            onPressed: () {
              context.read<ThemeProvider>().toggleTheme();
            },
          ),
          StreamBuilder<List<models.Order>>(
            stream: _firestoreService.getOrdersForUser(_userId),
            builder: (context, orderSnapshot) {
              bool hasReadyOrders = false;
              if (orderSnapshot.hasData) {
                hasReadyOrders = orderSnapshot.data!.any(
                  (order) => order.status == 'ready_for_delivery',
                );
              }
              return Badge(
                isLabelVisible: hasReadyOrders,
                label: const Text(
                  '!',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.account_circle_outlined),
                  tooltip: 'Mi Perfil',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
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
      body: Column(
        children: [
          _buildCategoryFilters(),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _selectedCategoryIds.isEmpty
                  ? _firestoreService.getProducts()
                  : _firestoreService.getProductsByCategories(
                      _selectedCategoryIds,
                    ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No hay productos disponibles.'),
                  );
                }

                final products = snapshot.data!;
                // Separo los productos en dos categorías: los que hay en stock para entrega
                // inmediata y los que se fabrican por pedido
                final inStockProducts =
                    products.where((p) => p.stockQuantity > 0).toList();
                final madeToOrderProducts =
                    products.where((p) => p.stockQuantity <= 0).toList();

                if (inStockProducts.isEmpty &&
                    madeToOrderProducts.isEmpty &&
                    _selectedCategoryIds.isNotEmpty) {
                  return const Center(
                    child: Text(
                      'No hay productos para los filtros seleccionados.',
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(12.0),
                  children: [
                    _buildInStockSection(context, inStockProducts),
                    _buildMadeToOrderSection(context, madeToOrderProducts),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // Botón flotante para que el cliente pueda contactarme por WhatsApp
      // cuando quiere algo que no está en el catálogo
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _launchWhatsApp,
        icon: const Icon(Icons.chat),
        label: const Text('Pedido Personalizado'),
      ),
    );
  }

  // Sección de productos con stock disponible - aparecen primero porque
  // pueden entregarse inmediatamente sin esperar fabricación
  Widget _buildInStockSection(BuildContext context, List<Product> products) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🔥 Entrega Inmediata',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 160,
                child: _buildProductCard(context, product),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Sección de productos que se fabrican por pedido - no tienen stock
  // pero el cliente puede solicitarlos con un anticipo del 50%
  Widget _buildMadeToOrderSection(
    BuildContext context,
    List<Product> products,
  ) {
    if (products.isEmpty && _selectedCategoryIds.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Text('No hay productos "Por Pedido" para estos filtros.'),
        ),
      );
    }

    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Muebles por Pedido',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
        ),
      ],
    );
  }

  // Barra horizontal con chips de categorías para filtrar rápidamente
  // Incluye un chip "Todos" para quitar cualquier filtro aplicado
  Widget _buildCategoryFilters() {
    return StreamBuilder<List<Category>>(
      stream: _firestoreService.getCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final categories = snapshot.data!;

        return Container(
          height: 50,
          color: Theme.of(context).cardColor,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final bool isSelected = _selectedCategoryIds.isEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategoryIds.clear();
                      });
                    },
                  ),
                );
              }

              final category = categories[index - 1];
              final bool isSelected = _selectedCategoryIds.contains(
                category.id,
              );

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(category.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategoryIds.add(category.id);
                      } else {
                        _selectedCategoryIds.remove(category.id);
                      }
                    });
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Tarjeta individual de producto con imagen, nombre, precio y botón de carrito
  // Al tocar la tarjeta se abre el detalle completo del producto
  Widget _buildProductCard(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(right: 8.0, bottom: 4.0, top: 4.0),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: product.imageUrls.isNotEmpty
                  ? Image.network(
                      product.imageUrls.first,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        return progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.error, color: Colors.red);
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
            ),
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
                  Text(_currencyFormatter.format(product.price)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.add_shopping_cart,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        final errorMessage =
                            context.read<CartProvider>().addItem(product);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              errorMessage ??
                                  '${product.name} añadido al carrito.',
                            ),
                            backgroundColor:
                                errorMessage != null ? Colors.red : null,
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
