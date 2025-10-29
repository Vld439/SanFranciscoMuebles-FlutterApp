import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/firestore_models.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Pantalla para añadir un nuevo producto al catálogo
// Solo accesible por administradores
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  // Clave global para validar el formulario antes de guardar
  final _formKey = GlobalKey<FormState>();

  // Controladores para cada campo del formulario
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '0'); // 0 = por pedido
  final _advanceController = TextEditingController(); // Adelanto opcional

  String? _selectedCategoryId; // Categoría seleccionada del dropdown
  List<Category> _categories = []; // Lista de categorías disponibles
  final List<XFile> _images = []; // Imágenes seleccionadas por el usuario
  bool _isLoading = false; // Muestra indicador de carga durante el guardado

  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    // Liberamos recursos cuando la pantalla se cierra
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  // Abre el selector de imágenes del dispositivo
  // Permite seleccionar múltiples imágenes a la vez
  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();
    setState(() {
      _images.addAll(pickedFiles);
    });
  }

  // Guarda el producto en Firestore y sube las imágenes a Storage
  // Proceso: 1) Crear producto sin imágenes, 2) Subir imágenes, 3) Actualizar con URLs
  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate() && !_isLoading) {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona una categoría')),
        );
        return;
      }
      if (_images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, añade al menos una imagen')),
        );
        return;
      }

      setState(() {
        _isLoading = true; // Mostramos el indicador de carga
      });

      final firestoreService = context.read<FirestoreService>();
      final storageService = context.read<StorageService>();

      try {
        // Paso 1: Creamos el producto sin imágenes para obtener su ID
        final product = Product(
          id: '',
          name: _nameController.text,
          description: _descriptionController.text,
          price: double.tryParse(_priceController.text) ?? 0.0,
          categoryId: _selectedCategoryId!,
          imageUrls: [],
          stockQuantity: int.tryParse(_stockController.text) ?? 0,
          advancePaymentAmount: double.tryParse(
            _advanceController.text,
          ),
        );

        // 1. Crear el producto sin imágenes primero
        final productId = await firestoreService.addProduct(product);

        // 2. Subir las imágenes al Storage y obtener sus URLs
        List<String> imageUrls = [];
        if (kIsWeb) {
          // En web usamos bytes
          for (var xFile in _images) {
            final bytes = await xFile.readAsBytes();
            final url = await storageService.uploadProductImage(
              bytes,
              productId,
            );
            imageUrls.add(url);
          }
        } else {
          // En móvil/desktop usamos archivos File
          final filesToUpload = _images.map((file) => File(file.path)).toList();
          imageUrls = await storageService.uploadProductImages(
            productId,
            filesToUpload,
          );
        }

        // 3. Actualizamos el producto con las URLs de las imágenes
        await firestoreService.updateProduct(productId, {
          'imageUrls': imageUrls,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto añadido con éxito')),
          );
          Navigator.of(context).pop(); // Volvemos a la pantalla anterior
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Producto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProduct,
            tooltip: 'Guardar Producto',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                      maxLines: 4,
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio (Gs)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v!.isEmpty) return 'Campo requerido';
                        if (double.tryParse(v) == null) {
                          return 'Ingrese un número válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _advanceController,
                      decoration: const InputDecoration(
                        labelText: 'Adelanto Requerido (Gs)',
                        hintText: 'Opcional, 0 o vacío si no aplica',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v != null &&
                            v.isNotEmpty &&
                            double.tryParse(v) == null) {
                          return 'Ingrese un número válido o déjelo vacío';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Stock (Entrega Inmediata)',
                        hintText: '0 si es por pedido',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v!.isEmpty) return 'Campo requerido (puede ser 0)';
                        if (int.tryParse(v) == null) {
                          return 'Ingrese un número entero válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // StreamBuilder para cargar las categorías en tiempo real
                    StreamBuilder<List<Category>>(
                      stream: firestoreService.getCategories(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        _categories = snapshot.data!;
                        return DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          hint: const Text('Seleccionar Categoría'),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                          validator: (v) =>
                              v == null ? 'Campo requerido' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Añadir Imágenes'),
                      onPressed: _pickImages,
                    ),
                    _buildImagePreview(), // Vista previa de las imágenes seleccionadas
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Producto'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saveProduct,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Construye la vista previa de las imágenes seleccionadas
  // Muestra una lista horizontal con opción de eliminar cada imagen
  Widget _buildImagePreview() {
    if (_images.isEmpty) {
      return const SizedBox.shrink(); // No muestra nada si no hay imágenes
    }
    return Container(
      height: 100,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final imagePath = _images[index].path;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              // Stack para poner el botón de eliminar encima de la imagen
              children: [
                // Muestra la imagen según la plataforma (web o móvil)
                kIsWeb
                    ? Image.network(
                        imagePath,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(imagePath),
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                // Botón para eliminar la imagen
                Positioned(
                  top: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 12,
                      ),
                      onPressed: () {
                        setState(() {
                          _images.removeAt(index);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
