import 'dart:async';

enum Categoria { bebida, comida, postre }

enum EstadoPedido {
  creado,
  pagoPendiente,
  pagado,
  preparando,
  listo,
  entregado,
  cancelado,
}

class Producto {
  final int idProducto;
  final String nombre;
  final double precio;
  int stock;
  final Categoria categoria;

  Producto(this.idProducto, this.nombre, this.precio, this.stock, this.categoria);

  @override
  String toString() => '$nombre (Q${precio.toStringAsFixed(2)}) - stock: $stock';
}

class Cliente {
  final int idCliente;
  final String clienteNombre;
  final String clienteCorreo;
  int puntos;
  List<dynamic> pedidos = [];

  Cliente(this.idCliente, this.clienteNombre, this.clienteCorreo, this.puntos);

  @override
  String toString() => '$clienteNombre ($clienteCorreo) - Puntos: $puntos';
}

class LineaPedido {
  final Producto producto;
  int cantidad;

  LineaPedido(this.producto, this.cantidad);

  double get subtotal => producto.precio * cantidad;

  @override
  String toString() =>
      '$cantidad x ${producto.nombre}  Q${subtotal.toStringAsFixed(2)}';
}

class Pedido {
  final int numero;
  final Cliente cliente;
  final DateTime fecha;
  final List<LineaPedido> _lineas = [];
  EstadoPedido estado = EstadoPedido.creado;

  Pedido(this.numero, this.cliente) : fecha = DateTime.now();

  List<LineaPedido> get lineas => List.unmodifiable(_lineas);

  double get subtotal =>
      _lineas.fold(0, (suma, linea) => suma + linea.subtotal);

  double get descuento {
    double d1 = subtotal >= 150 ? subtotal * 0.05 : 0;
    double d2 = cliente.puntos >= 100 ? subtotal * 0.10 : 0;
    return d1 > d2 ? d1 : d2;
  }

  double get total => subtotal - descuento;

  bool agregarProducto(Producto producto, int cantidad) {
    if (estado == EstadoPedido.pagado ||
        estado == EstadoPedido.preparando ||
        estado == EstadoPedido.listo ||
        estado == EstadoPedido.entregado) {
      print('No se puede modificar el pedido ${estado.name}');
      return false;
    }

    if (cantidad <= 0) {
      print('La cantidad debe ser mayor a cero');
      return false;
    }

    if (cantidad > producto.stock) {
      print('Stock insuficiente de ${producto.nombre}. Disponible: ${producto.stock}');
      return false;
    }

    for (var linea in _lineas) {
      if (linea.producto.idProducto == producto.idProducto) {
        if (linea.cantidad + cantidad > producto.stock) {
          print('Stock insuficiente');
          return false;
        }
        linea.cantidad += cantidad;
        print(' ${producto.nombre} actualizado a ${linea.cantidad} unidades');
        return true;
      }
    }

    _lineas.add(LineaPedido(producto, cantidad));
    print('$cantidad x ${producto.nombre} agregado');
    return true;
  }

  bool eliminarProducto(int productoId) {
    if (estado == EstadoPedido.pagado || estado == EstadoPedido.preparando) {
      print('No se puede modificar un pedido en estado ${estado.name}');
      return false;
    }
    final antes = _lineas.length;
    _lineas.removeWhere((l) => l.producto.idProducto == productoId);
    return _lineas.length < antes;
  }

  String generarRecibo() {
    final sb = StringBuffer();
    sb.writeln('Pedido #$numero - ${cliente.clienteNombre}');
    for (var linea in _lineas) {
      sb.writeln(linea.toString());
    }
    sb.writeln('Subtotal  Q${subtotal.toStringAsFixed(2)}');
    if (descuento > 0) {
      final pct = (descuento / subtotal * 100).toStringAsFixed(0);
      sb.writeln('Descuento $pct% Q${descuento.toStringAsFixed(2)}');
    }
    sb.writeln('TOTAL  Q${total.toStringAsFixed(2)}');
    return sb.toString();
  }
}

class ResultadoPago {
  bool aprobado;
  String mensaje;
  int codigo;

  ResultadoPago(this.aprobado, this.mensaje, this.codigo);

  @override
  String toString() =>
      aprobado ? 'Aprobado: AUT-$codigo' : ' Rechazado: $mensaje';
}

Future<List<Producto>> cargarCatalogo() async {
  await Future.delayed(const Duration(milliseconds: 600));
  return [
    Producto(1, 'Crossaint', 30.0, 20, Categoria.comida),
    Producto(2, 'Shuco', 12.0, 15, Categoria.comida),
    Producto(3, 'Pan con pollo', 15.0, 10, Categoria.comida),
    Producto(4, 'Rosa de Jamaica', 8.0, 20, Categoria.bebida),
    Producto(5, 'Horchata', 10.0, 20, Categoria.bebida),
    Producto(6, 'Tamarindo', 8.0, 20, Categoria.bebida),
    Producto(7, 'Flan', 8.0, 10, Categoria.postre),
    Producto(8, 'Pastel', 15.0, 8, Categoria.postre),
    Producto(9, 'Gelatina', 5.0, 30, Categoria.postre),
  ];
}

Future<ResultadoPago> procesarPago(Pedido pedido, {bool aprobar = true}) async {
  if (pedido.lineas.isEmpty) {
    return ResultadoPago(false, 'El pedido está vacío', 0);
  }

  pedido.estado = EstadoPedido.pagoPendiente;
  await Future.delayed(const Duration(milliseconds: 500));

  if (aprobar) {
    pedido.estado = EstadoPedido.pagado;
    for (var linea in pedido.lineas) {
      linea.producto.stock -= linea.cantidad;
    }
    return ResultadoPago(true, 'Pago exitoso', pedido.numero);
  } else {
    pedido.estado = EstadoPedido.creado;
    return ResultadoPago(false, 'Tarjeta rechazada', 0);
  }
}

Stream<EstadoPedido> prepararPedido(Pedido pedido) async* {
  if (pedido.estado != EstadoPedido.pagado) {
    print(' El pedido no está pagado');
    return;
  }

  pedido.estado = EstadoPedido.preparando;
  yield pedido.estado;
  await Future.delayed(const Duration(milliseconds: 500));

  pedido.estado = EstadoPedido.listo;
  yield pedido.estado;
  await Future.delayed(const Duration(milliseconds: 500));

  pedido.estado = EstadoPedido.entregado;
  yield pedido.estado;

  int puntosGanados = (pedido.total / 10).floor();
  pedido.cliente.puntos += puntosGanados;
  pedido.cliente.pedidos.add(pedido);
  print(' Puntos obtenidos: $puntosGanados');
  print(' Puntos acumulados: ${pedido.cliente.puntos}');
}

Future<void> main() async {
  print('Cargando catalogo');

  final catalogo = await cargarCatalogo();
  print('Catalogo disponible: ${catalogo.length} productos\n');

  final sofia = Cliente(1, 'Sofia Ramirez', 'sofia@mail.com', 120);

  final pedido = Pedido(1001, sofia);

  pedido.agregarProducto(catalogo[0], 2);
  pedido.agregarProducto(catalogo[4], 2);
  pedido.agregarProducto(catalogo[7], 1);

  pedido.agregarProducto(catalogo[8], 100);

  print('\n${pedido.generarRecibo()}');

  final pago = await procesarPago(pedido, aprobar: true);
  print(pago);

  await for (final estado in prepararPedido(pedido)) {
    print('Actualizacion: ${estado.name}');
  }

  print('\n RESUMEN ');
  print(sofia);
  print('Pedidos realizados: ${sofia.pedidos.length}');
  print('\nStock actualizado:');
  for (var p in catalogo) {
    print('  $p');
  }

  print('\n CONSULTAS ');

  final bajos = catalogo.where((p) => p.stock < 5).toList();
  print('Stock bajo: ${bajos.map((p) => p.nombre).join(', ')}');

  final valorInventario = catalogo.fold<double>(
    0,
    (suma, p) => suma + (p.precio * p.stock),
  );
  print('Valor inventario: Q${valorInventario.toStringAsFixed(2)}');

  final ordenados = [...catalogo]..sort((a, b) => b.precio.compareTo(a.precio));
  print('Ordenados por precio: ${ordenados.map((p) => p.nombre).join(', ')}');

  final porCategoria = <Categoria, int>{};
  for (var p in catalogo) {
    porCategoria[p.categoria] = (porCategoria[p.categoria] ?? 0) + 1;
  }
  print('Productos por categoría: $porCategoria');
}
