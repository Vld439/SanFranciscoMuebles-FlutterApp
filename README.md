# San Francisco Muebles Flutter-App

**Proyecto:** App móvil Flutter para venta de muebles y artículos de madera.  
**Autores:** Veronica Galeano, Vladimir De Andrade.

-----

## Descripción
App móvil construida en **Flutter** que permite navegar por categorías de productos, ver detalles, agregar al carrito, gestionar órdenes y perfil de usuario. El backend está implementado usando **Firebase** (Auth, Firestore, Storage) y existen servicios en `lib/services` para encapsular la lógica de acceso a Firebase.

-----

## Setup 
1. Instalar Flutter (SDK). Ver guía oficial. (https://docs.flutter.dev/install/with-vs-code)
2. Activar modo desarrollador, en Windows es: Configración/Actualización y seguridad/Para programadores/Modo para desarrolladores.
2. Descomprimir el archivo "app_muebles.rar"
3. Instalar dependencias en la terminal de la carpeta raíz del proyecto:
```
   flutter pub get
```
5. Ejecutar la aplicación:
```
   flutter run
```

-----

## Dependencias principales 
- `firebase_core` — inicialización de Firebase. 
- `firebase_auth` — autenticación de usuarios (email/password, Google Sign-In).  
- `cloud_firestore` — base de datos NoSQL para productos, pedidos, usuarios. 
- `firebase_storage` — almacenamiento de imágenes de productos.  
- `google_sign_in` — login con Google.  
- `provider` — gestión de estado simple. 
- `image_picker`, `photo_view`, `smooth_page_indicator`, `intl`, `google_fonts`, `url_launcher`, `uuid`, `cupertino_icons` — utilidades para UI y experiencia.

**Decisiones para uso de paquetes**
- Firebase (Auth, Firestore, Storage): permite construir un backend completo y escalable rápidamente sin desarrollar un servidor propio, permite reducir tiempo de desarrollo.
- Provider: usada para gestionar estado en apps Flutter pequeñas/medianas; permite mantener la UI reactiva.   
- `image_picker` / `photo_view`: necesarios para subir y mostrar imágenes de productos sin desarrollar componentes nativos desde cero.

-----

## Arquitectura
- **UI (screens/widgets)** — pantallas en `lib/screens/` y componentes en `lib/widgets/`.
- **Providers** — `lib/providers` (`CartProvider` para estado de sesión y carrito, `theme_provider` para manejo de tema claro y oscuro). MultiProvider en main.dart para otros proveedores.
- **Services** — `lib/services/*` encapsula llamadas a Firebase (`auth_service.dart`, `firestore_service.dart`, `storage_service.dart`).
- **Models** — `lib/models/*` modelos que representan Producto, Usuario, Pedido, Articulo, Estado de pedidos.

## Diagrama

[ UI Screens ] <--> [ Providers ] <--> [ Services ] <--> [ Firebase (Auth, Firestore, Storage) ]  

-----

## Asistencia de IA 
**Herramienta:** Gemini AI
**Finalidad:** apoyo en en uso de firebase, autenticación con google, uso de firestore, subida de imágenes, generación de APK.
**Adopciones:** 
- Conectar tu App Flutter con Firebase: https://gemini.google.com/share/8fb8792bcbaa
- Autenticación con Google: https://gemini.google.com/share/a8950cb97c43
- Modelo de Datos y Servicio de Firestore: https://gemini.google.com/share/4c1bfc72b60d
- Subida de imágenes de productos: https://gemini.google.com/share/eb7217403f76
- Generar un APK de release para Android: https://gemini.google.com/share/297777137132

---

## Referencias
- Inspiración inicial:
http://galeria.antoniogarciavillaran.es/
https://juegosdigitalesparaguay.com/comprar

- Provider:
https://docs.flutter.dev/data-and-backend/state-mgmt/simple

- Navegación:
https://docs.flutter.dev/cookbook/navigation/navigation-basics

- url_launcher, abrir URLs externas (Llamadas telefónicas, WhatsApp):
https://pub.dev/packages/url_launcher

- photo_view, visor de imágenes con zoom:
https://pub.dev/packages/photo_view

- google_fonts:
https://pub.dev/packages/google_fonts

- smooth_page_indicator, indicador de movimiento de galería de imágenes:
https://pub.dev/packages/smooth_page_indicator

- tooltip, para que se muestre texto al presionar de seguido:
https://youtu.be/EeEfD5fI-5Q?si=_1xzPuEsJcsVG9q9

- barra de búsqueda:
https://www.youtube.com/watch?v=LyxYFmcYYvE

- notify listeners:
https://api.flutter.dev/flutter/foundation/ChangeNotifier/notifyListeners.html

- barra de navegación:
https://youtu.be/DVGYddFaLv0?si=qNs0jHaXgMHZop11

- Badges:
https://youtu.be/_CIHLJHVoN8?si=X77phvs-7CtRG-97

- ScaffoldMessenger, SnackBar:
https://api.flutter.dev/flutter/material/ScaffoldMessenger-class.html?_gl=1*mrh9i7*_ga*OTgxNTU0MjQxLjE3NjE2NjI4ODk.*_ga_04YGWK0175*czE3NjE2NjYzODQkbzIkZzEkdDE3NjE2NjYzOTUkajQ5JGwwJGgw

- Imput numérico:
https://www.youtube.com/watch?v=pkBWlosVjhA&t=117s

- Hero animations:
https://docs.flutter.dev/ui/animations/hero-animations

- Readme: 
https://www.freecodecamp.org/news/how-to-write-a-good-readme-file/ 
https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks

- Varios (checkbox, toMap, temas, validar formulario, dispose, etc.):
https://www.youtube.com/watch?v=F5SuladTAQ4&list=PLrEinz_TtEGPgwiLUMQjVVz_CkW_JzmV6

---
