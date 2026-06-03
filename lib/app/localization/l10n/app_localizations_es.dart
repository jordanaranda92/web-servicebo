// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Servicebo';

  @override
  String get menuHome => 'Inicio';

  @override
  String get menuOrders => 'Pedidos';

  @override
  String get ordersHeaderLabel => 'HOY';

  @override
  String get menuSettings => 'Ajustes';

  @override
  String get settingsFacturaDirectaTitle => 'Factura Directa';

  @override
  String get settingsFacturaDirectaDescription =>
      'Conecta tu cuenta de FacturaDirecta para volcar los pedidos vía API.';

  @override
  String get settingsInvoiceSeriesLabel => 'Serie facturas';

  @override
  String get settingsInvoiceSeriesSaved => 'Serie guardada';

  @override
  String get settingsInvoiceSeriesEmpty => 'La serie no puede estar vacía';

  @override
  String get settingsInvoiceSeriesSaveError =>
      'Error al guardar la serie de facturas';

  @override
  String get settingsSave => 'Guardar';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get ordersNoFolderTitle => 'Carpeta de trabajo no configurada';

  @override
  String get ordersNoFolderMessage =>
      'Configura la carpeta de trabajo en Ajustes para poder ver los pedidos.';

  @override
  String get ordersGoToSettings => 'Ir a Ajustes';

  @override
  String get ordersNoFileTitle => 'No hay pedidos para hoy';

  @override
  String get ordersNoFileMessage =>
      'El archivo de pedidos de hoy aún no existe. Puedes crearlo a partir de la plantilla.';

  @override
  String get ordersCreateFile => 'Crear pedido de hoy';

  @override
  String get ordersErrorTemplateNotFound =>
      'No se encontró la plantilla (plantilla.xlsx) en la carpeta de trabajo.';

  @override
  String get ordersErrorFileSystem =>
      'Error al acceder a los archivos. Verifica los permisos de la carpeta de trabajo.';

  @override
  String get ordersErrorInvalidFormat =>
      'El archivo Excel tiene un formato no válido.';

  @override
  String get ordersErrorUnknown => 'Ha ocurrido un error inesperado.';

  @override
  String get ordersColumnPedidos => 'PEDIDOS';

  @override
  String get ordersColumnStocks => 'STOCKS';

  @override
  String get ordersColumnQuedan => 'QUEDAN';

  @override
  String get ordersStickyTotalsLabel => 'TOTALES';

  @override
  String get ordersRetry => 'Reintentar';

  @override
  String get ordersDelete => 'Eliminar';

  @override
  String get ordersExportExcel => 'Exportar Excel';

  @override
  String get ordersExportExcelSuccess => 'Excel exportado correctamente';

  @override
  String get ordersExportExcelError => 'Error al exportar el Excel';

  @override
  String get ordersShowPreview => 'Mostrar preview';

  @override
  String get ordersFilterClients => 'Filtrar clientes';

  @override
  String get ordersFilterClientsDialogTitle =>
      'Filtrar por categoría de cliente';

  @override
  String get ordersFilterSelectAll => 'Seleccionar todas';

  @override
  String get ordersFilterClearAll => 'Limpiar selección';

  @override
  String get ordersFilterApply => 'Aplicar';

  @override
  String get ordersFilterCancel => 'Cancelar';

  @override
  String get ordersFilterNoCategories => 'No hay categorías configuradas';

  @override
  String get ordersFilterNoCategoryLabel => 'Sin categoría';

  @override
  String get ordersDeleteConfirmTitle => 'Eliminar clientes';

  @override
  String ordersDeleteConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '¿Eliminar los $count clientes seleccionados?\nEsta acción no se puede deshacer.',
      one:
          '¿Eliminar el cliente seleccionado?\nEsta acción no se puede deshacer.',
    );
    return '$_temp0';
  }

  @override
  String get ordersDeleteConfirm => 'Eliminar';

  @override
  String get dashboardInvoices => 'Número de facturas';

  @override
  String get dashboardInvoicesTotal => 'Importe facturado';

  @override
  String get dashboardFdNotConfigured => 'Sin configurar';

  @override
  String get dashboardFdError => 'Error al cargar';

  @override
  String get dashboardVsYesterday => 'Hoy vs. ayer';

  @override
  String get dashboardVsSameWeekday => 'Hoy vs. mismo día semana anterior';

  @override
  String get dashboardVsLastWeek => 'Semana actual vs. anterior';

  @override
  String get dashboardNoData => 'Sin datos';

  @override
  String get dashboardInvoicesLabel => 'facturas';

  @override
  String get dashboardInvoicesTotalLabel => 'importe';

  @override
  String get dashboardComparisons => 'Comparativas';

  @override
  String get menuClients => 'Clientes';

  @override
  String get menuProducts => 'Productos';

  @override
  String get menuInvoices => 'Facturas';

  @override
  String get menuStatistics => 'Estadísticas';

  @override
  String get menuClientCategories => 'Categorías clientes';

  @override
  String get clientCategoriesEmpty =>
      'No se encontraron categorías de clientes';

  @override
  String get clientCategoriesColumnName => 'Nombre';

  @override
  String get clientCategoriesSearch => 'Buscar categoría...';

  @override
  String get clientCategoriesAdd => 'Añadir categoría';

  @override
  String get clientCategoriesNameRequired => 'El nombre es obligatorio';

  @override
  String get clientCategoriesColumnActions => 'Acciones';

  @override
  String get clientCategoriesEdit => 'Editar';

  @override
  String get clientCategoriesEditName => 'Editar nombre';

  @override
  String get clientCategoriesEditColor => 'Editar color';

  @override
  String get clientCategoriesDelete => 'Eliminar';

  @override
  String get clientCategoriesDeleteTitle => 'Eliminar categoría';

  @override
  String clientCategoriesDeleteMessage(String name) {
    return '¿Estás seguro de que quieres eliminar la categoría \"$name\"?\nEsta acción no se puede deshacer.';
  }

  @override
  String get clientCategoriesProgressSaving => 'Guardando cambios...';

  @override
  String get clientCategoriesProgressDeleting => 'Eliminando categoría...';

  @override
  String get clientCategoriesSuccessCreated => 'Categoría creada correctamente';

  @override
  String get clientCategoriesSuccessSaved => 'Cambios guardados correctamente';

  @override
  String get clientCategoriesSuccessDeleted =>
      'Categoría eliminada correctamente';

  @override
  String get clientCategoriesErrorOperation => 'Error al realizar la operación';

  @override
  String get clientCategoriesAssociateClients => 'Asociar clientes';

  @override
  String clientCategoriesAssociateTitle(String name) {
    return 'Asociar clientes a \"$name\"';
  }

  @override
  String get clientCategoriesAssociateSearch => 'Buscar cliente...';

  @override
  String get clientCategoriesAssociateNoClients =>
      'No hay clientes disponibles';

  @override
  String get clientCategoriesAssociateError => 'Error al cargar clientes';

  @override
  String get clientCategoriesAssociateSuccess =>
      'Clientes asociados correctamente';

  @override
  String get commonUnsavedTitle => 'Cambios sin guardar';

  @override
  String get commonUnsavedMessage =>
      'Tienes cambios sin guardar. Si sales ahora, se perderán.';

  @override
  String get commonUnsavedStay => 'Quedarse';

  @override
  String get commonUnsavedLeave => 'Salir sin guardar';

  @override
  String get clientsSearch => 'Buscar cliente...';

  @override
  String get clientsAddFromFd => 'Añadir desde Factura Directa';

  @override
  String get clientsAddFromFdLoading =>
      'Buscando nuevos contactos en Factura Directa…';

  @override
  String get clientsAddFromFdAdding => 'Añadiendo clientes seleccionados…';

  @override
  String get clientsAddFromFdNoNewTitle => 'Todo al día';

  @override
  String get clientsAddFromFdNoNew =>
      'Todos los contactos de Factura Directa ya están registrados como clientes.\nNo hay nuevos contactos pendientes de añadir.';

  @override
  String get clientsAddFromFdNoNewOk => 'Entendido';

  @override
  String get clientsAddFromFdError =>
      'Error al obtener contactos de Factura Directa';

  @override
  String clientsAddFromFdSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clientes añadidos correctamente',
      one: '1 cliente añadido correctamente',
    );
    return '$_temp0';
  }

  @override
  String get clientsAddFromFdDialogTitle => 'Seleccionar contactos';

  @override
  String clientsAddFromFdSelectedCount(int selected, int total) {
    return '$selected de $total seleccionados';
  }

  @override
  String get clientsAddFromFdSelectAll => 'Seleccionar todos';

  @override
  String get clientsAddFromFdDeselectAll => 'Deseleccionar todos';

  @override
  String get clientsAddFromFdNoName => '(Sin nombre)';

  @override
  String get clientsAddFromFdCancel => 'Cancelar';

  @override
  String clientsAddFromFdConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir $count clientes',
      one: 'Añadir 1 cliente',
      zero: 'Añadir',
    );
    return '$_temp0';
  }

  @override
  String get clientsEmpty => 'No se encontraron clientes';

  @override
  String get clientsColumnName => 'Nombre';

  @override
  String get clientsColumnNameFd => 'Nombre Factura Directa';

  @override
  String get clientsColumnFiscalId => 'NIF/CIF';

  @override
  String get clientsColumnEmail => 'Email';

  @override
  String get clientsColumnPhone => 'Teléfono';

  @override
  String get clientsColumnCity => 'Ciudad';

  @override
  String get productsSearch => 'Buscar producto...';

  @override
  String get productsEmpty => 'No se encontraron productos';

  @override
  String get productsColumnName => 'Nombre';

  @override
  String get productsColumnPrice => 'Precio';

  @override
  String get productsColumnActive => 'Activo';

  @override
  String get productsColumnInactive => 'Inactivo';

  @override
  String get productsColumnFdProduct => 'Producto Factura Directa';

  @override
  String get productsColumnActions => 'Acciones';

  @override
  String get productsSelectFdProduct => 'Vincular producto';

  @override
  String get productsSelectFdTitle => 'Seleccionar producto de Factura Directa';

  @override
  String get productsSelectFdSearch => 'Buscar producto...';

  @override
  String get productsSelectFdEmpty =>
      'No se encontraron productos en Factura Directa';

  @override
  String get productsSelectFdError =>
      'Error al cargar productos de Factura Directa';

  @override
  String get productsEdit => 'Editar';

  @override
  String get productsEditName => 'Editar nombre';

  @override
  String get productsModifyFdProduct => 'Modificar producto FD';

  @override
  String get productsActivate => 'Activar producto';

  @override
  String get productsDeactivate => 'Desactivar producto';

  @override
  String get productsDelete => 'Eliminar';

  @override
  String get productsDeleteTitle => 'Eliminar producto';

  @override
  String productsDeleteMessage(String name) {
    return '¿Estás seguro de que quieres eliminar el producto \"$name\"?\nEsta acción no se puede deshacer.';
  }

  @override
  String get productsNameRequired => 'El nombre es obligatorio';

  @override
  String get productsSuccessDeleted => 'Producto eliminado correctamente';

  @override
  String get productsSuccessLinked => 'Producto vinculado correctamente';

  @override
  String get productsNoFdLinked => 'Producto Factura Directa no vinculado';

  @override
  String get productsUnlinkFdProduct => 'Desvincular producto FD';

  @override
  String get productsSuccessUnlinked => 'Producto desvinculado correctamente';

  @override
  String get productsErrorOperation => 'Error al realizar la operación';

  @override
  String get productsAdd => 'Añadir producto';

  @override
  String get productsAddTitle => 'Nuevo producto';

  @override
  String get productsSuccessCreated => 'Producto creado correctamente';

  @override
  String get productsSuccessSaved => 'Cambios guardados correctamente';

  @override
  String get productsSaving => 'Guardando cambios...';

  @override
  String get productsErrorSaving => 'Error al guardar los cambios';

  @override
  String get productsReorder => 'Reordenar productos';

  @override
  String get productsReorderTitle => 'Ordenar productos';

  @override
  String get productsReorderSubtitle =>
      'Arrastra los productos para cambiar su orden';

  @override
  String get productsReorderSaved => 'Orden actualizado correctamente';

  @override
  String get invoicesSearchClient => 'Buscar factura...';

  @override
  String get invoicesEmpty => 'No se encontraron facturas';

  @override
  String get invoicesColumnNumber => 'Nº Factura';

  @override
  String get invoicesColumnClient => 'Cliente';

  @override
  String get invoicesColumnDate => 'Fecha';

  @override
  String get invoicesColumnTotal => 'Total';

  @override
  String get invoicesColumnSubtotal => 'Subtotal';

  @override
  String get invoicesColumnStatus => 'Estado';

  @override
  String invoicesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count facturas seleccionadas',
      one: '1 factura seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get invoicesActionConvertDefinitive => 'Convertir definitiva';

  @override
  String get invoicesNoActionsAvailable => 'No hay opciones disponibles';

  @override
  String get invoicesFilter => 'Filtrar';

  @override
  String get invoicesFilterTitle => 'Filtros';

  @override
  String get invoicesFilterStatus => 'Estado';

  @override
  String get invoicesFilterClients => 'Clientes';

  @override
  String get invoicesFilterDateFrom => 'Desde';

  @override
  String get invoicesFilterDateTo => 'Hasta';

  @override
  String get invoicesFilterApply => 'Aplicar';

  @override
  String get invoicesFilterClear => 'Limpiar filtros';

  @override
  String get invoicesFilterDateError =>
      'Fecha desde debe ser anterior a fecha hasta';

  @override
  String get invoicesFilterSearchClients => 'Buscar cliente...';

  @override
  String get invoicesLoadMore => 'Cargar más';

  @override
  String get invoicesFilterCancel => 'Cancelar';

  @override
  String get invoiceDetailTitle => 'Detalle de factura';

  @override
  String get invoiceDetailDate => 'Fecha';

  @override
  String get invoiceDetailClient => 'Cliente';

  @override
  String get invoiceDetailCurrency => 'Moneda';

  @override
  String get invoiceDetailLines => 'Líneas de factura';

  @override
  String get invoiceDetailLineDescription => 'Descripción';

  @override
  String get invoiceDetailLineQuantity => 'Cantidad';

  @override
  String get invoiceDetailLinePrice => 'Precio ud.';

  @override
  String get invoiceDetailLineTax => 'IVA';

  @override
  String get invoiceDetailLineTotal => 'Total';

  @override
  String get invoiceDetailNoLines => 'No hay líneas en esta factura';

  @override
  String get invoiceDetailSubtotal => 'Subtotal';

  @override
  String get invoiceDetailTaxBreakdown => 'Impuestos';

  @override
  String get invoiceDetailTaxBase => 'Base imponible';

  @override
  String get invoiceDetailTaxAmount => 'Cuota';

  @override
  String get invoiceDetailTotal => 'Total';

  @override
  String get invoiceDetailGoBack => 'Volver a facturas';

  @override
  String get paginationRowsPerPage => 'Filas por página:';

  @override
  String paginationRange(int start, int end, int total) {
    return '$start–$end de $total';
  }

  @override
  String get fdConfigNotFound =>
      'Configura tu cuenta de FacturaDirecta en Ajustes';

  @override
  String get fdNetworkError => 'Error de conexión. Verifica tu red';

  @override
  String get fdServerError => 'Error del servidor. Inténtalo más tarde';

  @override
  String get fdUnknownError => 'Error inesperado';

  @override
  String get fdRetry => 'Reintentar';

  @override
  String get clientsColumnCategory => 'Categoría';

  @override
  String get clientsCategoryUnspecified => 'Categoría no asignada';

  @override
  String get clientsSelectCategory => 'Seleccionar categoría';

  @override
  String get clientsSelectCategorySearch => 'Buscar categoría...';

  @override
  String get clientsSelectCategoryEmpty => 'No hay categorías disponibles';

  @override
  String get ordersResetOrders => 'Restablecer pedidos';

  @override
  String get ordersAdd => 'Añadir';

  @override
  String get ordersAddClient => 'Añadir cliente';

  @override
  String get ordersAddProduct => 'Añadir producto';

  @override
  String get ordersAddClientDialogTitle => 'Añadir clientes';

  @override
  String get ordersAddProductDialogTitle => 'Añadir productos';

  @override
  String get ordersAddDialogEmpty =>
      'Todos los elementos activos ya están en el pedido';

  @override
  String get ordersAddDialogSearch => 'Buscar...';

  @override
  String get ordersAddDialogColumnName => 'Nombre';

  @override
  String get ordersAddDialogNoResults => 'Sin resultados';

  @override
  String ordersAddDialogConfirm(int count) {
    return 'Añadir ($count)';
  }

  @override
  String get ordersExport => 'Exportar';

  @override
  String get ordersRemoveFromTable => 'Quitar de la tabla';

  @override
  String get ordersDeleteProductsConfirmTitle => 'Quitar productos';

  @override
  String ordersDeleteProductsConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '¿Quitar los $count productos seleccionados de la tabla?\nEsta acción no se puede deshacer.',
      one:
          '¿Quitar el producto seleccionado de la tabla?\nEsta acción no se puede deshacer.',
    );
    return '$_temp0';
  }

  @override
  String get ordersResetConfirmTitle => 'Restablecer pedidos';

  @override
  String ordersResetConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '¿Restablecer los pedidos de los $count clientes seleccionados? Los valores se pondrán a cero.',
      one:
          '¿Restablecer los pedidos del cliente seleccionado? Los valores se pondrán a cero.',
    );
    return '$_temp0';
  }

  @override
  String get ordersResetConfirm => 'Restablecer';

  @override
  String get settingsUserIdentityTitle => 'Identidad de usuario';

  @override
  String get settingsUserIdentityDescription =>
      'Este nombre identifica tus acciones cuando varios usuarios trabajan simultáneamente en los pedidos del día.';

  @override
  String get settingsUserNameLabel => 'Nombre de usuario';

  @override
  String ordersCellLocked(String user) {
    return 'Celda bloqueada por $user';
  }

  @override
  String ordersConnectedUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count usuarios conectados',
      one: '1 usuario conectado',
      zero: 'Sin usuarios',
    );
    return '$_temp0';
  }

  @override
  String get invoiceStatusPaid => 'Pagada';

  @override
  String get invoiceStatusPending => 'Pendiente';

  @override
  String get invoiceStatusOverdue => 'Vencida';

  @override
  String get invoiceStatusDraft => 'Provisional';

  @override
  String get invoiceStatusVoided => 'Anulada';

  @override
  String get invoiceStatusOverpaid => 'Sobrepagada';

  @override
  String productsLinkDialogSubtitle(String productName) {
    return 'Para vincular a: $productName';
  }

  @override
  String get ordersNoClients => 'No hay clientes añadidos';

  @override
  String get ordersNoClientsHint =>
      'Pulsa el botón + de la cabecera para añadir clientes.';

  @override
  String get ordersMarkCompensation => 'Marcar como compensación';

  @override
  String get ordersUnmarkCompensation => 'Desmarcar como compensación';

  @override
  String get ordersMarkReservation => 'Marcar como reserva';

  @override
  String get ordersUnmarkReservation => 'Desmarcar como reserva';

  @override
  String get ordersMarkStrictStock => 'Marcar como stock estricto';

  @override
  String get ordersUnmarkStrictStock => 'Desmarcar como stock estricto';

  @override
  String get ordersTooltipCompensation => 'Compensación';

  @override
  String get ordersTooltipReservation => 'Reserva';

  @override
  String get ordersTooltipStrictStock => 'Stock estricto';

  @override
  String get ordersAddNote => 'Añadir nota';

  @override
  String get ordersEditNote => 'Editar nota';

  @override
  String get ordersRemoveNote => 'Eliminar nota';

  @override
  String get ordersNoteDialogTitle => 'Nota';

  @override
  String get ordersNoteDialogHint => 'Escribe una nota (máx. 100 caracteres)';

  @override
  String get ordersNoteDialogSave => 'Guardar';

  @override
  String get ordersNoteDialogCancel => 'Cancelar';

  @override
  String get ordersAddRefund => 'Añadir abono';

  @override
  String get ordersEditRefund => 'Editar abono';

  @override
  String get ordersRemoveRefund => 'Eliminar abono';

  @override
  String get ordersRefundDialogTitle => 'Abono';

  @override
  String get ordersRefundDialogLabel => 'Cantidad de productos';

  @override
  String get ordersTooltipRefund => 'Abono';

  @override
  String get ordersContextMenuGenerateOrderSheet => 'Generar hoja de pedido';

  @override
  String get ordersGenerateOrderSheetEmpty =>
      'Este cliente no tiene productos con cantidad asignada.';

  @override
  String get ordersContextMenuGenerateProvisionalInvoice =>
      'Generar factura provisional';

  @override
  String get ordersContextMenuAddClientNote => 'Añadir nota';

  @override
  String get ordersContextMenuEditClientNote => 'Editar nota';

  @override
  String get ordersContextMenuDeleteClientNote => 'Eliminar nota';

  @override
  String get ordersClientNoteDialogTitle => 'Nota de cliente';

  @override
  String get ordersClientNoteDialogHint =>
      'Escribe una nota (máx. 200 caracteres)';

  @override
  String get ordersContextMenuChangeClient => 'Cambiar cliente';

  @override
  String get ordersChangeClientDialogTitle => 'Cambiar cliente';

  @override
  String get ordersChangeClientDialogConfirm => 'Confirmar';

  @override
  String get ordersContextMenuResetOrder => 'Restablecer pedido';

  @override
  String get ordersContextMenuDeleteClient => 'Eliminar cliente';

  @override
  String get ordersContextMenuDeleteProduct => 'Eliminar producto';

  @override
  String get ordersMarkLimitedProduct => 'Marcar como limitado';

  @override
  String get ordersUnmarkLimitedProduct => 'Desmarcar como limitado';

  @override
  String get ordersMarkOutOfBonusProduct => 'Marcar fuera de bono';

  @override
  String get ordersUnmarkOutOfBonusProduct => 'Desmarcar fuera de bono';

  @override
  String get ordersInfoDialogTitle => 'Ayuda de la tabla de pedidos';

  @override
  String get ordersInfoDialogClose => 'Entendido';

  @override
  String get ordersInfoAddClientTitle => 'Añadir un cliente';

  @override
  String get ordersInfoAddClientDesc =>
      'Pulsa el botón «+ Añadir cliente» en la parte superior derecha de la tabla.';

  @override
  String get ordersInfoAddProductTitle => 'Añadir un producto';

  @override
  String get ordersInfoAddProductDesc =>
      'Pulsa el botón «+ Añadir producto» en la parte inferior izquierda de la tabla.';

  @override
  String get ordersInfoEditStockTitle => 'Modificar el stock';

  @override
  String get ordersInfoEditStockDesc =>
      'Haz clic sobre la celda de la columna STOCKS del producto que deseas modificar e introduce el nuevo valor.';

  @override
  String get ordersInfoStrictStockTitle => 'Poner stock como estricto';

  @override
  String get ordersInfoStrictStockDesc =>
      'Haz clic derecho (o mantén pulsado en tablet) sobre la celda de stock de un producto y selecciona «Marcar stock estricto» en el menú contextual.';

  @override
  String get ordersInfoAssignQtyTitle => 'Asignar cantidad a un cliente';

  @override
  String get ordersInfoAssignQtyDesc =>
      'Haz clic sobre la celda en la intersección del producto y el cliente, e introduce la cantidad deseada. Usa las flechas del teclado o Tab para moverte entre celdas.';

  @override
  String get ordersInfoCompensationTitle => 'Marcar compensación';

  @override
  String get ordersInfoCompensationDesc =>
      'Haz clic derecho (o mantén pulsado en tablet) sobre una celda de cantidad de un cliente y selecciona «Marcar compensación» en el menú contextual.';

  @override
  String get ordersInfoReservationTitle => 'Marcar reserva';

  @override
  String get ordersInfoReservationDesc =>
      'Haz clic derecho (o mantén pulsado en tablet) sobre una celda de cantidad de un cliente y selecciona «Marcar reserva» en el menú contextual.';

  @override
  String get ordersInfoRemoveClientTitle => 'Quitar un cliente';

  @override
  String get ordersInfoRemoveClientDesc =>
      'Haz clic derecho (o mantén pulsado en tablet) sobre el nombre del cliente en la cabecera de la tabla y selecciona «Eliminar cliente» en el menú contextual.';

  @override
  String get ordersInfoRemoveProductTitle => 'Quitar un producto';

  @override
  String get ordersInfoRemoveProductDesc =>
      'Haz clic derecho (o mantén pulsado en tablet) sobre el nombre del producto en la columna izquierda y selecciona «Eliminar producto» en el menú contextual.';

  @override
  String get ordersInfoResetOrderTitle => 'Restablecer pedido de un cliente';

  @override
  String get ordersInfoResetOrderDesc =>
      'Haz clic derecho (o mantén pulsado en tablet) sobre el nombre del cliente en la cabecera y selecciona «Restablecer pedido» en el menú contextual. Esto pondrá a cero todas las cantidades de ese cliente.';

  @override
  String get ordersInfoOrderSheetTitle => 'Generar hoja de pedido';

  @override
  String get ordersInfoOrderSheetDesc =>
      'Haz clic derecho (o mantén pulsado en tablet) sobre el nombre del cliente en la cabecera y selecciona «Generar hoja de pedido». Genera un documento con las cantidades de productos solicitadas por el cliente, útil para que los trabajadores preparen el pedido.';

  @override
  String get ordersInfoProvisionalInvoiceTitle => 'Generar factura provisional';

  @override
  String get ordersInfoProvisionalInvoiceDesc =>
      'Haz clic derecho (o mantén pulsado en tablet) sobre el nombre del cliente en la cabecera y selecciona «Generar factura provisional». Crea la factura en estado provisional en Factura Directa con los productos y cantidades del pedido del cliente.';

  @override
  String get ordersInfoCellNoteTitle => 'Crear una nota en una celda';

  @override
  String get ordersInfoCellNoteDesc =>
      'Haz clic derecho (o mantén pulsado en tablet) sobre una celda de cantidad de un cliente y selecciona «Añadir nota». La nota se mostrará como un indicador en la celda y podrás verla al pasar el cursor por encima. Para editarla o eliminarla, vuelve a abrir el menú sobre la misma celda.';

  @override
  String get ordersPreparingTemplate =>
      'Preparando plantilla para pedidos de hoy…';

  @override
  String get provisionalInvoiceLoading => 'Preparando factura provisional…';

  @override
  String get provisionalInvoicePreviewTitle =>
      'Vista previa de factura provisional';

  @override
  String get provisionalInvoiceDraftBadge => 'PROVISIONAL';

  @override
  String get provisionalInvoiceDuplicateWarning =>
      'Ya existe una factura provisional para este cliente en esta fecha. Si continúas, se creará otra factura provisional.';

  @override
  String get provisionalInvoiceProduct => 'Producto';

  @override
  String get provisionalInvoiceQty => 'Ud.';

  @override
  String get provisionalInvoicePrice => 'Precio';

  @override
  String get provisionalInvoiceTax => 'IVA';

  @override
  String get provisionalInvoiceLineTotal => 'Total';

  @override
  String get provisionalInvoiceSubtotal => 'Subtotal';

  @override
  String get provisionalInvoiceTaxHeader => 'Impuesto';

  @override
  String get provisionalInvoiceTaxBase => 'Base imponible';

  @override
  String get provisionalInvoiceTaxAmount => 'Cuota';

  @override
  String get provisionalInvoiceNotesLabel => 'Notas';

  @override
  String get provisionalInvoiceTotal => 'Total';

  @override
  String get provisionalInvoiceCancel => 'Cancelar';

  @override
  String get provisionalInvoiceConfirm => 'Generar factura provisional';

  @override
  String get provisionalInvoiceSuccessTitle => 'Factura provisional creada';

  @override
  String provisionalInvoiceSuccessMessage(String docNumber) {
    return 'La factura provisional $docNumber se ha creado correctamente en Factura Directa.';
  }

  @override
  String get provisionalInvoiceClose => 'Cerrar';

  @override
  String get provisionalInvoiceErrorTitle => 'Error';

  @override
  String get provisionalInvoiceErrorConfigNotFound =>
      'No se ha configurado Factura Directa. Ve a Ajustes para configurarla.';

  @override
  String get provisionalInvoiceErrorClientNotLinked =>
      'Este cliente no está vinculado a Factura Directa. Vincúlalo desde la sección Clientes.';

  @override
  String get provisionalInvoiceErrorProductsNotLinked =>
      'Los siguientes productos no están vinculados a Factura Directa. Vincúlalos desde la sección Productos:';

  @override
  String get provisionalInvoiceErrorProductNotFoundInFd =>
      'Un producto vinculado no se ha encontrado en Factura Directa. Puede haber sido eliminado.';

  @override
  String get provisionalInvoiceErrorNoLines =>
      'No hay productos con cantidad para este cliente.';

  @override
  String get provisionalInvoiceErrorNetwork =>
      'No se ha podido conectar con Factura Directa. Comprueba tu conexión a internet.';

  @override
  String get provisionalInvoiceErrorServer =>
      'Error del servidor de Factura Directa. Inténtalo de nuevo más tarde.';

  @override
  String get provisionalInvoiceErrorUnknown =>
      'Se ha producido un error inesperado. Inténtalo de nuevo.';

  @override
  String get dashboardToday => 'Hoy,';

  @override
  String get weekdayMonday => 'Lunes';

  @override
  String get weekdayTuesday => 'Martes';

  @override
  String get weekdayWednesday => 'Miércoles';

  @override
  String get weekdayThursday => 'Jueves';

  @override
  String get weekdayFriday => 'Viernes';

  @override
  String get weekdaySaturday => 'Sábado';

  @override
  String get weekdaySunday => 'Domingo';

  @override
  String get monthJanuary => 'enero';

  @override
  String get monthFebruary => 'febrero';

  @override
  String get monthMarch => 'marzo';

  @override
  String get monthApril => 'abril';

  @override
  String get monthMay => 'mayo';

  @override
  String get monthJune => 'junio';

  @override
  String get monthJuly => 'julio';

  @override
  String get monthAugust => 'agosto';

  @override
  String get monthSeptember => 'septiembre';

  @override
  String get monthOctober => 'octubre';

  @override
  String get monthNovember => 'noviembre';

  @override
  String get monthDecember => 'diciembre';

  @override
  String dashboardDateFormat(int day, String month) {
    return '$day de $month';
  }

  @override
  String get clientCategoriesEditTitle => 'Editar categoría';

  @override
  String get clientCategoriesColumnColor => 'Color';

  @override
  String get clientCategoriesColumnAssociatedClients => 'Clientes';

  @override
  String get clientCategoriesColorLabel => 'Color de categoría';

  @override
  String get clientsEdit => 'Editar';

  @override
  String get clientsEditTitle => 'Editar cliente';

  @override
  String get clientsColumnShippingMethods => 'Métodos de envío';

  @override
  String get clientsColumnProvince => 'Provincia';

  @override
  String get clientsColumnCountry => 'País';

  @override
  String get clientsColumnPaymentMethod => 'Método de cobro';

  @override
  String get clientsColumnCurrency => 'Moneda';

  @override
  String get clientsDetailTitle => 'Detalle de cliente';

  @override
  String get clientsClientDataSection => 'Datos del cliente';

  @override
  String get clientsFdDataSection => 'Datos de Factura Directa';

  @override
  String get clientsShippingMethodsTitle => 'Métodos de envío';

  @override
  String get clientsShippingMethodsSubtitle =>
      'Asigna un método de envío por día';

  @override
  String get dayMonday => 'Lunes';

  @override
  String get dayTuesday => 'Martes';

  @override
  String get dayWednesday => 'Miércoles';

  @override
  String get dayThursday => 'Jueves';

  @override
  String get dayFriday => 'Viernes';

  @override
  String get daySaturday => 'Sábado';

  @override
  String get daySunday => 'Domingo';

  @override
  String get clientsShippingMethodNone => 'Sin método';

  @override
  String get clientsShippingMethodUndefined => 'Sin definir';

  @override
  String get menuShippingMethods => 'Métodos de envío';

  @override
  String get shippingMethodsSearch => 'Buscar método de envío...';

  @override
  String get shippingMethodsAdd => 'Añadir método';

  @override
  String get shippingMethodsEmpty => 'No se encontraron métodos de envío';

  @override
  String get shippingMethodsColumnName => 'Nombre';

  @override
  String get shippingMethodsColumnPhone => 'Teléfono';

  @override
  String get shippingMethodsColumnActions => 'Acciones';

  @override
  String get shippingMethodsEdit => 'Editar';

  @override
  String get shippingMethodsEditName => 'Editar nombre';

  @override
  String get shippingMethodsEditPhone => 'Editar teléfono';

  @override
  String get shippingMethodsAssociateClients => 'Asociar clientes';

  @override
  String shippingMethodsAssociateTitle(String name) {
    return 'Asociar clientes a \"$name\"';
  }

  @override
  String get shippingMethodsAssociateSearch => 'Buscar cliente...';

  @override
  String get shippingMethodsAssociateNoClients => 'No hay clientes disponibles';

  @override
  String get shippingMethodsAssociateLoading => 'Cargando clientes...';

  @override
  String get shippingMethodsAssociateError => 'Error al cargar clientes';

  @override
  String get shippingMethodsAssociateSelectAll => 'Todos los días';

  @override
  String get shippingMethodsAssociateDaysLabel => 'Selecciona los días';

  @override
  String get shippingMethodsAssociateSelectAllClients => 'Seleccionar todos';

  @override
  String get shippingMethodsDelete => 'Eliminar';

  @override
  String get shippingMethodsNameRequired => 'El nombre es obligatorio';

  @override
  String get shippingMethodsProgressSaving => 'Guardando...';

  @override
  String get shippingMethodsSuccessCreated =>
      'Método de envío creado correctamente';

  @override
  String get shippingMethodsDeleteTitle => 'Eliminar método de envío';

  @override
  String shippingMethodsDeleteMessage(String name) {
    return '¿Estás seguro de que quieres eliminar el método \"$name\"?\nEsta acción no se puede deshacer.';
  }

  @override
  String get shippingMethodsProgressDeleting => 'Eliminando método de envío...';

  @override
  String get shippingMethodsSuccessDeleted =>
      'Método de envío eliminado correctamente';

  @override
  String get shippingMethodsErrorOperation => 'Error al realizar la operación';

  @override
  String get shippingMethodsEditTitle => 'Editar método de envío';

  @override
  String get shippingMethodsPhoneHint => 'Teléfono de contacto';

  @override
  String get shippingMethodsSuccessSaved =>
      'Método de envío actualizado correctamente';

  @override
  String get clientsFdLoadError =>
      'No se pudieron cargar los datos de Factura Directa';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginSubtitle => 'Introduce tus credenciales para acceder';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginEmailHint => 'usuario@ejemplo.com';

  @override
  String get loginPasswordLabel => 'Contraseña';

  @override
  String get loginRememberMe => 'Recordarme';

  @override
  String get loginSignInButton => 'Iniciar sesión';

  @override
  String get loginErrorEmailEmpty => 'Introduce tu email';

  @override
  String get loginErrorEmailInvalid => 'Formato de email no válido';

  @override
  String get loginErrorPasswordEmpty => 'Introduce tu contraseña';

  @override
  String get loginErrorInvalidCredentials => 'Email o contraseña incorrectos';

  @override
  String get loginErrorUserDisabled =>
      'Cuenta deshabilitada. Contacta al administrador';

  @override
  String get loginErrorTooManyRequests =>
      'Demasiados intentos. Inténtalo más tarde';

  @override
  String get loginErrorNetwork => 'Sin conexión a internet';

  @override
  String get loginErrorUnknown => 'Error de autenticación inesperado';

  @override
  String get settingsSignOut => 'Cerrar sesión';

  @override
  String get settingsSignOutConfirmTitle => 'Cerrar sesión';

  @override
  String get settingsSignOutConfirmMessage =>
      '¿Estás seguro de que quieres cerrar sesión?';

  @override
  String get settingsSignOutConfirmCancel => 'Cancelar';

  @override
  String get settingsSignOutConfirmAccept => 'Cerrar sesión';

  @override
  String get notFoundMessage => 'La página que buscas no existe.';

  @override
  String get notFoundGoHome => 'Ir al inicio';

  @override
  String get clientNotFoundMessage =>
      'No se ha encontrado el cliente solicitado.';

  @override
  String get clientNotFoundGoBack => 'Volver a clientes';

  @override
  String get clientSaveSuccess => 'Cambios guardados correctamente';

  @override
  String get ordersMobileTitle => 'Pantalla no disponible';

  @override
  String get ordersMobileDescription =>
      'La gestión de pedidos de hoy solo está disponible en pantallas de mayor tamaño. Por favor, accede desde un ordenador o una tablet.';

  @override
  String get ordersMobileNoOrders => 'No hay pedidos registrados hoy';

  @override
  String ordersMobileProductCount(String count) {
    return '$count uds.';
  }

  @override
  String get ordersMobileReservation => 'Reserva';

  @override
  String get ordersMobileCompensation => 'Compensación';

  @override
  String ordersMobileRefund(String quantity) {
    return 'Abono: $quantity';
  }

  @override
  String ordersLastModified(String date) {
    return 'Última actualización: $date';
  }

  @override
  String get ordersNoOrdersToday => 'No hay pedidos para hoy';

  @override
  String get ordersLiveConnected => 'Conectado en tiempo real';

  @override
  String get ordersLiveDisconnected => 'Desconectado';

  @override
  String get statisticsComingSoon => 'Próximamente';

  @override
  String get pdfSelectShippingMethod => 'Seleccionar método de envío';

  @override
  String get pdfSearchShippingMethod => 'Buscar método de envío...';

  @override
  String get pdfColumnName => 'Nombre';

  @override
  String get pdfColumnPhone => 'Teléfono';

  @override
  String get pdfNoShippingMethodsFound => 'No se encontraron métodos de envío';

  @override
  String get taxLabelIva21 => 'IVA 21%';

  @override
  String get taxLabelIva10 => 'IVA 10%';

  @override
  String get taxLabelIva4 => 'IVA 4%';

  @override
  String get taxLabelRe52 => 'RE 5,20%';

  @override
  String get taxLabelRe14 => 'RE 1,40%';

  @override
  String get taxLabelRe05 => 'RE 0,50%';

  @override
  String dashboardDateRangeFormat(int startDay, int endDay, String month) {
    return '$startDay–$endDay de $month';
  }

  @override
  String pdfSubtitleFor(String clientName, String dayName) {
    return 'Para: $clientName ($dayName)';
  }

  @override
  String settingsAppVersionTitle(String version) {
    return 'Versión de la web $version';
  }

  @override
  String get ordersDateSelectorTitle => 'Seleccionar fecha';

  @override
  String get ordersDateSelectorAccept => 'Aceptar';

  @override
  String get ordersDateSelectorCancel => 'Cancelar';

  @override
  String ordersDateSelectorClients(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clientes',
      one: '1 cliente',
      zero: 'Sin clientes',
    );
    return '$_temp0';
  }

  @override
  String get ordersDateSelectorNoOrders => 'Sin pedidos';

  @override
  String get ordersDateSelectorToday => 'HOY';

  @override
  String get ordersDateSelectorChange => 'Cambiar fecha';

  @override
  String get ordersPdfLabelClient => 'Cliente';

  @override
  String get ordersPdfLabelDateTime => 'Fecha y hora';

  @override
  String get ordersPdfLabelOrderNumber => 'Número de pedido';

  @override
  String get ordersPdfLabelProduct => 'Producto';

  @override
  String get ordersPdfLabelQuantity => 'Cantidad';

  @override
  String get ordersPdfLabelNotes => 'Notas';

  @override
  String get ordersPdfLabelShippingMethod => 'Método de envío';

  @override
  String get ordersPdfLabelTotalProducts => 'Cantidad de productos';

  @override
  String get ordersPdfLabelSubtotal => 'Subtotal';

  @override
  String get ordersExcelSheetName => 'Pedidos';
}
