import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/firestore_models.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'category_management_screen.dart';
import 'order_management_screen.dart';
import 'product_list_view.dart';
import 'profile_screen.dart';
import '../widgets/product_search_delegate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex =
      0; //guarda indice de la pestaña, 0 = productos, 1 = pedidos

//Lista productos (0) y pedidos (1)
  static const List<Widget> _widgetOptions = <Widget>[
    ProductListView(),
    OrderManagementScreen(),
  ];

//Actualiza el estado al presionar un elemento
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.read<AuthService>(); //accede a AuthService
    final firestoreService = context.read<
        FirestoreService>(); //accede a FirestoreService y guarda en variable local

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0
            ? 'Mis Productos'
            : 'Pedidos'), //cambio de título según índice, 0=Mis productos, 1= Pedidos
        actions: [
          // BOTÓN DE BÚSQUEDA (si _selectIndex es 0)
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip:
                  'Buscar Productos', //texto que aparece al presionar de seguido
              onPressed: () {
                showSearch(
                  //Interfaz de búsqueda de flutter
                  context: context,
                  delegate: ProductSearchDelegate(
                    // clase que maneja la búsqueda, pasa el servicio de Firestore
                    firestoreService: firestoreService,
                  ),
                );
              },
            ),

          IconButton(
            icon: Consumer<ThemeProvider>(
              //widget consumer de provider escucha cambios en theme provider
              builder: (context, themeProvider, child) => Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
            ),
            onPressed: () {
              context
                  .read<ThemeProvider>()
                  .toggleTheme(); //llama a toggleTheme para cambiar estado del tema
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Mi Perfil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) =>
                        const ProfileScreen()), //Abre la pantalla de perfil
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Gestionar Categorías',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const CategoryManagementScreen(), //abre la pantalla de categorías
                ),
              );
            },
          ),
        ],
      ),

      //Cuerpo principal, muestra el widget de la lista widgetOptions seleccionado según el índice
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: StreamBuilder<List<Order>>(
        //barra de navegación inferior
        stream: firestoreService.getOrders(),
        builder: (context, snapshot) {
          //Manejo de todos los estados del snapshot
          if (snapshot.hasError) {
            // En caso de error, muestra la barra de navegación sin notificaciones
            print("Error en el Stream de pedidos: ${snapshot.error}");
            return _buildNavigationBar(0);
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            // Mientras carga, muestra la barra de navegación sin notificaciones
            return _buildNavigationBar(0);
          }

          final orders =
              snapshot.data ?? []; //lista de pedidos, es vacía si es null
          final pendingOrdersCount = orders
              .where((order) =>
                  order.status == 'pending' ||
                  order.status == 'delivery_scheduled')
              .length; //cuenta estados pendientes y programados

          return _buildNavigationBar(
              pendingOrdersCount); //funcion que recibe el numero de pedidos pendientes
        },
      ),
    );
  }

  // Widget auxiliar para construir la barra de navegación
  BottomNavigationBar _buildNavigationBar(int pendingOrdersCount) {
    return BottomNavigationBar(
      items: <BottomNavigationBarItem>[
        const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined), //icono de productos
          activeIcon: Icon(Icons.inventory_2),
          label: 'Productos',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            //muestra notificacion
            label: Text(pendingOrdersCount.toString()),
            isLabelVisible: pendingOrdersCount > 0,
            child: const Icon(Icons.receipt_long_outlined), //icono de pedidos
          ),
          activeIcon: Badge(
            label: Text(pendingOrdersCount.toString()),
            isLabelVisible: pendingOrdersCount > 0,
            child: const Icon(Icons.receipt_long),
          ),
          label: 'Pedidos',
        ),
      ],
      currentIndex: _selectedIndex, //elemento de la barra seleccionado
      onTap: _onItemTapped,
    );
  }
}
