import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../models/company_profile.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../services/company_service.dart';
import '../theme/stora_brand.dart';

class PrintService {
  PrintService._();
  static final PrintService instance = PrintService._();

  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final _currency = NumberFormat.currency(locale: 'fr_FR', symbol: '');

  _PdfScale _scaleFor(PdfPageFormat format) {
    final usable = format.availableWidth;
    final factor = (usable / 515).clamp(0.72, 1.35);
    return _PdfScale(
      title: 14 * factor,
      subtitle: 10 * factor,
      body: 8.5 * factor,
      cell: 7.5 * factor,
      logo: (48 * factor).clamp(28, 72),
      margin: math.max(24.0, 36 * factor),
    );
  }

  pw.TextStyle _font(_PdfScale s, {double? size, bool bold = false}) {
    return pw.TextStyle(
      font: pw.Font.courier(),
      fontSize: size ?? s.body,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
  }

  String _clip(String? value, int max) {
    final v = (value ?? '').trim();
    if (v.length <= max) return v;
    return '${v.substring(0, math.max(0, max - 1))}…';
  }

  Future<pw.ImageProvider?> _loadCompanyLogo(CompanyProfile profile) async {
    final path = profile.logoPath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    try {
      return pw.MemoryImage(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  Future<pw.ImageProvider?> _loadBrandLogo() async {
    try {
      final data = await rootBundle.load(StoraBrand.assetLogoPng);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      try {
        final file = File(StoraBrand.assetLogoPng);
        if (await file.exists()) {
          return pw.MemoryImage(await file.readAsBytes());
        }
      } catch (_) {}
      return null;
    }
  }

  /// Identité page 1 : société si configurée, sinon logo.png + STORA + slogan.
  Future<pw.Widget> _buildIdentityBlock(
    PdfPageFormat format,
    _PdfScale s,
  ) async {
    final profile = await CompanyService.instance.getProfile();
    final companyLogo = await _loadCompanyLogo(profile);
    final useCompany = profile.hasPrintIdentity || companyLogo != null;

    final pw.ImageProvider? logo;
    final String title;
    final List<String> lines;

    if (useCompany) {
      logo = companyLogo ?? await _loadBrandLogo();
      title = profile.isConfigured ? profile.companyName : StoraBrand.name;
      lines = profile.infoLines;
    } else {
      logo = await _loadBrandLogo();
      title = StoraBrand.name;
      lines = [StoraBrand.slogan, StoraBrand.tagline];
    }

    final nameMax = (format.availableWidth / 9).floor().clamp(18, 48);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: s.logo,
                height: s.logo,
                margin: const pw.EdgeInsets.only(right: 10),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _clip(title, nameMax),
                    style: _font(s, size: s.title, bold: true),
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                  ),
                  ...lines.take(5).map(
                        (line) => pw.Text(
                          _clip(line, nameMax + 12),
                          style: _font(s, size: s.cell),
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.8, color: PdfColors.grey700),
        pw.SizedBox(height: 6),
      ],
    );
  }

  /// Titre du document (présent sur toutes les pages, compact).
  pw.Widget _documentTitleBar(
    String documentTitle,
    _PdfScale s,
    DateTime date, {
    required bool compact,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                documentTitle,
                style: _font(s, size: compact ? s.cell : s.subtitle, bold: true),
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
              ),
            ),
            pw.Text(
              _dateFormat.format(date),
              style: _font(s, size: s.cell),
            ),
          ],
        ),
        if (!compact) ...[
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5, color: PdfColors.grey500),
          pw.SizedBox(height: 8),
        ] else ...[
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.4, color: PdfColors.grey400),
          pw.SizedBox(height: 6),
        ],
      ],
    );
  }

  /// En-tête MultiPage : identité (société ou STORA) page 1 seulement.
  pw.Widget _pageHeader({
    required pw.Context context,
    required String documentTitle,
    required _PdfScale s,
    required DateTime date,
    required pw.Widget identityBlock,
  }) {
    if (context.pageNumber == 1) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          identityBlock,
          _documentTitleBar(documentTitle, s, date, compact: false),
        ],
      );
    }

    // Pages suivantes : pas de logo ni coordonnées
    return _documentTitleBar(
      '$documentTitle — suite',
      s,
      date,
      compact: true,
    );
  }

  pw.Widget _pageFooter(pw.Context context, _PdfScale s) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Text(
        'Page ${context.pageNumber} / ${context.pagesCount}',
        style: _font(s, size: s.cell),
      ),
    );
  }

  pw.Widget _responsiveTable({
    required List<String> headers,
    required List<List<String>> rows,
    required List<int> flex,
    required _PdfScale s,
  }) {
    assert(headers.length == flex.length);

    final headerStyle = _font(s, size: s.cell, bold: true);
    final cellStyle = _font(s, size: s.cell);

    pw.TableRow buildRow(List<String> cells, {bool isHeader = false}) {
      return pw.TableRow(
        decoration: isHeader
            ? const pw.BoxDecoration(color: PdfColors.grey300)
            : null,
        children: List.generate(cells.length, (i) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(
              cells[i],
              style: isHeader ? headerStyle : cellStyle,
              maxLines: isHeader ? 1 : 2,
              overflow: pw.TextOverflow.clip,
            ),
          );
        }),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
      columnWidths: {
        for (var i = 0; i < flex.length; i++)
          i: pw.FlexColumnWidth(flex[i].toDouble()),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        buildRow(headers, isHeader: true),
        ...rows.map((r) => buildRow(r)),
      ],
    );
  }

  Future<void> printStockReport() async {
    final products = await DatabaseHelper.instance.getProducts();
    final summary = await DatabaseHelper.instance.getStockSummary();
    final now = DateTime.now();

    await Printing.layoutPdf(
      onLayout: (format) async {
        final s = _scaleFor(format);
        final identity = await _buildIdentityBlock(format, s);
        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: pw.EdgeInsets.all(s.margin),
            maxPages: 100,
            header: (context) => _pageHeader(
              context: context,
              documentTitle: 'RAPPORT DE STOCK',
              s: s,
              date: now,
              identityBlock: identity,
            ),
            footer: (context) => _pageFooter(context, s),
            build: (context) => [
              pw.Text(
                'Produits: ${summary['total_products']}  |  '
                'Qté: ${summary['total_quantity']}  |  '
                'Valeur: ${_currency.format(summary['total_value'])}  |  '
                'Alertes: ${summary['low_stock_count']}',
                style: _font(s, size: s.body),
                maxLines: 3,
                overflow: pw.TextOverflow.clip,
              ),
              pw.SizedBox(height: 10),
              _productTable(products, s, format),
            ],
          ),
        );
        return doc.save();
      },
    );
  }

  Future<void> printLowStockReport() async {
    final products = await DatabaseHelper.instance.getLowStockProducts();
    final now = DateTime.now();

    await Printing.layoutPdf(
      onLayout: (format) async {
        final s = _scaleFor(format);
        final identity = await _buildIdentityBlock(format, s);
        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: pw.EdgeInsets.all(s.margin),
            maxPages: 50,
            header: (context) => _pageHeader(
              context: context,
              documentTitle: 'ALERTES STOCK BAS',
              s: s,
              date: now,
              identityBlock: identity,
            ),
            footer: (context) => _pageFooter(context, s),
            build: (context) => [
              if (products.isEmpty)
                pw.Text('Aucune alerte.', style: _font(s))
              else
                _productTable(products, s, format),
            ],
          ),
        );
        return doc.save();
      },
    );
  }

  Future<void> printMovementsReport(
    List<StockMovement> movements,
    Map<int, Product> productMap,
  ) async {
    final now = DateTime.now();

    await Printing.layoutPdf(
      onLayout: (format) async {
        final s = _scaleFor(format);
        final identity = await _buildIdentityBlock(format, s);
        final nameMax =
            (format.availableWidth / 18).floor().clamp(10, 28);
        final agentMax =
            (format.availableWidth / 28).floor().clamp(8, 18);

        final rows = movements.map((m) {
          final p = productMap[m.productId];
          return [
            _clip(_dateFormat.format(m.createdAt), 16),
            _clip(m.typeLabel, 12),
            _clip(m.agentName, agentMax),
            _clip(p?.code, 10),
            _clip(p?.name, nameMax),
            '${m.quantity}',
            '${m.quantityBefore}',
            '${m.quantityAfter}',
          ];
        }).toList();

        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: pw.EdgeInsets.all(s.margin),
            maxPages: 100,
            header: (context) => _pageHeader(
              context: context,
              documentTitle: 'JOURNAL DES MOUVEMENTS',
              s: s,
              date: now,
              identityBlock: identity,
            ),
            footer: (context) => _pageFooter(context, s),
            build: (context) => [
              _responsiveTable(
                headers: [
                  'DATE',
                  'TYPE',
                  'AGENT',
                  'CODE',
                  'PRODUIT',
                  'QTÉ',
                  'AVANT',
                  'APRÈS'
                ],
                rows: rows,
                flex: const [16, 12, 14, 10, 22, 7, 8, 8],
                s: s,
              ),
            ],
          ),
        );
        return doc.save();
      },
    );
  }

  Future<void> printProductLabel(Product product) async {
    final profile = await CompanyService.instance.getProfile();
    final companyLogo = await _loadCompanyLogo(profile);
    final useCompany = profile.hasPrintIdentity || companyLogo != null;
    final logo = useCompany
        ? (companyLogo ?? await _loadBrandLogo())
        : await _loadBrandLogo();
    final title = useCompany && profile.isConfigured
        ? profile.companyName
        : StoraBrand.name;

    await Printing.layoutPdf(
      onLayout: (format) async {
        final page = PdfPageFormat(
          format.width.clamp(140, 320),
          format.height.clamp(80, 200),
          marginAll: 8,
        );
        final s = _scaleFor(page);
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: page,
            margin: const pw.EdgeInsets.all(8),
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 24,
                        height: 24,
                        margin: const pw.EdgeInsets.only(right: 6),
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _clip(title, 28),
                            style: _font(s, size: s.cell, bold: true),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          ),
                          if (!useCompany)
                            pw.Text(
                              StoraBrand.slogan,
                              style: _font(s, size: s.cell * 0.85),
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  product.code,
                  style: _font(s, size: s.title, bold: true),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
                pw.Text(
                  _clip(product.name, 36),
                  style: _font(s, size: s.body),
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                ),
                pw.Spacer(),
                pw.Text(
                  'Qté: ${product.quantity} ${product.unit}',
                  style: _font(s, size: s.cell),
                ),
              ],
            ),
          ),
        );
        return doc.save();
      },
    );
  }

  pw.Widget _productTable(
    List<Product> products,
    _PdfScale s,
    PdfPageFormat format,
  ) {
    final nameMax = (format.availableWidth / 14).floor().clamp(12, 36);
    final rows = products
        .map((p) => [
              _clip(p.code, 12),
              _clip(p.name, nameMax),
              '${p.quantity}',
              '${p.minStock}',
              _clip(p.unit, 6),
              _clip(p.location, 10),
              _clip(_currency.format(p.purchasePrice), 12),
              _clip(_currency.format(p.quantity * p.purchasePrice), 12),
            ])
        .toList();

    return _responsiveTable(
      headers: [
        'CODE',
        'NOM',
        'QTÉ',
        'MIN',
        'UNITÉ',
        'EMPL.',
        'P.ACHAT',
        'VALEUR'
      ],
      rows: rows,
      flex: const [12, 28, 7, 6, 7, 10, 14, 14],
      s: s,
    );
  }
}

class _PdfScale {
  const _PdfScale({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.cell,
    required this.logo,
    required this.margin,
  });

  final double title;
  final double subtitle;
  final double body;
  final double cell;
  final double logo;
  final double margin;
}
