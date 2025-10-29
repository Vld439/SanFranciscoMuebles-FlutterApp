import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/firestore_models.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

// Pantalla para editar un producto existente
// Permite modificar nombre, precio, stock, categoría e imágenes
class EditProductScreen extends StatefulWidget {
  final Product product; // Producto a editar
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos del formulario
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _advanceController;

  // Estado del formulario
  String? _selectedCategoryId; // Categoría seleccionada
  List<Category> _categories = []; // Lista de categorías disponibles
  List<String> _existingImageUrls = []; // Imágenes actuales del producto
  final List<XFile> _newImages = []; // Nuevas imágenes para agregar
  final List<String> _urlsToDelete = []; // Imágenes marcadas para eliminar
  bool _isLoading = false; // Indicador de carga

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Inicializamos los controladores con los datos actuales del producto
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(
      text: widget.product.description,
    );
    _priceController = TextEditingController(
      text: widget.product.price.toStringAsFixed(0),
    );
    _stockController = TextEditingController(
      text: widget.product.stockQuantity.toString(),
    );
    _advanceController = TextEditingController(
      text: widget.product.advancePaymentAmount?.toStringAsFixed(0) ?? '',
    ); // Muestra vacío si es null
    _selectedCategoryId = widget.product.categoryId;
    // Crea una copia modificable de las URLs existentes.
    _existingImageUrls = List.from(widget.product.imageUrls);
  }

  @override
  void dispose() {
    // Libera los recursos de los controladores cuando el widget se destruye.
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  // Abre el selector para que el usuario elija múltiples imágenes.
  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();
      // Añade las imágenes seleccionadas a la lista de nuevas imágenes.
      setState(() {
        _newImages.addAll(pickedFiles);
      });
    } catch (e) {
      // Maneja errores si ocurren durante la selección.
      if (mounted) {
        // Verifica si el widget todavía está en el árbol.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imágenes: $e')),
        );
      }
    }
  }

  // Guarda los cambios realizados en el producto.
  Future<void> _saveProduct() async {
    // Valida el formulario y verifica que no esté ya en proceso de guardado.
    if (_formKey.currentState!.validate() && !_isLoading) {
      // Validaciones adicionales: categoría seleccionada y al menos una imagen.
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona una categoría')),
        );
        return;
      }
      if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El producto debe tener al menos una imagen.'),
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      }); // Muestra el indicador de carga.

      // Obtiene los servicios necesarios.
      final firestoreService = context.read<FirestoreService>();
      final storageService = context.read<StorageService>();

      // Prepara listas para manejar las imágenes.
      final List<String> urlsToDeleteOnSuccess = List.from(
        _urlsToDelete,
      ); // Copia para seguridad
      List<String> finalImageUrls = List.from(
        _existingImageUrls,
      ); // Lista final de URLs

      try {
        // 1. Sube las nuevas imágenes (si hay).
        if (_newImages.isNotEmpty) {
          List<String> newUrls = [];
          if (kIsWeb) {
            // Lógica para subir imágenes en la web (usando bytes).
            for (var xFile in _newImages) {
              final bytes = await xFile.readAsBytes();
              final url = await storageService.uploadProductImage(
                bytes,
                widget.product.id,
              );
              newUrls.add(url);
            }
          } else {
            // Lógica para subir imágenes en móvil (usando File).
            final filesToUpload =
                _newImages.map((file) => File(file.path)).toList();
            newUrls = await storageService.uploadProductImages(
              widget.product.id,
              filesToUpload,
            );
          }
          finalImageUrls.addAll(
            newUrls,
          ); // Añade las URLs nuevas a la lista final.
        }

        // 2. Actualiza el documento del producto en Firestore.
        await firestoreService.updateProduct(widget.product.id, {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'price': double.tryParse(_priceController.text) ??
              0.0, // Convierte a double
          'categoryId': _selectedCategoryId!,
          'imageUrls': finalImageUrls, // Guarda la lista final de URLs
          'stockQuantity':
              int.tryParse(_stockController.text) ?? 0, // Convierte a int
          'advancePaymentAmount': double.tryParse(
            _advanceController.text,
          ), // Convierte a double o guarda null
        });

        // 3. Si la actualización en Firestore fue exitosa, elimina las imágenes marcadas de Storage.
        //    Se hace sin 'await' para no bloquear la UI.
        for (String urlToDelete in urlsToDeleteOnSuccess) {
          storageService.deleteImageByUrl(urlToDelete).catchError((e) {
            // Opcional: Registrar este error si la eliminación en segundo plano falla.
            print("Error eliminando imagen $urlToDelete de Storage: $e");
          });
        }

        // Si el widget aún está montado, muestra mensaje de éxito y vuelve atrás.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto actualizado con éxito')),
          );
          Navigator.of(
            context,
          ).pop(); // Vuelve a la pantalla anterior (lista de productos).
        }
      } catch (e) {
        // Si ocurre un error durante el proceso.
        if (mounted) {
          setState(() {
            _isLoading = false;
          }); // Oculta el indicador de carga.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar: $e'),
            ), // Muestra mensaje de error.
          );
        }
      }
    }
  }

  // Muestra un diálogo de confirmación y elimina el producto si se confirma.
  Future<void> _deleteProduct() async {
    // Muestra el diálogo y espera la respuesta (true si confirma, false si cancela).
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este producto? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    // Si el usuario confirmó la eliminación.
    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      }); // Muestra indicador de carga.
      try {
        // Obtiene el servicio (mejor dentro del bloque try-catch por si acaso).
        final firestoreService = context.read<FirestoreService>();
        // Llama al método para eliminar el producto (que también elimina imágenes).
        await firestoreService.deleteProduct(widget.product.id);
        // Si el widget aún está montado, muestra mensaje y vuelve a la pantalla principal.
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Producto eliminado')));
          // Vuelve atrás hasta la primera pantalla de la pila (la pantalla principal del admin).
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        // Si ocurre un error durante la eliminación.
        if (mounted) {
          setState(() {
            _isLoading = false;
          }); // Oculta indicador de carga.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
            ), // Muestra mensaje de error.
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtiene el servicio de Firestore para el dropdown de categorías.
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Producto'),
        actions: [
          // Botón para eliminar el producto.
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteProduct,
            tooltip: 'Eliminar Producto',
          ),
          // Botón para guardar los cambios.
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProduct,
            tooltip: 'Guardar Cambios',
          ),
        ],
      ),
      // Muestra un indicador de carga o el formulario.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey, // Asocia la clave global al formulario.
              child: SingleChildScrollView(
                // Permite hacer scroll si el contenido es largo.
                padding: const EdgeInsets.all(
                  16.0,
                ), // Espaciado alrededor del formulario.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment
                      .stretch, // Expande los widgets horizontalmente.
                  children: [
                    //  Campos del Formulario
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => v!.isEmpty
                          ? 'Campo requerido'
                          : null, // Validación básica.
                    ),
                    const SizedBox(height: 16), // Espacio vertical.
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                      maxLines: 4, // Permite escribir varias líneas.
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
                      ), // Teclado numérico sin decimales.
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ], // Permite solo dígitos.
                      validator: (v) {
                        // Validación para el precio.
                        if (v!.isEmpty) return 'Campo requerido';
                        if (double.tryParse(v) == null) {
                          return 'Ingrese un número válido';
                        }
                        return null; // Válido.
                      },
                    ),
                    const SizedBox(height: 16),
                    // Campo para el Adelanto Requerido.
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
                        // Validación opcional para el adelanto.
                        if (v != null &&
                            v.isNotEmpty &&
                            double.tryParse(v) == null) {
                          return 'Ingrese un número válido o déjelo vacío';
                        }
                        return null; // Válido si está vacío o es número.
                      },
                    ),
                    const SizedBox(height: 16),
                    // Campo para la Cantidad en Stock.
                    TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Stock (Entrega Inmediata)',
                        hintText: '0 si es por pedido',
                      ),
                      keyboardType: TextInputType.number, // Teclado numérico.
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        // Validación para el stock.
                        if (v!.isEmpty) return 'Campo requerido (puede ser 0)';
                        if (int.tryParse(v) == null) {
                          return 'Ingrese un número entero válido';
                        }
                        return null; // Válido.
                      },
                    ),
                    const SizedBox(height: 16),
                    // Dropdown para seleccionar la Categoría.
                    StreamBuilder<List<Category>>(
                      stream: firestoreService
                          .getCategories(), // Obtiene las categorías.
                      builder: (context, snapshot) {
                        // Muestra indicador de carga mientras espera las categorías.
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        _categories =
                            snapshot.data!; // Guarda las categorías obtenidas.
                        // Verifica si la categoría seleccionada previamente sigue existiendo.
                        if (_selectedCategoryId != null &&
                            !_categories.any(
                              (cat) => cat.id == _selectedCategoryId,
                            )) {
                          _selectedCategoryId =
                              null; // La resetea si fue eliminada.
                        }
                        // Construye el Dropdown.
                        return DropdownButtonFormField<String>(
                          value:
                              _selectedCategoryId, // Valor seleccionado actualmente.
                          hint: const Text(
                            'Seleccionar Categoría',
                          ), // Texto si no hay nada seleccionado.
                          items: _categories.map((category) {
                            // Crea un item por cada categoría.
                            return DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            // Actualiza el estado cuando se selecciona una categoría.
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                          validator: (v) => v == null
                              ? 'Campo requerido'
                              : null, // La categoría es obligatoria.
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Botón para añadir nuevas imágenes.
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Añadir Nuevas Imágenes'),
                      onPressed:
                          _pickImages, // Llama a la función para seleccionar imágenes.
                    ),
                    // Muestra la previsualización de imágenes existentes y nuevas.
                    _buildImagePreview(),
                    const SizedBox(
                      height: 32,
                    ), // Espacio antes del botón final.
                    // Botón principal para guardar los cambios.
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Cambios'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ), // Botón más alto.
                      ),
                      onPressed:
                          _saveProduct, // Llama a la función para guardar.
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget que construye la lista horizontal de previsualización de imágenes.
  Widget _buildImagePreview() {
    // Si no hay imágenes existentes ni nuevas, no muestra nada.
    if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
      return const SizedBox.shrink(); // Widget vacío.
    }

    // Contenedor con altura fija para la lista horizontal.
    return Container(
      height: 100,
      margin: const EdgeInsets.only(top: 16), // Espacio superior.
      child: ListView.builder(
        scrollDirection: Axis.horizontal, // Desplazamiento horizontal.
        // Número total de imágenes a mostrar.
        itemCount: _existingImageUrls.length + _newImages.length,
        itemBuilder: (context, index) {
          // Construye cada imagen en la lista.
          Widget imageWidget;
          // Determina si es una imagen existente (URL) o nueva (XFile).
          bool isExistingImage = index < _existingImageUrls.length;

          if (isExistingImage) {
            // Muestra imagen existente desde la red.
            final imageUrl = _existingImageUrls[index];
            imageWidget = Image.network(
              imageUrl,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            );
          } else {
            // Muestra imagen nueva (desde archivo local o blob web).
            final newImageIndex = index - _existingImageUrls.length;
            final imagePath = _newImages[newImageIndex].path;
            // Usa Image.network para web, Image.file para móvil.
            imageWidget = kIsWeb
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
                  );
          }

          // Añade espaciado a la derecha de cada imagen.
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            // Stack permite superponer el botón 'x'.
            child: Stack(
              children: [
                imageWidget, // La imagen.
                // Botón 'x' para quitar la imagen de la previsualización.
                Positioned(
                  top: 0,
                  right: 0,
                  child: CircleAvatar(
                    // Fondo circular semitransparente.
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      padding: EdgeInsets.zero, // Sin padding interno.
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 12,
                      ), // Icono 'x'.
                      tooltip: isExistingImage
                          ? 'Quitar imagen (se eliminará al guardar)'
                          : 'Quitar imagen nueva', // Texto de ayuda.
                      onPressed: () {
                        // Actualiza el estado al quitar una imagen.
                        setState(() {
                          if (isExistingImage) {
                            // Si es existente, la mueve a la lista '_urlsToDelete'.
                            _urlsToDelete.add(
                              _existingImageUrls.removeAt(index),
                            );
                          } else {
                            // Si es nueva, simplemente la quita de '_newImages'.
                            _newImages.removeAt(
                              index - _existingImageUrls.length,
                            );
                          }
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
