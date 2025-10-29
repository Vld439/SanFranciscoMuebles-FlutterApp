import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/firestore_models.dart';
import '../services/firestore_service.dart';

// Pantalla para gestionar categorías
class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    // Muestra un diálogo para crear o editar una categoría, si se pasa una `Category`, el diálogo actúa como edición, sino crea una nueva
    void showCategoryDialog({Category? category}) {
      final isEditing = category != null;
      final TextEditingController categoryController = TextEditingController(
        text: isEditing ? category.name : '', // carga el nombre si estamos editando
      );

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              isEditing ? 'Editar Categoría' : 'Añadir Nueva Categoría',
            ),
            content: TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                hintText: "Nombre de la categoría",
              ),
              autofocus: true,
            ),
            actions: [
              // Botón cancelar cierra el diálogo
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              // Guardar: crea o actualiza según el modo
              ElevatedButton(
                child: Text(isEditing ? 'Guardar' : 'Añadir'),
                onPressed: () {
                  if (categoryController.text.isNotEmpty) {
                    if (isEditing) {
                      // Actualiza nombre de categoría existente
                      firestoreService.updateCategory(
                        category.id,
                        categoryController.text,
                      );
                    } else {
                      // Crea nueva categoría
                      firestoreService.addCategory(categoryController.text);
                    }
                    Navigator.of(context).pop(); // cierra el diálogo
                  }
                },
              ),
            ],
          );
        },
      );
    }

    // Diálogo de confirmación para eliminar una categoria.
    void showDeleteDialog(Category category) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
            '¿Estás seguro de que quieres eliminar la categoria "${category.name}"? Los productos asociados no se eliminarán, pero quedarán sin categoria.',
          ),
          actions: [
            // Cancelar: cerrar el diálogo sin cambios
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            // Eliminar: llama al servicio y cierra el diálogo
            ElevatedButton(
              onPressed: () {
                firestoreService.deleteCategory(category.id);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Categorías')),
      // StreamBuilder escucha cambios en la colección `categories` y reconstruye la lista
      body: StreamBuilder<List<Category>>(
        stream: firestoreService.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); // muestra un indicador de carga
          }
          // Si no hay datos, mostramos mensaje informativo
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay categorías creadas.'));
          }

          final categories = snapshot.data!; // lista de categorías recuperadas

          // Construimos la lista desplazable de categorías
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(category.name),
                  // Acciones: editar y eliminar
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => showCategoryDialog(category: category),
                        tooltip: 'Editar',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => showDeleteDialog(category),
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // Botón flotante para añadir una nueva categoría
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCategoryDialog(),
        tooltip: 'Añadir Categoría',
        child: const Icon(Icons.add),
      ),
    );
  }
}
