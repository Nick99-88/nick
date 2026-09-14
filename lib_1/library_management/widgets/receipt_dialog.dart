import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/checkout.dart';

class ReceiptDialog {
  static Future<void> showCheckoutReceipt(BuildContext context, dynamic checkouts) {
    final list = checkouts is List<Checkout> ? checkouts : [checkouts as Checkout];
    final distinctBooks = list.map((c) => c.bookTitle).toSet().length;
    final suffix = list.length == 1 ? '' : ' (${list.length} cop${list.length == 1 ? 'y' : 'ies'}, $distinctBooks book${distinctBooks == 1 ? '' : 's'})';
    final title = 'CHECKOUT RECEIPT$suffix';
    return _show(context, title, _buildMultiCheckoutBody(list), list.first);
  }

  static Future<void> showReturnReceipt(BuildContext context, dynamic checkouts) {
    final list = checkouts is List<Checkout> ? checkouts : [checkouts as Checkout];
    final distinctBooks = list.map((c) => c.bookTitle).toSet().length;
    final suffix = list.length == 1 ? '' : ' (${list.length} cop${list.length == 1 ? 'y' : 'ies'}, $distinctBooks book${distinctBooks == 1 ? '' : 's'})';
    final title = 'RETURN RECEIPT$suffix';
    return _show(context, title, _buildReturnBody(list), list.first);
  }

  static String _buildMultiCheckoutBody(List<Checkout> list) {
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════╗')
      ..writeln('║${list.length == 1 ? '        CHECKOUT RECEIPT      ' : '   CHECKOUT RECEIPT (${list.length})  '}║')
      ..writeln('╠══════════════════════════════╣')
      ..writeln('║ Date: ${list.first.checkoutDate.toString().substring(0, 19)}');

    final byBook = <String, int>{};
    for (final co in list) {
      byBook[co.bookTitle] = (byBook[co.bookTitle] ?? 0) + 1;
    }
    if (byBook.length == 1) {
      buf.writeln('║ Book: ${list.first.bookTitle}');
      buf.writeln('║ Author: ${list.first.bookAuthor}');
      buf.writeln('║ Copies: ${list.length}');
    } else {
      buf.writeln('║──────────────────────────────║');
      buf.writeln('║ Books:');
      for (final e in byBook.entries) {
        buf.writeln('║   ${e.value}x ${e.key}');
      }
      buf.writeln('║   Total: ${list.length} copies');
    }

    buf
      ..writeln('║──────────────────────────────║')
      ..writeln('║ Client: ${list.first.clientName}${list.first.clientPhone != null ? '\n║ Phone: ${list.first.clientPhone}' : ''}');

    if (list.first.extraFields.isNotEmpty) {
      buf.writeln('║──────────────────────────────║');
      for (final e in list.first.extraFields.entries) {
        buf.writeln('║ ${e.key}: ${e.value}');
      }
    }

    buf.writeln('║──────────────────────────────║');
    if (list.length > 1) {
      buf.writeln('║ IDs:');
      for (final co in list) {
        buf.writeln('║   ${co.id.substring(0, 8)}...');
      }
      buf.writeln('║──────────────────────────────║');
    }
    buf
      ..writeln('║ Status: ${list.first.returnDate != null ? "RETURNED" : "CHECKED OUT"}${" "}║')
      ..writeln('╚══════════════════════════════╝');
    return buf.toString();
  }

  static String _buildReturnBody(List<Checkout> list) {
    final now = DateTime.now();
    final buf = StringBuffer()
      ..writeln('╔══════════════════════════════╗')
      ..writeln('║${list.length == 1 ? '         RETURN RECEIPT       ' : '    RETURN RECEIPT (${list.length})   '}║')
      ..writeln('╠══════════════════════════════╣')
      ..writeln('║ Return Date: ${now.toString().substring(0, 19)}');

    final byBook = <String, int>{};
    for (final co in list) {
      byBook[co.bookTitle] = (byBook[co.bookTitle] ?? 0) + 1;
    }
    if (byBook.length == 1) {
      buf.writeln('║ Book: ${list.first.bookTitle}');
      buf.writeln('║ Author: ${list.first.bookAuthor}');
      buf.writeln('║ Copies: ${list.length}');
    } else {
      buf.writeln('║──────────────────────────────║');
      buf.writeln('║ Books:');
      for (final e in byBook.entries) {
        buf.writeln('║   ${e.value}x ${e.key}');
      }
      buf.writeln('║   Total: ${list.length} copies');
    }

    buf
      ..writeln('║──────────────────────────────║')
      ..writeln('║ Client: ${list.first.clientName}${list.first.clientPhone != null ? '\n║ Phone: ${list.first.clientPhone}' : ''}');

    if (list.first.extraFields.isNotEmpty) {
      buf.writeln('║──────────────────────────────║');
      for (final e in list.first.extraFields.entries) {
        buf.writeln('║ ${e.key}: ${e.value}');
      }
    }

    buf
      ..writeln('║──────────────────────────────║')
      ..writeln('║ Checked Out: ${list.first.checkoutDate.toString().substring(0, 10)}')
      ..writeln('║ Status: RETURNED             ║')
      ..writeln('╚══════════════════════════════╝');
    return buf.toString();
  }

  static Future<void> _print(String title, String body) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Center(
          child: pw.Text(body, style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10)),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  static Future<void> _download(String body) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.txt');
    await file.writeAsString(body);
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: file.path.split('\\').last,
    );
  }

  static Future<void> _show(
      BuildContext context, String title, String body, Checkout checkout) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(title.contains('RETURN') ? Icons.check_circle : Icons.receipt_long,
                color: title.contains('RETURN') ? Colors.green : Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  body,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: body));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Receipt copied to clipboard')),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Save'),
                    onPressed: () async {
                      await _download(body);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Receipt saved')),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print'),
                    onPressed: () => _print(title, body),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
