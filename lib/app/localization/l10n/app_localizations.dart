import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// Título de la aplicación
  ///
  /// In es, this message translates to:
  /// **'Servicebo'**
  String get appTitle;

  /// Ítem de menú: Inicio
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get menuHome;

  /// Ítem de menú: Pedidos de hoy
  ///
  /// In es, this message translates to:
  /// **'Pedidos de hoy'**
  String get menuOrdersToday;

  /// Etiqueta superior del header de pedidos de hoy
  ///
  /// In es, this message translates to:
  /// **'HOY'**
  String get ordersTodayHeaderLabel;

  /// Ítem de menú: Historial de pedidos
  ///
  /// In es, this message translates to:
  /// **'Historial de pedidos'**
  String get menuOrdersHistory;

  /// Ítem de menú: Ajustes
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get menuSettings;

  /// Título de la sección de FacturaDirecta en Ajustes
  ///
  /// In es, this message translates to:
  /// **'Factura Directa'**
  String get settingsFacturaDirectaTitle;

  /// Descripción de la sección de FacturaDirecta
  ///
  /// In es, this message translates to:
  /// **'Conecta tu cuenta de FacturaDirecta para volcar los pedidos vía API.'**
  String get settingsFacturaDirectaDescription;

  /// Label del campo de serie de facturas en ajustes
  ///
  /// In es, this message translates to:
  /// **'Serie facturas'**
  String get settingsInvoiceSeriesLabel;

  /// Mensaje de éxito al guardar la serie de facturas
  ///
  /// In es, this message translates to:
  /// **'Serie guardada'**
  String get settingsInvoiceSeriesSaved;

  /// Error cuando la serie de facturas está vacía
  ///
  /// In es, this message translates to:
  /// **'La serie no puede estar vacía'**
  String get settingsInvoiceSeriesEmpty;

  /// Error cuando falla el guardado de la serie de facturas en Firestore
  ///
  /// In es, this message translates to:
  /// **'Error al guardar la serie de facturas'**
  String get settingsInvoiceSeriesSaveError;

  /// Botón para guardar configuración
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get settingsSave;

  /// Botón para cancelar una acción
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get settingsCancel;

  /// Título cuando no hay carpeta de trabajo configurada en pedidos de hoy
  ///
  /// In es, this message translates to:
  /// **'Carpeta de trabajo no configurada'**
  String get ordersTodayNoFolderTitle;

  /// Mensaje cuando no hay carpeta de trabajo configurada
  ///
  /// In es, this message translates to:
  /// **'Configura la carpeta de trabajo en Ajustes para poder ver los pedidos.'**
  String get ordersTodayNoFolderMessage;

  /// Botón para navegar a la página de ajustes desde pedidos de hoy
  ///
  /// In es, this message translates to:
  /// **'Ir a Ajustes'**
  String get ordersTodayGoToSettings;

  /// Título cuando no existe el archivo del día
  ///
  /// In es, this message translates to:
  /// **'No hay pedidos para hoy'**
  String get ordersTodayNoFileTitle;

  /// Mensaje cuando no existe el archivo del día
  ///
  /// In es, this message translates to:
  /// **'El archivo de pedidos de hoy aún no existe. Puedes crearlo a partir de la plantilla.'**
  String get ordersTodayNoFileMessage;

  /// Botón para crear el archivo del día desde la plantilla
  ///
  /// In es, this message translates to:
  /// **'Crear pedido de hoy'**
  String get ordersTodayCreateFile;

  /// Error cuando falta la plantilla
  ///
  /// In es, this message translates to:
  /// **'No se encontró la plantilla (plantilla.xlsx) en la carpeta de trabajo.'**
  String get ordersTodayErrorTemplateNotFound;

  /// Error de acceso a archivos
  ///
  /// In es, this message translates to:
  /// **'Error al acceder a los archivos. Verifica los permisos de la carpeta de trabajo.'**
  String get ordersTodayErrorFileSystem;

  /// Error de formato del Excel
  ///
  /// In es, this message translates to:
  /// **'El archivo Excel tiene un formato no válido.'**
  String get ordersTodayErrorInvalidFormat;

  /// Error desconocido en pedidos de hoy
  ///
  /// In es, this message translates to:
  /// **'Ha ocurrido un error inesperado.'**
  String get ordersTodayErrorUnknown;

  /// Cabecera de la columna de pedidos totales por producto
  ///
  /// In es, this message translates to:
  /// **'PEDIDOS'**
  String get ordersTodayColumnPedidos;

  /// Cabecera de la columna de stock disponible
  ///
  /// In es, this message translates to:
  /// **'STOCKS'**
  String get ordersTodayColumnStocks;

  /// Cabecera de la columna de unidades restantes (stocks - pedidos)
  ///
  /// In es, this message translates to:
  /// **'QUEDAN'**
  String get ordersTodayColumnQuedan;

  /// Botón para reintentar la carga
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get ordersTodayRetry;

  /// Botón para eliminar filas seleccionadas
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get ordersTodayDelete;

  /// Botón para exportar la tabla de pedidos de hoy como Excel
  ///
  /// In es, this message translates to:
  /// **'Exportar Excel'**
  String get ordersTodayExportExcel;

  /// Mensaje de éxito al exportar el Excel
  ///
  /// In es, this message translates to:
  /// **'Excel exportado correctamente'**
  String get ordersTodayExportExcelSuccess;

  /// Mensaje de error al exportar el Excel
  ///
  /// In es, this message translates to:
  /// **'Error al exportar el Excel'**
  String get ordersTodayExportExcelError;

  /// Botón para mostrar la previsualización de pedidos
  ///
  /// In es, this message translates to:
  /// **'Mostrar preview'**
  String get ordersTodayShowPreview;

  /// Botón para filtrar clientes por categoría en la tabla de pedidos de hoy
  ///
  /// In es, this message translates to:
  /// **'Filtrar clientes'**
  String get ordersTodayFilterClients;

  /// Título del diálogo de filtro de clientes por categoría
  ///
  /// In es, this message translates to:
  /// **'Filtrar por categoría de cliente'**
  String get ordersTodayFilterClientsDialogTitle;

  /// Botón para seleccionar todas las categorías en el filtro
  ///
  /// In es, this message translates to:
  /// **'Seleccionar todas'**
  String get ordersTodayFilterSelectAll;

  /// Botón para limpiar la selección de categorías en el filtro
  ///
  /// In es, this message translates to:
  /// **'Limpiar selección'**
  String get ordersTodayFilterClearAll;

  /// Botón para aplicar el filtro de categorías
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get ordersTodayFilterApply;

  /// Botón para cancelar el filtro de categorías
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get ordersTodayFilterCancel;

  /// Mensaje cuando no existen categorías de clientes
  ///
  /// In es, this message translates to:
  /// **'No hay categorías configuradas'**
  String get ordersTodayFilterNoCategories;

  /// Etiqueta para clientes sin categoría asignada en el filtro
  ///
  /// In es, this message translates to:
  /// **'Sin categoría'**
  String get ordersTodayFilterNoCategoryLabel;

  /// Título del diálogo de confirmación para eliminar clientes
  ///
  /// In es, this message translates to:
  /// **'Eliminar clientes'**
  String get ordersTodayDeleteConfirmTitle;

  /// Mensaje del diálogo de confirmación para eliminar clientes
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{¿Eliminar el cliente seleccionado?\nEsta acción no se puede deshacer.} other{¿Eliminar los {count} clientes seleccionados?\nEsta acción no se puede deshacer.}}'**
  String ordersTodayDeleteConfirmMessage(int count);

  /// Botón de confirmar eliminación en el diálogo
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get ordersTodayDeleteConfirm;

  /// Título cuando no hay archivos históricos
  ///
  /// In es, this message translates to:
  /// **'Sin pedidos anteriores'**
  String get ordersHistoryEmptyTitle;

  /// Mensaje cuando no hay pedidos históricos
  ///
  /// In es, this message translates to:
  /// **'No hay pedidos de días anteriores registrados.'**
  String get ordersHistoryEmptyMessage;

  /// Error de servidor en historial
  ///
  /// In es, this message translates to:
  /// **'Error al conectar con el servidor. Comprueba tu conexión e inténtalo de nuevo.'**
  String get ordersHistoryErrorServer;

  /// Error desconocido en historial
  ///
  /// In es, this message translates to:
  /// **'Ha ocurrido un error inesperado.'**
  String get ordersHistoryErrorUnknown;

  /// Botón para reintentar la carga en historial
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get ordersHistoryRetry;

  /// Botón para volver al listado de fechas
  ///
  /// In es, this message translates to:
  /// **'Volver al listado'**
  String get ordersHistoryBackToList;

  /// Placeholder del campo de búsqueda de clientes en historial
  ///
  /// In es, this message translates to:
  /// **'Buscar cliente...'**
  String get ordersHistorySearchClient;

  /// Cabecera de la columna de clientes en historial
  ///
  /// In es, this message translates to:
  /// **'Cliente'**
  String get ordersHistoryColumnClient;

  /// Cabecera de la columna de totales en historial
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get ordersHistoryColumnTotal;

  /// Etiqueta de la fila de totales en historial
  ///
  /// In es, this message translates to:
  /// **'Totales'**
  String get ordersHistoryRowTotals;

  /// Conteo de clientes en el listado de fechas
  ///
  /// In es, this message translates to:
  /// **'{count} clientes'**
  String ordersHistoryDateClients(int count);

  /// Conteo de productos en el listado de fechas
  ///
  /// In es, this message translates to:
  /// **'{count} productos'**
  String ordersHistoryDateProducts(int count);

  /// Etiqueta para la sección de la última semana en el historial
  ///
  /// In es, this message translates to:
  /// **'Última semana'**
  String get ordersHistoryLastWeek;

  /// Etiqueta del contador de facturas del día en el dashboard
  ///
  /// In es, this message translates to:
  /// **'Número de facturas'**
  String get dashboardInvoices;

  /// Etiqueta del importe total de facturas del día en el dashboard
  ///
  /// In es, this message translates to:
  /// **'Importe facturado'**
  String get dashboardInvoicesTotal;

  /// Aviso en cards de FacturaDirecta cuando no hay configuración
  ///
  /// In es, this message translates to:
  /// **'Sin configurar'**
  String get dashboardFdNotConfigured;

  /// Aviso en cards de FacturaDirecta cuando falla la carga
  ///
  /// In es, this message translates to:
  /// **'Error al cargar'**
  String get dashboardFdError;

  /// Título de la comparativa hoy vs ayer
  ///
  /// In es, this message translates to:
  /// **'Hoy vs. ayer'**
  String get dashboardVsYesterday;

  /// Título de la comparativa hoy vs mismo día de la semana pasada
  ///
  /// In es, this message translates to:
  /// **'Hoy vs. mismo día semana anterior'**
  String get dashboardVsSameWeekday;

  /// Título de la comparativa semanal
  ///
  /// In es, this message translates to:
  /// **'Semana actual vs. anterior'**
  String get dashboardVsLastWeek;

  /// Texto mostrado cuando no hay datos para una comparativa
  ///
  /// In es, this message translates to:
  /// **'Sin datos'**
  String get dashboardNoData;

  /// Etiqueta de facturas en comparativas
  ///
  /// In es, this message translates to:
  /// **'facturas'**
  String get dashboardInvoicesLabel;

  /// Etiqueta de importe facturado en comparativas
  ///
  /// In es, this message translates to:
  /// **'importe'**
  String get dashboardInvoicesTotalLabel;

  /// Título de la sección de comparativas
  ///
  /// In es, this message translates to:
  /// **'Comparativas'**
  String get dashboardComparisons;

  /// Ítem de menú: Clientes
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get menuClients;

  /// Ítem de menú: Productos
  ///
  /// In es, this message translates to:
  /// **'Productos'**
  String get menuProducts;

  /// Ítem de menú: Facturas
  ///
  /// In es, this message translates to:
  /// **'Facturas'**
  String get menuInvoices;

  /// Ítem de menú: Estadísticas (solo admin)
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get menuStatistics;

  /// Ítem de menú: Categorías de clientes
  ///
  /// In es, this message translates to:
  /// **'Categorías clientes'**
  String get menuClientCategories;

  /// Mensaje cuando no hay categorías de clientes
  ///
  /// In es, this message translates to:
  /// **'No se encontraron categorías de clientes'**
  String get clientCategoriesEmpty;

  /// Cabecera de columna nombre en tabla de categorías de clientes
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get clientCategoriesColumnName;

  /// Placeholder del buscador de categorías de clientes
  ///
  /// In es, this message translates to:
  /// **'Buscar categoría...'**
  String get clientCategoriesSearch;

  /// Botón para añadir una nueva categoría de clientes
  ///
  /// In es, this message translates to:
  /// **'Añadir categoría'**
  String get clientCategoriesAdd;

  /// Validación: nombre de categoría vacío
  ///
  /// In es, this message translates to:
  /// **'El nombre es obligatorio'**
  String get clientCategoriesNameRequired;

  /// Cabecera de columna acciones en tabla de categorías de clientes
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get clientCategoriesColumnActions;

  /// Tooltip botón editar categoría
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get clientCategoriesEdit;

  /// Opción de menú para editar el nombre de la categoría
  ///
  /// In es, this message translates to:
  /// **'Editar nombre'**
  String get clientCategoriesEditName;

  /// Opción de menú para editar el color de la categoría
  ///
  /// In es, this message translates to:
  /// **'Editar color'**
  String get clientCategoriesEditColor;

  /// Tooltip y botón eliminar categoría
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get clientCategoriesDelete;

  /// Título del diálogo de confirmación de eliminación
  ///
  /// In es, this message translates to:
  /// **'Eliminar categoría'**
  String get clientCategoriesDeleteTitle;

  /// Mensaje de confirmación de eliminación de categoría
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que quieres eliminar la categoría \"{name}\"?\nEsta acción no se puede deshacer.'**
  String clientCategoriesDeleteMessage(String name);

  /// Texto del diálogo de progreso al guardar
  ///
  /// In es, this message translates to:
  /// **'Guardando cambios...'**
  String get clientCategoriesProgressSaving;

  /// Texto del diálogo de progreso al eliminar
  ///
  /// In es, this message translates to:
  /// **'Eliminando categoría...'**
  String get clientCategoriesProgressDeleting;

  /// Toast tras crear categoría
  ///
  /// In es, this message translates to:
  /// **'Categoría creada correctamente'**
  String get clientCategoriesSuccessCreated;

  /// Toast tras guardar cambios en lote
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados correctamente'**
  String get clientCategoriesSuccessSaved;

  /// Toast tras eliminar categoría
  ///
  /// In es, this message translates to:
  /// **'Categoría eliminada correctamente'**
  String get clientCategoriesSuccessDeleted;

  /// Toast de error genérico en operación de categoría
  ///
  /// In es, this message translates to:
  /// **'Error al realizar la operación'**
  String get clientCategoriesErrorOperation;

  /// Tooltip del botón para asociar clientes a una categoría
  ///
  /// In es, this message translates to:
  /// **'Asociar clientes'**
  String get clientCategoriesAssociateClients;

  /// Título del diálogo de asociación de clientes
  ///
  /// In es, this message translates to:
  /// **'Asociar clientes a \"{name}\"'**
  String clientCategoriesAssociateTitle(String name);

  /// Hint del campo de búsqueda en el diálogo de asociación
  ///
  /// In es, this message translates to:
  /// **'Buscar cliente...'**
  String get clientCategoriesAssociateSearch;

  /// Mensaje cuando no hay clientes para asociar
  ///
  /// In es, this message translates to:
  /// **'No hay clientes disponibles'**
  String get clientCategoriesAssociateNoClients;

  /// Mensaje de error al cargar clientes en el diálogo de asociación
  ///
  /// In es, this message translates to:
  /// **'Error al cargar clientes'**
  String get clientCategoriesAssociateError;

  /// Toast de éxito tras asociar clientes
  ///
  /// In es, this message translates to:
  /// **'Clientes asociados correctamente'**
  String get clientCategoriesAssociateSuccess;

  /// Título del diálogo de cambios sin guardar
  ///
  /// In es, this message translates to:
  /// **'Cambios sin guardar'**
  String get commonUnsavedTitle;

  /// Mensaje del diálogo de cambios sin guardar
  ///
  /// In es, this message translates to:
  /// **'Tienes cambios sin guardar. Si sales ahora, se perderán.'**
  String get commonUnsavedMessage;

  /// Botón para quedarse en la página actual
  ///
  /// In es, this message translates to:
  /// **'Quedarse'**
  String get commonUnsavedStay;

  /// Botón para salir descartando cambios
  ///
  /// In es, this message translates to:
  /// **'Salir sin guardar'**
  String get commonUnsavedLeave;

  /// Placeholder de búsqueda de clientes
  ///
  /// In es, this message translates to:
  /// **'Buscar cliente...'**
  String get clientsSearch;

  /// Botón para añadir clientes desde FacturaDirecta
  ///
  /// In es, this message translates to:
  /// **'Añadir desde Factura Directa'**
  String get clientsAddFromFd;

  /// Mensaje del diálogo de carga mientras se buscan contactos nuevos
  ///
  /// In es, this message translates to:
  /// **'Buscando nuevos contactos en Factura Directa…'**
  String get clientsAddFromFdLoading;

  /// Mensaje del diálogo de carga mientras se añaden clientes
  ///
  /// In es, this message translates to:
  /// **'Añadiendo clientes seleccionados…'**
  String get clientsAddFromFdAdding;

  /// Título del diálogo cuando no hay contactos nuevos
  ///
  /// In es, this message translates to:
  /// **'Todo al día'**
  String get clientsAddFromFdNoNewTitle;

  /// Mensaje cuando no se encuentran contactos nuevos
  ///
  /// In es, this message translates to:
  /// **'Todos los contactos de Factura Directa ya están registrados como clientes.\nNo hay nuevos contactos pendientes de añadir.'**
  String get clientsAddFromFdNoNew;

  /// Botón aceptar del diálogo sin contactos nuevos
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get clientsAddFromFdNoNewOk;

  /// Mensaje de error al buscar o añadir contactos
  ///
  /// In es, this message translates to:
  /// **'Error al obtener contactos de Factura Directa'**
  String get clientsAddFromFdError;

  /// Mensaje de éxito tras añadir clientes
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 cliente añadido correctamente} other{{count} clientes añadidos correctamente}}'**
  String clientsAddFromFdSuccess(int count);

  /// Título del diálogo de selección de contactos
  ///
  /// In es, this message translates to:
  /// **'Seleccionar contactos'**
  String get clientsAddFromFdDialogTitle;

  /// Contador de contactos seleccionados
  ///
  /// In es, this message translates to:
  /// **'{selected} de {total} seleccionados'**
  String clientsAddFromFdSelectedCount(int selected, int total);

  /// Botón para seleccionar todos los contactos
  ///
  /// In es, this message translates to:
  /// **'Seleccionar todos'**
  String get clientsAddFromFdSelectAll;

  /// Botón para deseleccionar todos los contactos
  ///
  /// In es, this message translates to:
  /// **'Deseleccionar todos'**
  String get clientsAddFromFdDeselectAll;

  /// Texto para contactos sin nombre
  ///
  /// In es, this message translates to:
  /// **'(Sin nombre)'**
  String get clientsAddFromFdNoName;

  /// Botón cancelar del diálogo de selección
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get clientsAddFromFdCancel;

  /// Botón confirmar del diálogo de selección
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Añadir} =1{Añadir 1 cliente} other{Añadir {count} clientes}}'**
  String clientsAddFromFdConfirm(int count);

  /// Mensaje cuando no hay clientes
  ///
  /// In es, this message translates to:
  /// **'No se encontraron clientes'**
  String get clientsEmpty;

  /// Cabecera de columna nombre en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get clientsColumnName;

  /// Cabecera de columna nombre de FacturaDirecta en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'Nombre Factura Directa'**
  String get clientsColumnNameFd;

  /// Cabecera de columna NIF/CIF en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'NIF/CIF'**
  String get clientsColumnFiscalId;

  /// Cabecera de columna email en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get clientsColumnEmail;

  /// Cabecera de columna teléfono en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get clientsColumnPhone;

  /// Cabecera de columna ciudad en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'Ciudad'**
  String get clientsColumnCity;

  /// Placeholder de búsqueda de productos
  ///
  /// In es, this message translates to:
  /// **'Buscar producto...'**
  String get productsSearch;

  /// Mensaje cuando no hay productos
  ///
  /// In es, this message translates to:
  /// **'No se encontraron productos'**
  String get productsEmpty;

  /// Cabecera de columna nombre en tabla de productos
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get productsColumnName;

  /// Cabecera de columna precio en tabla de productos
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get productsColumnPrice;

  /// Cabecera de columna activo en tabla de productos
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get productsColumnActive;

  /// Etiqueta para producto inactivo
  ///
  /// In es, this message translates to:
  /// **'Inactivo'**
  String get productsColumnInactive;

  /// Cabecera de columna producto Factura Directa
  ///
  /// In es, this message translates to:
  /// **'Producto Factura Directa'**
  String get productsColumnFdProduct;

  /// Cabecera de columna acciones en tabla de productos
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get productsColumnActions;

  /// Placeholder selector producto FD
  ///
  /// In es, this message translates to:
  /// **'Vincular producto'**
  String get productsSelectFdProduct;

  /// Título del diálogo de selección de producto FD
  ///
  /// In es, this message translates to:
  /// **'Seleccionar producto de Factura Directa'**
  String get productsSelectFdTitle;

  /// Placeholder de búsqueda en selector FD
  ///
  /// In es, this message translates to:
  /// **'Buscar producto...'**
  String get productsSelectFdSearch;

  /// Mensaje vacío en selector FD
  ///
  /// In es, this message translates to:
  /// **'No se encontraron productos en Factura Directa'**
  String get productsSelectFdEmpty;

  /// Error al cargar productos FD
  ///
  /// In es, this message translates to:
  /// **'Error al cargar productos de Factura Directa'**
  String get productsSelectFdError;

  /// Tooltip y botón editar producto
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get productsEdit;

  /// Opción de menú para editar el nombre del producto
  ///
  /// In es, this message translates to:
  /// **'Editar nombre'**
  String get productsEditName;

  /// Opción de menú para cambiar el producto de Factura Directa vinculado
  ///
  /// In es, this message translates to:
  /// **'Modificar producto FD'**
  String get productsModifyFdProduct;

  /// Opción de menú para activar un producto inactivo
  ///
  /// In es, this message translates to:
  /// **'Activar producto'**
  String get productsActivate;

  /// Opción de menú para desactivar un producto activo
  ///
  /// In es, this message translates to:
  /// **'Desactivar producto'**
  String get productsDeactivate;

  /// Tooltip y botón eliminar producto
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get productsDelete;

  /// Título del diálogo de confirmación de eliminación
  ///
  /// In es, this message translates to:
  /// **'Eliminar producto'**
  String get productsDeleteTitle;

  /// Mensaje de confirmación de eliminación de producto
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que quieres eliminar el producto \"{name}\"?\nEsta acción no se puede deshacer.'**
  String productsDeleteMessage(String name);

  /// Validación: nombre de producto vacío
  ///
  /// In es, this message translates to:
  /// **'El nombre es obligatorio'**
  String get productsNameRequired;

  /// Toast tras eliminar producto
  ///
  /// In es, this message translates to:
  /// **'Producto eliminado correctamente'**
  String get productsSuccessDeleted;

  /// Toast tras vincular producto con FD
  ///
  /// In es, this message translates to:
  /// **'Producto vinculado correctamente'**
  String get productsSuccessLinked;

  /// Texto en card cuando el producto no tiene producto FD vinculado
  ///
  /// In es, this message translates to:
  /// **'Producto Factura Directa no vinculado'**
  String get productsNoFdLinked;

  /// Tooltip del botón para desvincular producto de FD
  ///
  /// In es, this message translates to:
  /// **'Desvincular producto FD'**
  String get productsUnlinkFdProduct;

  /// Toast tras desvincular producto de FD
  ///
  /// In es, this message translates to:
  /// **'Producto desvinculado correctamente'**
  String get productsSuccessUnlinked;

  /// Toast de error genérico en operación de producto
  ///
  /// In es, this message translates to:
  /// **'Error al realizar la operación'**
  String get productsErrorOperation;

  /// Botón para añadir un nuevo producto
  ///
  /// In es, this message translates to:
  /// **'Añadir producto'**
  String get productsAdd;

  /// Título del diálogo de nuevo producto
  ///
  /// In es, this message translates to:
  /// **'Nuevo producto'**
  String get productsAddTitle;

  /// Toast tras crear un producto
  ///
  /// In es, this message translates to:
  /// **'Producto creado correctamente'**
  String get productsSuccessCreated;

  /// Toast tras guardar cambios en lote de productos
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados correctamente'**
  String get productsSuccessSaved;

  /// Mensaje de progreso al guardar campo de producto
  ///
  /// In es, this message translates to:
  /// **'Guardando cambios...'**
  String get productsSaving;

  /// Mensaje de error al guardar campo de producto
  ///
  /// In es, this message translates to:
  /// **'Error al guardar los cambios'**
  String get productsErrorSaving;

  /// Botón para abrir el diálogo de reordenación de productos
  ///
  /// In es, this message translates to:
  /// **'Reordenar productos'**
  String get productsReorder;

  /// Título del diálogo de reordenación de productos
  ///
  /// In es, this message translates to:
  /// **'Ordenar productos'**
  String get productsReorderTitle;

  /// Subtítulo del diálogo de reordenación de productos
  ///
  /// In es, this message translates to:
  /// **'Arrastra los productos para cambiar su orden'**
  String get productsReorderSubtitle;

  /// Toast tras guardar el nuevo orden de productos
  ///
  /// In es, this message translates to:
  /// **'Orden actualizado correctamente'**
  String get productsReorderSaved;

  /// Placeholder de búsqueda de facturas
  ///
  /// In es, this message translates to:
  /// **'Buscar factura...'**
  String get invoicesSearchClient;

  /// Mensaje cuando no hay facturas
  ///
  /// In es, this message translates to:
  /// **'No se encontraron facturas'**
  String get invoicesEmpty;

  /// Cabecera de columna número en tabla de facturas
  ///
  /// In es, this message translates to:
  /// **'Nº Factura'**
  String get invoicesColumnNumber;

  /// Cabecera de columna cliente en tabla de facturas
  ///
  /// In es, this message translates to:
  /// **'Cliente'**
  String get invoicesColumnClient;

  /// Cabecera de columna fecha en tabla de facturas
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get invoicesColumnDate;

  /// Cabecera de columna total en tabla de facturas
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get invoicesColumnTotal;

  /// Cabecera de columna subtotal en tabla de facturas
  ///
  /// In es, this message translates to:
  /// **'Subtotal'**
  String get invoicesColumnSubtotal;

  /// Cabecera de columna estado en tabla de facturas
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get invoicesColumnStatus;

  /// Número de facturas seleccionadas en la barra de acciones
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 factura seleccionada} other{{count} facturas seleccionadas}}'**
  String invoicesSelectedCount(int count);

  /// Acción para convertir facturas provisionales en definitivas
  ///
  /// In es, this message translates to:
  /// **'Convertir definitiva'**
  String get invoicesActionConvertDefinitive;

  /// Mensaje cuando las facturas seleccionadas no permiten acciones
  ///
  /// In es, this message translates to:
  /// **'No hay opciones disponibles'**
  String get invoicesNoActionsAvailable;

  /// Texto del botón de filtrar facturas
  ///
  /// In es, this message translates to:
  /// **'Filtrar'**
  String get invoicesFilter;

  /// Título del diálogo de filtros de facturas
  ///
  /// In es, this message translates to:
  /// **'Filtros'**
  String get invoicesFilterTitle;

  /// Label de sección estado en filtros
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get invoicesFilterStatus;

  /// Label de sección clientes en filtros
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get invoicesFilterClients;

  /// Label del campo fecha desde en filtros
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get invoicesFilterDateFrom;

  /// Label del campo fecha hasta en filtros
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get invoicesFilterDateTo;

  /// Texto del botón aplicar filtros
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get invoicesFilterApply;

  /// Texto del botón limpiar todos los filtros
  ///
  /// In es, this message translates to:
  /// **'Limpiar filtros'**
  String get invoicesFilterClear;

  /// Error de validación de rango de fechas
  ///
  /// In es, this message translates to:
  /// **'Fecha desde debe ser anterior a fecha hasta'**
  String get invoicesFilterDateError;

  /// Placeholder del campo buscar cliente en filtros
  ///
  /// In es, this message translates to:
  /// **'Buscar cliente...'**
  String get invoicesFilterSearchClients;

  /// Texto del botón cargar más facturas
  ///
  /// In es, this message translates to:
  /// **'Cargar más'**
  String get invoicesLoadMore;

  /// Texto del botón cancelar en filtros
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get invoicesFilterCancel;

  /// Título de la página de detalle de factura
  ///
  /// In es, this message translates to:
  /// **'Detalle de factura'**
  String get invoiceDetailTitle;

  /// Etiqueta de fecha en detalle de factura
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get invoiceDetailDate;

  /// Etiqueta de cliente en detalle de factura
  ///
  /// In es, this message translates to:
  /// **'Cliente'**
  String get invoiceDetailClient;

  /// Etiqueta de moneda en detalle de factura
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get invoiceDetailCurrency;

  /// Título de la sección de líneas de factura
  ///
  /// In es, this message translates to:
  /// **'Líneas de factura'**
  String get invoiceDetailLines;

  /// Cabecera de columna descripción en líneas
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get invoiceDetailLineDescription;

  /// Cabecera de columna cantidad en líneas
  ///
  /// In es, this message translates to:
  /// **'Cantidad'**
  String get invoiceDetailLineQuantity;

  /// Cabecera de columna precio unitario en líneas
  ///
  /// In es, this message translates to:
  /// **'Precio ud.'**
  String get invoiceDetailLinePrice;

  /// Cabecera de columna IVA en líneas
  ///
  /// In es, this message translates to:
  /// **'IVA'**
  String get invoiceDetailLineTax;

  /// Cabecera de columna total en líneas
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get invoiceDetailLineTotal;

  /// Mensaje cuando la factura no tiene líneas
  ///
  /// In es, this message translates to:
  /// **'No hay líneas en esta factura'**
  String get invoiceDetailNoLines;

  /// Etiqueta de subtotal en detalle de factura
  ///
  /// In es, this message translates to:
  /// **'Subtotal'**
  String get invoiceDetailSubtotal;

  /// Etiqueta de sección de desglose de impuestos
  ///
  /// In es, this message translates to:
  /// **'Impuestos'**
  String get invoiceDetailTaxBreakdown;

  /// Etiqueta columna base imponible en desglose de impuestos
  ///
  /// In es, this message translates to:
  /// **'Base imponible'**
  String get invoiceDetailTaxBase;

  /// Etiqueta columna cuota en desglose de impuestos
  ///
  /// In es, this message translates to:
  /// **'Cuota'**
  String get invoiceDetailTaxAmount;

  /// Etiqueta de total en detalle de factura
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get invoiceDetailTotal;

  /// Texto del botón volver al listado de facturas
  ///
  /// In es, this message translates to:
  /// **'Volver a facturas'**
  String get invoiceDetailGoBack;

  /// Etiqueta del selector de filas por página
  ///
  /// In es, this message translates to:
  /// **'Filas por página:'**
  String get paginationRowsPerPage;

  /// Rango de paginación
  ///
  /// In es, this message translates to:
  /// **'{start}–{end} de {total}'**
  String paginationRange(int start, int end, int total);

  /// Error: configuración de FacturaDirecta no encontrada
  ///
  /// In es, this message translates to:
  /// **'Configura tu cuenta de FacturaDirecta en Ajustes'**
  String get fdConfigNotFound;

  /// Error de red al conectar con FacturaDirecta
  ///
  /// In es, this message translates to:
  /// **'Error de conexión. Verifica tu red'**
  String get fdNetworkError;

  /// Error del servidor de FacturaDirecta
  ///
  /// In es, this message translates to:
  /// **'Error del servidor. Inténtalo más tarde'**
  String get fdServerError;

  /// Error desconocido de FacturaDirecta
  ///
  /// In es, this message translates to:
  /// **'Error inesperado'**
  String get fdUnknownError;

  /// Botón de reintentar
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get fdRetry;

  /// Cabecera de columna categoría en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get clientsColumnCategory;

  /// Texto cuando un cliente no tiene categoría asignada
  ///
  /// In es, this message translates to:
  /// **'Categoría no asignada'**
  String get clientsCategoryUnspecified;

  /// Título del diálogo para seleccionar categoría de cliente
  ///
  /// In es, this message translates to:
  /// **'Seleccionar categoría'**
  String get clientsSelectCategory;

  /// Placeholder del buscador en el selector de categoría
  ///
  /// In es, this message translates to:
  /// **'Buscar categoría...'**
  String get clientsSelectCategorySearch;

  /// Mensaje cuando no hay categorías
  ///
  /// In es, this message translates to:
  /// **'No hay categorías disponibles'**
  String get clientsSelectCategoryEmpty;

  /// Botón para restablecer los pedidos de los clientes seleccionados
  ///
  /// In es, this message translates to:
  /// **'Restablecer pedidos'**
  String get ordersTodayResetOrders;

  /// Botón para añadir cliente o producto
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get ordersTodayAdd;

  /// Opción del menú para añadir un cliente
  ///
  /// In es, this message translates to:
  /// **'Añadir cliente'**
  String get ordersTodayAddClient;

  /// Opción del menú para añadir un producto
  ///
  /// In es, this message translates to:
  /// **'Añadir producto'**
  String get ordersTodayAddProduct;

  /// Título del diálogo para seleccionar clientes a añadir
  ///
  /// In es, this message translates to:
  /// **'Añadir clientes'**
  String get ordersTodayAddClientDialogTitle;

  /// Título del diálogo para seleccionar productos a añadir
  ///
  /// In es, this message translates to:
  /// **'Añadir productos'**
  String get ordersTodayAddProductDialogTitle;

  /// Mensaje cuando no hay elementos disponibles para añadir
  ///
  /// In es, this message translates to:
  /// **'Todos los elementos activos ya están en el pedido'**
  String get ordersTodayAddDialogEmpty;

  /// Placeholder del campo de búsqueda en el diálogo de añadir
  ///
  /// In es, this message translates to:
  /// **'Buscar...'**
  String get ordersTodayAddDialogSearch;

  /// Cabecera de la columna de nombre en el diálogo de añadir
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get ordersTodayAddDialogColumnName;

  /// Mensaje cuando la búsqueda no encuentra coincidencias
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get ordersTodayAddDialogNoResults;

  /// Botón de confirmar en el diálogo de añadir con contador
  ///
  /// In es, this message translates to:
  /// **'Añadir ({count})'**
  String ordersTodayAddDialogConfirm(int count);

  /// Botón desplegable para exportar pedidos
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get ordersTodayExport;

  /// Botón para quitar clientes seleccionados de la tabla
  ///
  /// In es, this message translates to:
  /// **'Quitar de la tabla'**
  String get ordersTodayRemoveFromTable;

  /// Título del diálogo de confirmación para quitar productos
  ///
  /// In es, this message translates to:
  /// **'Quitar productos'**
  String get ordersTodayDeleteProductsConfirmTitle;

  /// Mensaje del diálogo de confirmación para quitar productos
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{¿Quitar el producto seleccionado de la tabla?\nEsta acción no se puede deshacer.} other{¿Quitar los {count} productos seleccionados de la tabla?\nEsta acción no se puede deshacer.}}'**
  String ordersTodayDeleteProductsConfirmMessage(int count);

  /// Título del diálogo de confirmación para restablecer pedidos
  ///
  /// In es, this message translates to:
  /// **'Restablecer pedidos'**
  String get ordersTodayResetConfirmTitle;

  /// Mensaje del diálogo de confirmación para restablecer pedidos
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{¿Restablecer los pedidos del cliente seleccionado? Los valores se pondrán a cero.} other{¿Restablecer los pedidos de los {count} clientes seleccionados? Los valores se pondrán a cero.}}'**
  String ordersTodayResetConfirmMessage(int count);

  /// Botón de confirmar restablecimiento en el diálogo
  ///
  /// In es, this message translates to:
  /// **'Restablecer'**
  String get ordersTodayResetConfirm;

  /// Título de la sección de identidad de usuario en ajustes
  ///
  /// In es, this message translates to:
  /// **'Identidad de usuario'**
  String get settingsUserIdentityTitle;

  /// Descripción de la sección de identidad de usuario
  ///
  /// In es, this message translates to:
  /// **'Este nombre identifica tus acciones cuando varios usuarios trabajan simultáneamente en los pedidos del día.'**
  String get settingsUserIdentityDescription;

  /// Label del campo de nombre de usuario
  ///
  /// In es, this message translates to:
  /// **'Nombre de usuario'**
  String get settingsUserNameLabel;

  /// Mensaje cuando una celda está bloqueada por otro usuario
  ///
  /// In es, this message translates to:
  /// **'Celda bloqueada por {user}'**
  String ordersTodayCellLocked(String user);

  /// Indicador de usuarios conectados en pedidos de hoy
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin usuarios} =1{1 usuario conectado} other{{count} usuarios conectados}}'**
  String ordersTodayConnectedUsers(int count);

  /// Estado de factura: pagada
  ///
  /// In es, this message translates to:
  /// **'Pagada'**
  String get invoiceStatusPaid;

  /// Estado de factura: pendiente
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get invoiceStatusPending;

  /// Estado de factura: vencida
  ///
  /// In es, this message translates to:
  /// **'Vencida'**
  String get invoiceStatusOverdue;

  /// Estado de factura: provisional
  ///
  /// In es, this message translates to:
  /// **'Provisional'**
  String get invoiceStatusDraft;

  /// Estado de factura: anulada
  ///
  /// In es, this message translates to:
  /// **'Anulada'**
  String get invoiceStatusVoided;

  /// Estado de factura: sobrepagada
  ///
  /// In es, this message translates to:
  /// **'Sobrepagada'**
  String get invoiceStatusOverpaid;

  /// Título del panel de navegación en historial de pedidos
  ///
  /// In es, this message translates to:
  /// **'Navegación'**
  String get ordersHistoryNavigation;

  /// Subtítulo del diálogo de vinculación de producto FD
  ///
  /// In es, this message translates to:
  /// **'Para vincular a: {productName}'**
  String productsLinkDialogSubtitle(String productName);

  /// Placeholder en la tabla de pedidos cuando no hay clientes
  ///
  /// In es, this message translates to:
  /// **'No hay clientes añadidos'**
  String get ordersTodayNoClients;

  /// Hint debajo del placeholder de no clientes indicando cómo añadir uno
  ///
  /// In es, this message translates to:
  /// **'Pulsa el botón + de la cabecera para añadir clientes.'**
  String get ordersTodayNoClientsHint;

  /// Opción del menú contextual para marcar una celda como compensación
  ///
  /// In es, this message translates to:
  /// **'Marcar como compensación'**
  String get ordersTodayMarkCompensation;

  /// Opción del menú contextual para desmarcar una celda como compensación
  ///
  /// In es, this message translates to:
  /// **'Desmarcar como compensación'**
  String get ordersTodayUnmarkCompensation;

  /// Opción del menú contextual para marcar una celda como reserva
  ///
  /// In es, this message translates to:
  /// **'Marcar como reserva'**
  String get ordersTodayMarkReservation;

  /// Opción del menú contextual para desmarcar una celda como reserva
  ///
  /// In es, this message translates to:
  /// **'Desmarcar como reserva'**
  String get ordersTodayUnmarkReservation;

  /// Opción del menú contextual para marcar stock estricto
  ///
  /// In es, this message translates to:
  /// **'Marcar como stock estricto'**
  String get ordersTodayMarkStrictStock;

  /// Opción del menú contextual para desmarcar stock estricto
  ///
  /// In es, this message translates to:
  /// **'Desmarcar como stock estricto'**
  String get ordersTodayUnmarkStrictStock;

  /// Tooltip para celda marcada como compensación
  ///
  /// In es, this message translates to:
  /// **'Compensación'**
  String get ordersTodayTooltipCompensation;

  /// Tooltip para celda marcada como reserva
  ///
  /// In es, this message translates to:
  /// **'Reserva'**
  String get ordersTodayTooltipReservation;

  /// Tooltip para celda marcada como stock estricto
  ///
  /// In es, this message translates to:
  /// **'Stock estricto'**
  String get ordersTodayTooltipStrictStock;

  /// Opción del menú contextual para añadir nota a una celda
  ///
  /// In es, this message translates to:
  /// **'Añadir nota'**
  String get ordersTodayAddNote;

  /// Opción del menú contextual para editar nota existente
  ///
  /// In es, this message translates to:
  /// **'Editar nota'**
  String get ordersTodayEditNote;

  /// Opción del menú contextual para eliminar nota de una celda
  ///
  /// In es, this message translates to:
  /// **'Eliminar nota'**
  String get ordersTodayRemoveNote;

  /// Título del diálogo para añadir o editar nota
  ///
  /// In es, this message translates to:
  /// **'Nota'**
  String get ordersTodayNoteDialogTitle;

  /// Hint del campo de texto en el diálogo de nota
  ///
  /// In es, this message translates to:
  /// **'Escribe una nota (máx. 100 caracteres)'**
  String get ordersTodayNoteDialogHint;

  /// Botón de guardar en el diálogo de nota
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get ordersTodayNoteDialogSave;

  /// Botón de cancelar en el diálogo de nota
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get ordersTodayNoteDialogCancel;

  /// Opción del menú contextual para añadir abono
  ///
  /// In es, this message translates to:
  /// **'Añadir abono'**
  String get ordersTodayAddRefund;

  /// Opción del menú contextual para editar abono existente
  ///
  /// In es, this message translates to:
  /// **'Editar abono'**
  String get ordersTodayEditRefund;

  /// Opción del menú contextual para eliminar abono
  ///
  /// In es, this message translates to:
  /// **'Eliminar abono'**
  String get ordersTodayRemoveRefund;

  /// Título del diálogo de abono
  ///
  /// In es, this message translates to:
  /// **'Abono'**
  String get ordersTodayRefundDialogTitle;

  /// Label del campo de texto en el diálogo de abono
  ///
  /// In es, this message translates to:
  /// **'Cantidad de productos'**
  String get ordersTodayRefundDialogLabel;

  /// Tooltip para celda con abono
  ///
  /// In es, this message translates to:
  /// **'Abono'**
  String get ordersTodayTooltipRefund;

  /// Opción del menú contextual de cliente para generar hoja de pedido
  ///
  /// In es, this message translates to:
  /// **'Generar hoja de pedido'**
  String get ordersTodayContextMenuGenerateOrderSheet;

  /// Mensaje cuando se intenta generar hoja de pedido de un cliente sin productos
  ///
  /// In es, this message translates to:
  /// **'Este cliente no tiene productos con cantidad asignada.'**
  String get ordersTodayGenerateOrderSheetEmpty;

  /// Opción del menú contextual de cliente para generar factura provisional (deshabilitada)
  ///
  /// In es, this message translates to:
  /// **'Generar factura provisional'**
  String get ordersTodayContextMenuGenerateProvisionalInvoice;

  /// Opción del menú contextual de cliente para añadir una nota de cliente
  ///
  /// In es, this message translates to:
  /// **'Añadir nota'**
  String get ordersTodayContextMenuAddClientNote;

  /// Opción del menú contextual de cliente para editar una nota de cliente existente
  ///
  /// In es, this message translates to:
  /// **'Editar nota'**
  String get ordersTodayContextMenuEditClientNote;

  /// Opción del menú contextual de cliente para eliminar una nota de cliente
  ///
  /// In es, this message translates to:
  /// **'Eliminar nota'**
  String get ordersTodayContextMenuDeleteClientNote;

  /// Título del diálogo de nota de cliente
  ///
  /// In es, this message translates to:
  /// **'Nota de cliente'**
  String get ordersTodayClientNoteDialogTitle;

  /// Hint del campo de texto en el diálogo de nota de cliente
  ///
  /// In es, this message translates to:
  /// **'Escribe una nota (máx. 200 caracteres)'**
  String get ordersTodayClientNoteDialogHint;

  /// Opción del menú contextual de cliente para cambiar el cliente de la columna
  ///
  /// In es, this message translates to:
  /// **'Cambiar cliente'**
  String get ordersTodayContextMenuChangeClient;

  /// Título del diálogo para seleccionar el nuevo cliente
  ///
  /// In es, this message translates to:
  /// **'Cambiar cliente'**
  String get ordersTodayChangeClientDialogTitle;

  /// Botón de confirmación en el diálogo de cambiar cliente
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get ordersTodayChangeClientDialogConfirm;

  /// Opción del menú contextual de cliente para restablecer pedido
  ///
  /// In es, this message translates to:
  /// **'Restablecer pedido'**
  String get ordersTodayContextMenuResetOrder;

  /// Opción del menú contextual de cliente para eliminar cliente
  ///
  /// In es, this message translates to:
  /// **'Eliminar cliente'**
  String get ordersTodayContextMenuDeleteClient;

  /// Opción del menú contextual de producto para eliminar producto
  ///
  /// In es, this message translates to:
  /// **'Eliminar producto'**
  String get ordersTodayContextMenuDeleteProduct;

  /// Título del diálogo de ayuda informativa de la tabla de pedidos
  ///
  /// In es, this message translates to:
  /// **'Ayuda de la tabla de pedidos'**
  String get ordersTodayInfoDialogTitle;

  /// Botón para cerrar el diálogo de ayuda informativa
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get ordersTodayInfoDialogClose;

  /// Título de la acción añadir cliente en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Añadir un cliente'**
  String get ordersTodayInfoAddClientTitle;

  /// Descripción de la acción añadir cliente en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Pulsa el botón «+ Añadir cliente» en la parte superior derecha de la tabla.'**
  String get ordersTodayInfoAddClientDesc;

  /// Título de la acción añadir producto en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Añadir un producto'**
  String get ordersTodayInfoAddProductTitle;

  /// Descripción de la acción añadir producto en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Pulsa el botón «+ Añadir producto» en la parte inferior izquierda de la tabla.'**
  String get ordersTodayInfoAddProductDesc;

  /// Título de la acción modificar stock en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Modificar el stock'**
  String get ordersTodayInfoEditStockTitle;

  /// Descripción de la acción modificar stock en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic sobre la celda de la columna STOCKS del producto que deseas modificar e introduce el nuevo valor.'**
  String get ordersTodayInfoEditStockDesc;

  /// Título de la acción stock estricto en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Poner stock como estricto'**
  String get ordersTodayInfoStrictStockTitle;

  /// Descripción de la acción stock estricto en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic derecho (o mantén pulsado en tablet) sobre la celda de stock de un producto y selecciona «Marcar stock estricto» en el menú contextual.'**
  String get ordersTodayInfoStrictStockDesc;

  /// Título de la acción asignar cantidad en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Asignar cantidad a un cliente'**
  String get ordersTodayInfoAssignQtyTitle;

  /// Descripción de la acción asignar cantidad en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic sobre la celda en la intersección del producto y el cliente, e introduce la cantidad deseada. Usa las flechas del teclado o Tab para moverte entre celdas.'**
  String get ordersTodayInfoAssignQtyDesc;

  /// Título de la acción compensación en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Marcar compensación'**
  String get ordersTodayInfoCompensationTitle;

  /// Descripción de la acción compensación en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic derecho (o mantén pulsado en tablet) sobre una celda de cantidad de un cliente y selecciona «Marcar compensación» en el menú contextual.'**
  String get ordersTodayInfoCompensationDesc;

  /// Título de la acción reserva en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Marcar reserva'**
  String get ordersTodayInfoReservationTitle;

  /// Descripción de la acción reserva en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic derecho (o mantén pulsado en tablet) sobre una celda de cantidad de un cliente y selecciona «Marcar reserva» en el menú contextual.'**
  String get ordersTodayInfoReservationDesc;

  /// Título de la acción quitar cliente en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Quitar un cliente'**
  String get ordersTodayInfoRemoveClientTitle;

  /// Descripción de la acción quitar cliente en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic derecho (o mantén pulsado en tablet) sobre el nombre del cliente en la cabecera de la tabla y selecciona «Eliminar cliente» en el menú contextual.'**
  String get ordersTodayInfoRemoveClientDesc;

  /// Título de la acción quitar producto en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Quitar un producto'**
  String get ordersTodayInfoRemoveProductTitle;

  /// Descripción de la acción quitar producto en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic derecho (o mantén pulsado en tablet) sobre el nombre del producto en la columna izquierda y selecciona «Eliminar producto» en el menú contextual.'**
  String get ordersTodayInfoRemoveProductDesc;

  /// Título de la acción restablecer pedido en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Restablecer pedido de un cliente'**
  String get ordersTodayInfoResetOrderTitle;

  /// Descripción de la acción restablecer pedido en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic derecho (o mantén pulsado en tablet) sobre el nombre del cliente en la cabecera y selecciona «Restablecer pedido» en el menú contextual. Esto pondrá a cero todas las cantidades de ese cliente.'**
  String get ordersTodayInfoResetOrderDesc;

  /// Título de la acción generar hoja de pedido en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Generar hoja de pedido'**
  String get ordersTodayInfoOrderSheetTitle;

  /// Descripción de la acción generar hoja de pedido en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic derecho (o mantén pulsado en tablet) sobre el nombre del cliente en la cabecera y selecciona «Generar hoja de pedido». Genera un documento con las cantidades de productos solicitadas por el cliente, útil para que los trabajadores preparen el pedido.'**
  String get ordersTodayInfoOrderSheetDesc;

  /// Título de la acción generar factura provisional en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Generar factura provisional'**
  String get ordersTodayInfoProvisionalInvoiceTitle;

  /// Descripción de la acción generar factura provisional en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic derecho (o mantén pulsado en tablet) sobre el nombre del cliente en la cabecera y selecciona «Generar factura provisional». Crea la factura en estado provisional en Factura Directa con los productos y cantidades del pedido del cliente.'**
  String get ordersTodayInfoProvisionalInvoiceDesc;

  /// Título de la acción crear nota en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Crear una nota en una celda'**
  String get ordersTodayInfoCellNoteTitle;

  /// Descripción de la acción crear nota en el diálogo de ayuda
  ///
  /// In es, this message translates to:
  /// **'Haz clic derecho (o mantén pulsado en tablet) sobre una celda de cantidad de un cliente y selecciona «Añadir nota». La nota se mostrará como un indicador en la celda y podrás verla al pasar el cursor por encima. Para editarla o eliminarla, vuelve a abrir el menú sobre la misma celda.'**
  String get ordersTodayInfoCellNoteDesc;

  /// Mensaje mostrado durante la animación de auto-creación del documento de pedidos del día
  ///
  /// In es, this message translates to:
  /// **'Preparando plantilla para pedidos de hoy…'**
  String get ordersTodayPreparingTemplate;

  /// Mensaje de carga mientras se prepara la preview de factura
  ///
  /// In es, this message translates to:
  /// **'Preparando factura provisional…'**
  String get provisionalInvoiceLoading;

  /// Título del diálogo de preview de factura provisional
  ///
  /// In es, this message translates to:
  /// **'Vista previa de factura provisional'**
  String get provisionalInvoicePreviewTitle;

  /// Badge que indica que la factura es provisional
  ///
  /// In es, this message translates to:
  /// **'PROVISIONAL'**
  String get provisionalInvoiceDraftBadge;

  /// Aviso de factura provisional duplicada
  ///
  /// In es, this message translates to:
  /// **'Ya existe una factura provisional para este cliente en esta fecha. Si continúas, se creará otra factura provisional.'**
  String get provisionalInvoiceDuplicateWarning;

  /// Cabecera columna producto en tabla de preview
  ///
  /// In es, this message translates to:
  /// **'Producto'**
  String get provisionalInvoiceProduct;

  /// Cabecera columna cantidad en tabla de preview
  ///
  /// In es, this message translates to:
  /// **'Ud.'**
  String get provisionalInvoiceQty;

  /// Cabecera columna precio en tabla de preview
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get provisionalInvoicePrice;

  /// Cabecera columna impuesto en tabla de preview
  ///
  /// In es, this message translates to:
  /// **'IVA'**
  String get provisionalInvoiceTax;

  /// Cabecera columna total de línea en tabla de preview
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get provisionalInvoiceLineTotal;

  /// Etiqueta subtotal en resumen de factura
  ///
  /// In es, this message translates to:
  /// **'Subtotal'**
  String get provisionalInvoiceSubtotal;

  /// Cabecera columna impuesto en tabla de desglose fiscal
  ///
  /// In es, this message translates to:
  /// **'Impuesto'**
  String get provisionalInvoiceTaxHeader;

  /// Cabecera columna base imponible en tabla de desglose fiscal
  ///
  /// In es, this message translates to:
  /// **'Base imponible'**
  String get provisionalInvoiceTaxBase;

  /// Cabecera columna cuota en tabla de desglose fiscal
  ///
  /// In es, this message translates to:
  /// **'Cuota'**
  String get provisionalInvoiceTaxAmount;

  /// Etiqueta de la sección de notas en la preview de factura
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get provisionalInvoiceNotesLabel;

  /// Etiqueta total final en resumen de factura
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get provisionalInvoiceTotal;

  /// Botón cancelar en diálogo de factura provisional
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get provisionalInvoiceCancel;

  /// Botón confirmar en diálogo de factura provisional
  ///
  /// In es, this message translates to:
  /// **'Generar factura provisional'**
  String get provisionalInvoiceConfirm;

  /// Título del mensaje de éxito al crear factura
  ///
  /// In es, this message translates to:
  /// **'Factura provisional creada'**
  String get provisionalInvoiceSuccessTitle;

  /// Mensaje de éxito con número de documento
  ///
  /// In es, this message translates to:
  /// **'La factura provisional {docNumber} se ha creado correctamente en Factura Directa.'**
  String provisionalInvoiceSuccessMessage(String docNumber);

  /// Botón cerrar en diálogo de factura provisional
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get provisionalInvoiceClose;

  /// Título del diálogo de error de factura provisional
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get provisionalInvoiceErrorTitle;

  /// Error cuando no hay config de FD
  ///
  /// In es, this message translates to:
  /// **'No se ha configurado Factura Directa. Ve a Ajustes para configurarla.'**
  String get provisionalInvoiceErrorConfigNotFound;

  /// Error cuando el cliente no tiene UUID de FD
  ///
  /// In es, this message translates to:
  /// **'Este cliente no está vinculado a Factura Directa. Vincúlalo desde la sección Clientes.'**
  String get provisionalInvoiceErrorClientNotLinked;

  /// Error cuando hay productos sin vincular a FD
  ///
  /// In es, this message translates to:
  /// **'Los siguientes productos no están vinculados a Factura Directa. Vincúlalos desde la sección Productos:'**
  String get provisionalInvoiceErrorProductsNotLinked;

  /// Error cuando un producto local vinculado no existe en la API de FD
  ///
  /// In es, this message translates to:
  /// **'Un producto vinculado no se ha encontrado en Factura Directa. Puede haber sido eliminado.'**
  String get provisionalInvoiceErrorProductNotFoundInFd;

  /// Error cuando no hay líneas para facturar
  ///
  /// In es, this message translates to:
  /// **'No hay productos con cantidad para este cliente.'**
  String get provisionalInvoiceErrorNoLines;

  /// Error de red al conectar con FD
  ///
  /// In es, this message translates to:
  /// **'No se ha podido conectar con Factura Directa. Comprueba tu conexión a internet.'**
  String get provisionalInvoiceErrorNetwork;

  /// Error del servidor FD
  ///
  /// In es, this message translates to:
  /// **'Error del servidor de Factura Directa. Inténtalo de nuevo más tarde.'**
  String get provisionalInvoiceErrorServer;

  /// Error desconocido
  ///
  /// In es, this message translates to:
  /// **'Se ha producido un error inesperado. Inténtalo de nuevo.'**
  String get provisionalInvoiceErrorUnknown;

  /// Encabezado de la fecha actual en el dashboard
  ///
  /// In es, this message translates to:
  /// **'Hoy,'**
  String get dashboardToday;

  /// Día de la semana: lunes
  ///
  /// In es, this message translates to:
  /// **'Lunes'**
  String get weekdayMonday;

  /// Día de la semana: martes
  ///
  /// In es, this message translates to:
  /// **'Martes'**
  String get weekdayTuesday;

  /// Día de la semana: miércoles
  ///
  /// In es, this message translates to:
  /// **'Miércoles'**
  String get weekdayWednesday;

  /// Día de la semana: jueves
  ///
  /// In es, this message translates to:
  /// **'Jueves'**
  String get weekdayThursday;

  /// Día de la semana: viernes
  ///
  /// In es, this message translates to:
  /// **'Viernes'**
  String get weekdayFriday;

  /// Día de la semana: sábado
  ///
  /// In es, this message translates to:
  /// **'Sábado'**
  String get weekdaySaturday;

  /// Día de la semana: domingo
  ///
  /// In es, this message translates to:
  /// **'Domingo'**
  String get weekdaySunday;

  /// Mes: enero
  ///
  /// In es, this message translates to:
  /// **'enero'**
  String get monthJanuary;

  /// Mes: febrero
  ///
  /// In es, this message translates to:
  /// **'febrero'**
  String get monthFebruary;

  /// Mes: marzo
  ///
  /// In es, this message translates to:
  /// **'marzo'**
  String get monthMarch;

  /// Mes: abril
  ///
  /// In es, this message translates to:
  /// **'abril'**
  String get monthApril;

  /// Mes: mayo
  ///
  /// In es, this message translates to:
  /// **'mayo'**
  String get monthMay;

  /// Mes: junio
  ///
  /// In es, this message translates to:
  /// **'junio'**
  String get monthJune;

  /// Mes: julio
  ///
  /// In es, this message translates to:
  /// **'julio'**
  String get monthJuly;

  /// Mes: agosto
  ///
  /// In es, this message translates to:
  /// **'agosto'**
  String get monthAugust;

  /// Mes: septiembre
  ///
  /// In es, this message translates to:
  /// **'septiembre'**
  String get monthSeptember;

  /// Mes: octubre
  ///
  /// In es, this message translates to:
  /// **'octubre'**
  String get monthOctober;

  /// Mes: noviembre
  ///
  /// In es, this message translates to:
  /// **'noviembre'**
  String get monthNovember;

  /// Mes: diciembre
  ///
  /// In es, this message translates to:
  /// **'diciembre'**
  String get monthDecember;

  /// Formato de fecha en el dashboard
  ///
  /// In es, this message translates to:
  /// **'{day} de {month}'**
  String dashboardDateFormat(int day, String month);

  /// Título del diálogo de edición de categoría de clientes
  ///
  /// In es, this message translates to:
  /// **'Editar categoría'**
  String get clientCategoriesEditTitle;

  /// Cabecera de columna color en tabla de categorías de clientes
  ///
  /// In es, this message translates to:
  /// **'Color'**
  String get clientCategoriesColumnColor;

  /// Cabecera de columna de clientes asociados en tabla de categorías
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get clientCategoriesColumnAssociatedClients;

  /// Etiqueta del selector de color en diálogos de categorías
  ///
  /// In es, this message translates to:
  /// **'Color de categoría'**
  String get clientCategoriesColorLabel;

  /// Botón para editar un cliente
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get clientsEdit;

  /// Título de la vista de edición de un cliente
  ///
  /// In es, this message translates to:
  /// **'Editar cliente'**
  String get clientsEditTitle;

  /// Cabecera de columna métodos de envío en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'Métodos de envío'**
  String get clientsColumnShippingMethods;

  /// Cabecera de columna provincia en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'Provincia'**
  String get clientsColumnProvince;

  /// Cabecera de columna país en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'País'**
  String get clientsColumnCountry;

  /// Cabecera de columna método de cobro en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'Método de cobro'**
  String get clientsColumnPaymentMethod;

  /// Cabecera de columna moneda en tabla de clientes
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get clientsColumnCurrency;

  /// Título del AppBar en la vista de detalle de cliente en mobile
  ///
  /// In es, this message translates to:
  /// **'Detalle de cliente'**
  String get clientsDetailTitle;

  /// Título de la sección de datos del cliente en el detalle de cliente
  ///
  /// In es, this message translates to:
  /// **'Datos del cliente'**
  String get clientsClientDataSection;

  /// Título de la sección de datos de Factura Directa en el detalle de cliente
  ///
  /// In es, this message translates to:
  /// **'Datos de Factura Directa'**
  String get clientsFdDataSection;

  /// Título del diálogo de métodos de envío por día
  ///
  /// In es, this message translates to:
  /// **'Métodos de envío'**
  String get clientsShippingMethodsTitle;

  /// Subtítulo del diálogo de métodos de envío por día
  ///
  /// In es, this message translates to:
  /// **'Asigna un método de envío por día'**
  String get clientsShippingMethodsSubtitle;

  /// Día de la semana: lunes (abreviado/corto)
  ///
  /// In es, this message translates to:
  /// **'Lunes'**
  String get dayMonday;

  /// Día de la semana: martes (abreviado/corto)
  ///
  /// In es, this message translates to:
  /// **'Martes'**
  String get dayTuesday;

  /// Día de la semana: miércoles (abreviado/corto)
  ///
  /// In es, this message translates to:
  /// **'Miércoles'**
  String get dayWednesday;

  /// Día de la semana: jueves (abreviado/corto)
  ///
  /// In es, this message translates to:
  /// **'Jueves'**
  String get dayThursday;

  /// Día de la semana: viernes (abreviado/corto)
  ///
  /// In es, this message translates to:
  /// **'Viernes'**
  String get dayFriday;

  /// Día de la semana: sábado (abreviado/corto)
  ///
  /// In es, this message translates to:
  /// **'Sábado'**
  String get daySaturday;

  /// Día de la semana: domingo (abreviado/corto)
  ///
  /// In es, this message translates to:
  /// **'Domingo'**
  String get daySunday;

  /// Opción sin método de envío asignado en el selector por día
  ///
  /// In es, this message translates to:
  /// **'Sin método'**
  String get clientsShippingMethodNone;

  /// Texto mostrado cuando un día no tiene método de envío asignado
  ///
  /// In es, this message translates to:
  /// **'Sin definir'**
  String get clientsShippingMethodUndefined;

  /// Ítem de menú: Métodos de envío
  ///
  /// In es, this message translates to:
  /// **'Métodos de envío'**
  String get menuShippingMethods;

  /// Placeholder de búsqueda de métodos de envío
  ///
  /// In es, this message translates to:
  /// **'Buscar método de envío...'**
  String get shippingMethodsSearch;

  /// Botón para añadir un nuevo método de envío
  ///
  /// In es, this message translates to:
  /// **'Añadir método'**
  String get shippingMethodsAdd;

  /// Mensaje cuando no hay métodos de envío
  ///
  /// In es, this message translates to:
  /// **'No se encontraron métodos de envío'**
  String get shippingMethodsEmpty;

  /// Cabecera de columna nombre en tabla de métodos de envío
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get shippingMethodsColumnName;

  /// Cabecera de columna teléfono en tabla de métodos de envío
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get shippingMethodsColumnPhone;

  /// Cabecera de columna acciones en tabla de métodos de envío
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get shippingMethodsColumnActions;

  /// Tooltip botón editar método de envío
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get shippingMethodsEdit;

  /// Opción de menú para editar el nombre del método de envío
  ///
  /// In es, this message translates to:
  /// **'Editar nombre'**
  String get shippingMethodsEditName;

  /// Opción de menú para editar el teléfono del método de envío
  ///
  /// In es, this message translates to:
  /// **'Editar teléfono'**
  String get shippingMethodsEditPhone;

  /// Opción de menú para asociar clientes al método de envío
  ///
  /// In es, this message translates to:
  /// **'Asociar clientes'**
  String get shippingMethodsAssociateClients;

  /// Título del diálogo de asociación de clientes a método de envío
  ///
  /// In es, this message translates to:
  /// **'Asociar clientes a \"{name}\"'**
  String shippingMethodsAssociateTitle(String name);

  /// Placeholder del campo de búsqueda en diálogo de asociación
  ///
  /// In es, this message translates to:
  /// **'Buscar cliente...'**
  String get shippingMethodsAssociateSearch;

  /// Texto cuando no hay clientes para asociar
  ///
  /// In es, this message translates to:
  /// **'No hay clientes disponibles'**
  String get shippingMethodsAssociateNoClients;

  /// Texto de carga en diálogo de asociación
  ///
  /// In es, this message translates to:
  /// **'Cargando clientes...'**
  String get shippingMethodsAssociateLoading;

  /// Texto de error en diálogo de asociación
  ///
  /// In es, this message translates to:
  /// **'Error al cargar clientes'**
  String get shippingMethodsAssociateError;

  /// Opción para asignar el método de envío a todos los días
  ///
  /// In es, this message translates to:
  /// **'Todos los días'**
  String get shippingMethodsAssociateSelectAll;

  /// Etiqueta de la sección de selección de días
  ///
  /// In es, this message translates to:
  /// **'Selecciona los días'**
  String get shippingMethodsAssociateDaysLabel;

  /// Opción para seleccionar todos los clientes
  ///
  /// In es, this message translates to:
  /// **'Seleccionar todos'**
  String get shippingMethodsAssociateSelectAllClients;

  /// Tooltip y botón eliminar método de envío
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get shippingMethodsDelete;

  /// Validación: nombre de método de envío vacío
  ///
  /// In es, this message translates to:
  /// **'El nombre es obligatorio'**
  String get shippingMethodsNameRequired;

  /// Texto del diálogo de progreso al guardar método de envío
  ///
  /// In es, this message translates to:
  /// **'Guardando...'**
  String get shippingMethodsProgressSaving;

  /// Toast tras crear método de envío
  ///
  /// In es, this message translates to:
  /// **'Método de envío creado correctamente'**
  String get shippingMethodsSuccessCreated;

  /// Título del diálogo de confirmación de eliminación de método de envío
  ///
  /// In es, this message translates to:
  /// **'Eliminar método de envío'**
  String get shippingMethodsDeleteTitle;

  /// Mensaje de confirmación de eliminación de método de envío
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que quieres eliminar el método \"{name}\"?\nEsta acción no se puede deshacer.'**
  String shippingMethodsDeleteMessage(String name);

  /// Texto del diálogo de progreso al eliminar método de envío
  ///
  /// In es, this message translates to:
  /// **'Eliminando método de envío...'**
  String get shippingMethodsProgressDeleting;

  /// Toast tras eliminar método de envío
  ///
  /// In es, this message translates to:
  /// **'Método de envío eliminado correctamente'**
  String get shippingMethodsSuccessDeleted;

  /// Toast de error genérico en operación de método de envío
  ///
  /// In es, this message translates to:
  /// **'Error al realizar la operación'**
  String get shippingMethodsErrorOperation;

  /// Título del diálogo de edición de método de envío
  ///
  /// In es, this message translates to:
  /// **'Editar método de envío'**
  String get shippingMethodsEditTitle;

  /// Hint del campo de teléfono en formulario de método de envío
  ///
  /// In es, this message translates to:
  /// **'Teléfono de contacto'**
  String get shippingMethodsPhoneHint;

  /// Toast tras actualizar método de envío
  ///
  /// In es, this message translates to:
  /// **'Método de envío actualizado correctamente'**
  String get shippingMethodsSuccessSaved;

  /// Mensaje de error al fallar la carga de datos FD en detalle de cliente
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los datos de Factura Directa'**
  String get clientsFdLoadError;

  /// Título de la pantalla de login
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginTitle;

  /// Subtítulo de la pantalla de login
  ///
  /// In es, this message translates to:
  /// **'Introduce tus credenciales para acceder'**
  String get loginSubtitle;

  /// Label del campo de email en login
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// Hint del campo de email en login
  ///
  /// In es, this message translates to:
  /// **'usuario@ejemplo.com'**
  String get loginEmailHint;

  /// Label del campo de contraseña en login
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get loginPasswordLabel;

  /// Label del checkbox de recordar sesión
  ///
  /// In es, this message translates to:
  /// **'Recordarme'**
  String get loginRememberMe;

  /// Texto del botón de inicio de sesión
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginSignInButton;

  /// Error cuando el campo de email está vacío
  ///
  /// In es, this message translates to:
  /// **'Introduce tu email'**
  String get loginErrorEmailEmpty;

  /// Error cuando el email tiene formato inválido
  ///
  /// In es, this message translates to:
  /// **'Formato de email no válido'**
  String get loginErrorEmailInvalid;

  /// Error cuando el campo de contraseña está vacío
  ///
  /// In es, this message translates to:
  /// **'Introduce tu contraseña'**
  String get loginErrorPasswordEmpty;

  /// Error de credenciales incorrectas
  ///
  /// In es, this message translates to:
  /// **'Email o contraseña incorrectos'**
  String get loginErrorInvalidCredentials;

  /// Error cuando la cuenta está deshabilitada
  ///
  /// In es, this message translates to:
  /// **'Cuenta deshabilitada. Contacta al administrador'**
  String get loginErrorUserDisabled;

  /// Error por demasiados intentos de login
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Inténtalo más tarde'**
  String get loginErrorTooManyRequests;

  /// Error de conexión de red en login
  ///
  /// In es, this message translates to:
  /// **'Sin conexión a internet'**
  String get loginErrorNetwork;

  /// Error desconocido en login
  ///
  /// In es, this message translates to:
  /// **'Error de autenticación inesperado'**
  String get loginErrorUnknown;

  /// Botón de cerrar sesión en ajustes
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get settingsSignOut;

  /// Título del diálogo de confirmación de cierre de sesión
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get settingsSignOutConfirmTitle;

  /// Mensaje del diálogo de confirmación de cierre de sesión
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que quieres cerrar sesión?'**
  String get settingsSignOutConfirmMessage;

  /// Botón cancelar del diálogo de cierre de sesión
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get settingsSignOutConfirmCancel;

  /// Botón confirmar del diálogo de cierre de sesión
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get settingsSignOutConfirmAccept;

  /// Mensaje de error 404
  ///
  /// In es, this message translates to:
  /// **'La página que buscas no existe.'**
  String get notFoundMessage;

  /// Botón para volver al inicio desde la página 404
  ///
  /// In es, this message translates to:
  /// **'Ir al inicio'**
  String get notFoundGoHome;

  /// Mensaje de error cuando un cliente no se encuentra por ID
  ///
  /// In es, this message translates to:
  /// **'No se ha encontrado el cliente solicitado.'**
  String get clientNotFoundMessage;

  /// Botón para volver a la lista de clientes desde error de cliente no encontrado
  ///
  /// In es, this message translates to:
  /// **'Volver a clientes'**
  String get clientNotFoundGoBack;

  /// Mensaje de éxito al guardar cambios de un cliente
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados correctamente'**
  String get clientSaveSuccess;

  /// Título del placeholder cuando se accede a Pedidos de hoy desde un dispositivo con pantalla pequeña
  ///
  /// In es, this message translates to:
  /// **'Pantalla no disponible'**
  String get ordersTodayMobileTitle;

  /// Descripción del placeholder cuando se accede a Pedidos de hoy desde un dispositivo con pantalla pequeña
  ///
  /// In es, this message translates to:
  /// **'La gestión de pedidos de hoy solo está disponible en pantallas de mayor tamaño. Por favor, accede desde un ordenador o una tablet.'**
  String get ordersTodayMobileDescription;

  /// Mensaje cuando el fichero de pedidos existe pero ningún cliente tiene datos
  ///
  /// In es, this message translates to:
  /// **'No hay pedidos registrados hoy'**
  String get ordersTodayMobileNoOrders;

  /// Total de productos (cantidades + abonos) en la tarjeta colapsada del cliente
  ///
  /// In es, this message translates to:
  /// **'{count} uds.'**
  String ordersTodayMobileProductCount(String count);

  /// Etiqueta del badge de reserva en la vista móvil de pedidos
  ///
  /// In es, this message translates to:
  /// **'Reserva'**
  String get ordersTodayMobileReservation;

  /// Etiqueta del badge de compensación en la vista móvil de pedidos
  ///
  /// In es, this message translates to:
  /// **'Compensación'**
  String get ordersTodayMobileCompensation;

  /// Etiqueta del badge de abono con cantidad en la vista móvil de pedidos
  ///
  /// In es, this message translates to:
  /// **'Abono: {quantity}'**
  String ordersTodayMobileRefund(String quantity);

  /// Fecha y hora de la última modificación del documento de pedidos
  ///
  /// In es, this message translates to:
  /// **'Última actualización: {date}'**
  String ordersTodayLastModified(String date);

  /// Mensaje cuando no existe el documento de pedidos del día en la vista de solo lectura
  ///
  /// In es, this message translates to:
  /// **'No hay pedidos para hoy'**
  String get ordersTodayNoOrdersToday;

  /// Tooltip del indicador de conexión en vivo
  ///
  /// In es, this message translates to:
  /// **'Conectado en tiempo real'**
  String get ordersTodayLiveConnected;

  /// Tooltip del indicador cuando se pierde la conexión
  ///
  /// In es, this message translates to:
  /// **'Desconectado'**
  String get ordersTodayLiveDisconnected;

  /// Texto placeholder en la página de estadísticas
  ///
  /// In es, this message translates to:
  /// **'Próximamente'**
  String get statisticsComingSoon;

  /// Título del diálogo de selección de método de envío para PDF
  ///
  /// In es, this message translates to:
  /// **'Seleccionar método de envío'**
  String get pdfSelectShippingMethod;

  /// Hint del campo de búsqueda de método de envío en diálogo PDF
  ///
  /// In es, this message translates to:
  /// **'Buscar método de envío...'**
  String get pdfSearchShippingMethod;

  /// Cabecera de columna nombre en tabla del diálogo PDF
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get pdfColumnName;

  /// Cabecera de columna teléfono en tabla del diálogo PDF
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get pdfColumnPhone;

  /// Mensaje cuando no hay resultados en búsqueda de métodos de envío
  ///
  /// In es, this message translates to:
  /// **'No se encontraron métodos de envío'**
  String get pdfNoShippingMethodsFound;

  /// Etiqueta del impuesto IVA al 21%
  ///
  /// In es, this message translates to:
  /// **'IVA 21%'**
  String get taxLabelIva21;

  /// Etiqueta del impuesto IVA al 10%
  ///
  /// In es, this message translates to:
  /// **'IVA 10%'**
  String get taxLabelIva10;

  /// Etiqueta del impuesto IVA al 4%
  ///
  /// In es, this message translates to:
  /// **'IVA 4%'**
  String get taxLabelIva4;

  /// Etiqueta del recargo de equivalencia 5,20%
  ///
  /// In es, this message translates to:
  /// **'RE 5,20%'**
  String get taxLabelRe52;

  /// Etiqueta del recargo de equivalencia 1,40%
  ///
  /// In es, this message translates to:
  /// **'RE 1,40%'**
  String get taxLabelRe14;

  /// Etiqueta del recargo de equivalencia 0,50%
  ///
  /// In es, this message translates to:
  /// **'RE 0,50%'**
  String get taxLabelRe05;

  /// Formato de rango de fechas del mismo mes en el dashboard
  ///
  /// In es, this message translates to:
  /// **'{startDay}–{endDay} de {month}'**
  String dashboardDateRangeFormat(int startDay, int endDay, String month);

  /// Subtítulo del diálogo PDF con nombre de cliente y día
  ///
  /// In es, this message translates to:
  /// **'Para: {clientName} ({dayName})'**
  String pdfSubtitleFor(String clientName, String dayName);

  /// Título de la sección de versión de la aplicación en Ajustes
  ///
  /// In es, this message translates to:
  /// **'Versión de la web {version}'**
  String settingsAppVersionTitle(String version);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
