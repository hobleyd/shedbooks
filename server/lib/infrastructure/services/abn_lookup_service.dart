import 'package:http/http.dart' as http;

/// Result of an ABN lookup against the Australian Business Register.
class AbnLookupResult {
  /// Whether the ABN was found in the register.
  final bool found;

  /// Whether the entity is currently registered for GST.
  final bool gstRegistered;

  const AbnLookupResult({required this.found, required this.gstRegistered});
}

/// Queries the ABR XML Search SOAP API to resolve ABN details.
class AbnLookupService {
  static const _endpoint =
      'https://abr.business.gov.au/abrxmlsearch/AbrXmlSearch.asmx';
  static const _soapAction =
      'http://abr.business.gov.au/ABRXMLSearch/SearchByABNv202001';
  static const _namespace = 'http://abr.business.gov.au/ABRXMLSearch/';

  final String _authGuid;
  final http.Client _httpClient;

  AbnLookupService({required String authGuid, http.Client? httpClient})
      : _authGuid = authGuid,
        _httpClient = httpClient ?? http.Client();

  /// Looks up [abn] (11 digits, no spaces) and returns registration details.
  /// Throws if the network request fails.
  Future<AbnLookupResult> lookup(String abn) async {
    final envelope = '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <SearchByABNv202001 xmlns="$_namespace">
      <searchString>$abn</searchString>
      <includeHistoricalDetails>N</includeHistoricalDetails>
      <authenticationGuid>$_authGuid</authenticationGuid>
    </SearchByABNv202001>
  </soap:Body>
</soap:Envelope>''';

    final response = await _httpClient.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'text/xml; charset=utf-8',
        'SOAPAction': _soapAction,
      },
      body: envelope,
    );

    if (response.statusCode != 200) {
      throw Exception('ABR service returned ${response.statusCode}');
    }

    return _parseResponse(response.body);
  }

  AbnLookupResult _parseResponse(String body) {
    // An <exception> element indicates the ABN was not found or is invalid.
    if (body.contains('<exception>')) {
      return const AbnLookupResult(found: false, gstRegistered: false);
    }

    // GST is active when <goodsAndServicesTax> is present and its
    // <effectiveTo> date is 0001-01-01 (the ABR sentinel for "no end date").
    final gstBlock = RegExp(
      r'<goodsAndServicesTax>.*?</goodsAndServicesTax>',
      dotAll: true,
    ).firstMatch(body);

    if (gstBlock == null) {
      return const AbnLookupResult(found: true, gstRegistered: false);
    }

    final effectiveTo = RegExp(r'<effectiveTo>(.*?)</effectiveTo>')
        .firstMatch(gstBlock.group(0)!)
        ?.group(1);

    final gstActive = effectiveTo == '0001-01-01';
    return AbnLookupResult(found: true, gstRegistered: gstActive);
  }
}
