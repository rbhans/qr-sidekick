/// Niagara-specific constants for BQL queries and API
class NiagaraConstants {
  NiagaraConstants._();

  /// Default port for Niagara stations
  static const int defaultPort = 443;

  /// Default protocol
  static const String defaultProtocol = 'https';

  /// Base BQL query to get all control points under Drivers
  static const String baseControlPointQuery =
      "station:|slot:/Drivers|bql:select%20slotPath,%20type%20as%20'Point%20Type',%20facets%20from%20control:ControlPoint";

  /// Format options to try for CSV export (version-dependent)
  /// Ordered by preference - try each until one returns valid CSV
  static const List<String> formatOptions = [
    '&format=csv',
    '&export=csv',
    '&view=csv',
    '|view:web:CsvView',
    '|view:web:TextView',
    '|view:workbench:TableToCsv',
    '', // Fallback: attempt to parse HTML table
  ];

  /// Expected CSV headers for validation
  static const List<String> expectedHeaders = [
    'slotPath',
    'Point Type',
    'facets',
  ];

  /// Regex patterns for parsing
  static const String slotPathPattern = r'^slot:/';
  static const String pointTypePattern = r':(\w+)$';
}
