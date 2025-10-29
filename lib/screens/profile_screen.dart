import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/firestore_models.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'my_orders_screen.dart';
import '../models/firestore_models.dart' as models; // Importa el modelo Order para usarlo en el StreamBuilder

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>(); // clave para validar el formulario
  late TextEditingController _addressController; // controlador para la dirección
  late TextEditingController _phoneController; // controlador para el teléfono
  bool _dataLoaded = false; // asegura que los datos se carguen solo una vez

  // Variables para los services y id del usuario
  late final AuthService _authService;
  late final FirestoreService _firestoreService;
  late final String _userId;

  @override
  void initState() {
    super.initState();
    // Inicializa los controladores
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    // Se obtienen los servicios y el userId
    _authService = context.read<AuthService>();
    _firestoreService = context.read<FirestoreService>();
    _userId = _authService.currentUser!.uid;
  }

// Limpia los controladores, libera recursos
  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Guarda el perfil del usuario
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) { //valida el formulario
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _firestoreService.updateUser(_userId, {// usa _userId
          'shippingAddress': _addressController.text,
          'phoneNumber': _phoneController.text,
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se obtiene el usuario actual
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: StreamBuilder<AppUser?>(
        //Usa el userId para obtener el stream del usuario
        stream: _firestoreService.getUserStream(_userId),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator()); //muestra indicador de carga
          }
          final appUser = userSnapshot.data!; //datos del usuario de Firestore, ! asegura que no es nulo

          if (appUser.role == 'client' && !_dataLoaded) { //si es cliente y no se han cargado los datos aún
            _addressController.text = appUser.shippingAddress ?? '';// carga los datos, si es nulo asigna cadena vacía
            _phoneController.text = appUser.phoneNumber ?? '';
            _dataLoaded = true; //marca que los datos ya se cargaron
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar( //muestra la foto del usuario o un icono por defecto
                    radius: 50,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text( //nombre del usuario o 'Sin Nombre' si es nulo
                    user?.displayName ?? 'Sin Nombre',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Center(child: Text(user?.email ?? 'Sin Email')), //email del usuario o 'Sin Email' si es nulo
                const SizedBox(height: 24),

                if (appUser.role == 'client') //si es cliente
                  _buildClientProfile(context, _userId)
                else                          //si es admin
                  _buildAdminProfile(context),

                const Divider(),

                // Opción para cerrar sesión
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red[700]),
                  title: Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  onTap: () async {
                    await _authService.signOut();
                    if (mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst); //regresa a la pantalla de login
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget de Cliente
  Widget _buildClientProfile(BuildContext context, String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Buscar pedidos listos para entrega
        StreamBuilder<List<models.Order>>(
          // Escucha los pedidos del usuario
          stream: _firestoreService.getOrdersForUser(userId),
          builder: (context, orderSnapshot) {
            bool hasReadyOrders = false;
            if (orderSnapshot.hasData) {
              // Comprueba si algún pedido tiene el estado 'ready_for_delivery'
              hasReadyOrders = orderSnapshot.data!.any(
                (order) => order.status == 'ready_for_delivery',
              );
            }

            // Muestra el ListTile con o sin indicador
            return ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Mis Pedidos'),
              // Indicador si hay pedidos listos
              trailing: Row(
                // Usamos Row para el icono y el indicador
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasReadyOrders) // Muestra un punto rojo si hay pedidos listos
                    Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: const Text(
                        '!', // símbolo que muestra dentro del punto
                        style: TextStyle(color: Colors.white, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (hasReadyOrders) const SizedBox(width: 5), // Espacio
                  const Icon(Icons.chevron_right), // Icono de flecha
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MyOrdersScreen(), //abre la pantalla de mis pedidos 
                  ),
                );
              },
            );
          },
        ),
        const Divider(),
        const SizedBox(height: 16),
        // Formulario
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField( //campo de dirección
                controller: _addressController,
                decoration: const InputDecoration( 
                  labelText: 'Dirección de Envío', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu dirección'; //mensaje si no se ingresa dirección
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField( //campo de teléfono
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Número de Teléfono',
                  hintText: '+595981123456 (ej. de formato admitido)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintStyle: TextStyle(color: CupertinoColors.inactiveGray),
                ),
                keyboardType: TextInputType.phone, //input numérico
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu teléfono';
                  }
                  if (!value.startsWith('+')) {
                    return 'Debe incluir el código de país (ej. +595)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Guardar Cambios'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget de Admin
  Widget _buildAdminProfile(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.admin_panel_settings),
      title: Text('Rol de Administrador'),
      subtitle: Text('Tienes acceso al panel de gestión.'),
    );
  }
}
