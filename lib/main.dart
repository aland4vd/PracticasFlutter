import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.indigo,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    ),
    home: const SubirFotoPage(),
  ));
}

class SubirFotoPage extends StatefulWidget {
  const SubirFotoPage({super.key});

  @override
  State<SubirFotoPage> createState() => _SubirFotoPageState();
}

class _SubirFotoPageState extends State<SubirFotoPage> {
  File? _imagen;
  final TextEditingController _descripcionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _subiendo = false;
  bool _cargandoLista = true;
  List<dynamic> _fotosSubidas = [];

  // IMPORTANTE:
  // - Emulador Android Studio: http://10.0.2.2:8000
  // - Windows / Chrome local: http://127.0.0.1:8000
  // - Teléfono físico (Wi-Fi): http://TU_IP_LOCAL:8000
  final String baseUrl = "http://127.0.0.1:8000";

  String get apiUrl => "$baseUrl/fotos";

  @override
  void initState() {
    super.initState();
    _obtenerFotos();
  }

  Future<void> _obtenerFotos() async {
    setState(() => _cargandoLista = true);
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          if (decoded is List) {
            _fotosSubidas = decoded.reversed.toList();
          } else if (decoded is Map) {
            // Busca automáticamente cualquier propiedad que sea una lista
            final listaEncontrada = decoded.values.firstWhere(
                  (v) => v is List,
              orElse: () => [],
            );
            _fotosSubidas = (listaEncontrada as List).reversed.toList();
          }
        });
      } else {
        _mostrarSnackBar("Error GET: ${response.statusCode}", esError: true);
      }
    } catch (e) {
      _mostrarSnackBar("No se pudo conectar a $apiUrl: $e", esError: true);
    } finally {
      if (mounted) {
        setState(() => _cargandoLista = false);
      }
    }
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    final XFile? foto = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (foto != null) {
      setState(() {
        _imagen = File(foto.path);
      });
    }
  }

  void _mostrarSnackBar(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _subirAApi() async {
    if (_imagen == null || _descripcionController.text.trim().isEmpty) {
      _mostrarSnackBar(
        "Por favor selecciona una foto y escribe una descripción",
        esError: true,
      );
      return;
    }

    setState(() {
      _subiendo = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['descripcion'] = _descripcionController.text.trim();
      // Si tu tabla en MySQL pide blog_id obligatorio, descomenta la siguiente línea:
      // request.fields['blog_id'] = '1';

      request.files.add(
        await http.MultipartFile.fromPath('file', _imagen!.path),
      );

      var response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        _mostrarSnackBar("¡Foto subida correctamente!");
        setState(() {
          _imagen = null;
          _descripcionController.clear();
        });
        await _obtenerFotos(); // Recarga la lista de abajo automáticamente
      } else {
        _mostrarSnackBar(
          "Error al subir (Código: ${response.statusCode})",
          esError: true,
        );
      }
    } catch (e) {
      _mostrarSnackBar("Error de conexión: $e", esError: true);
    } finally {
      if (mounted) {
        setState(() {
          _subiendo = false;
        });
      }
    }
  }

  String _construirUrlImagen(Map<String, dynamic> item) {
    String ruta = (item['ruta'] ?? '').toString().replaceAll('\\', '/');
    String urlCompleta = ruta.startsWith('http')
        ? ruta
        : (ruta.startsWith('/') ? "$baseUrl$ruta" : "$baseUrl/$ruta");
    return Uri.encodeFull(urlCompleta);
  }

  String _formatearFecha(Map<String, dynamic> item) {
    final rawFecha = item['fecha'] ??
        item['created_at'] ??
        item['fecha_subida'] ??
        item['fecha_creacion'];

    if (rawFecha == null || rawFecha.toString().isEmpty) {
      return "Sin fecha registrada";
    }

    final parsed = DateTime.tryParse(rawFecha.toString());
    if (parsed != null) {
      final d = parsed.toLocal();
      final dia = d.day.toString().padLeft(2, '0');
      final mes = d.month.toString().padLeft(2, '0');
      final hora = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return "$dia/$mes/${d.year} • $hora:$min";
    }
    return rawFecha.toString();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Galería y Publicaciones",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _obtenerFotos,
            tooltip: "Actualizar lista",
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _obtenerFotos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- SECCIÓN 1: FORMULARIO DE SUBIDA ---
                  Container(
                    height: 230,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _imagen != null
                            ? colorScheme.primary
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _imagen == null
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Ninguna imagen seleccionada",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                        : Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            _imagen!,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white),
                              onPressed: () {
                                setState(() => _imagen = null);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      if (!kIsWeb && !Platform.isWindows) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _subiendo
                                ? null
                                : () => _seleccionarImagen(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text("Cámara"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _subiendo
                              ? null
                              : () => _seleccionarImagen(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text("Galería / Archivo"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _descripcionController,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: "Descripción de la foto",
                      hintText: "Escribe un comentario o título...",
                      prefixIcon: const Icon(Icons.description_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _subiendo ? null : _subirAApi,
                      icon: _subiendo
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        _subiendo ? "Subiendo foto..." : "Subir a API",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 12),

                  // --- SECCIÓN 2: LISTA DE FOTOS SUBIDAS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Fotos subidas",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${_fotosSubidas.length} elementos",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_cargandoLista)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_fotosSubidas.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        "Aún no hay fotos registradas en el servidor.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _fotosSubidas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final item =
                        _fotosSubidas[index] as Map<String, dynamic>;
                        final urlImagen = _construirUrlImagen(item);
                        final descripcion =
                            item['descripcion']?.toString() ?? 'Sin descripción';
                        final fecha = _formatearFecha(item);

                        return Card(
                          color: Colors.white,
                          elevation: 2,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Imagen desde el servidor
                              AspectRatio(
                                aspectRatio: 16 / 10,
                                child: Image.network(
                                  urlImagen,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image_outlined,
                                              size: 40,
                                              color: Colors.grey.shade500),
                                          const SizedBox(height: 6),
                                          Text(
                                            "No se pudo cargar la imagen",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Descripción y fecha abajo
                              Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      descripcion,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 15,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          fecha,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}