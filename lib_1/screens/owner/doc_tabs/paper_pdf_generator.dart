import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'testArchitect.dart';

class PaperPdfGenerator {
  final String instName;
  final String subject;
  final String targetClass;
  final String paperType;
  final String duration;
  final PaperLang lang;
  final String institutionalNotice;
  final List<PaperPage> pages;

  PaperPdfGenerator({
    required this.instName,
    required this.subject,
    required this.targetClass,
    required this.paperType,
    required this.duration,
    required this.lang,
    required this.institutionalNotice,
    required this.pages,
    this.logoBytes,
    this.logoShape = 'circle',
  });

  final Uint8List? logoBytes;
  final String logoShape;

  final Map<PaperLang, Map<String, String>> langMap = {
    PaperLang.en: {
      "sub": "SUB", "class": "CLASS", "type": "TYPE", "time": "TIME",
      "mcq": "Multiple Choice Questions", "short": "Short Questions", "long": "Long Questions",
      "subject": "Subject", "class_label": "Class", "type_label": "Type", "time_label": "Time"
    },
    PaperLang.ur: {
      "sub": "مضمون", "class": "جماعت", "type": "قسم", "time": "وقت",
      "mcq": "کثیر الانتخابی سوالات", "short": "مختصر سوالات", "long": "انشائیہ سوالات",
      "subject": "مضمون", "class_label": "جماعت", "type_label": "قسم", "time_label": "وقت"
    },
    PaperLang.ar: {
      "sub": "المادة", "class": "الصف", "type": "نوع", "time": "وقت",
      "mcq": "أسئلة الاختيار من متعدد", "short": "أسئلة قصيرة", "long": "أسئلة طويلة",
      "subject": "المادة", "class_label": "الصف", "type_label": "نوع", "time_label": "وقت"
    },
  };

  String _getLocalizedText(String key) {
    return langMap[lang]?[key.toLowerCase()] ?? key;
  }

  String _getLocalizedNum(int n) {
    if (lang == PaperLang.en) return n.toString();
    const urduDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final digits = lang == PaperLang.ar ? arabicDigits : urduDigits;
    final isNegative = n < 0;
    final absStr = n.abs().toString();
    final result = absStr.split('').map((d) {
      final idx = int.tryParse(d);
      return idx != null ? digits[idx] : d;
    }).join('');
    return isNegative ? '-$result' : result;
  }

  String _getLocalizedOption(int index) {
    if (lang == PaperLang.en) return String.fromCharCode(97 + index);
    if (lang == PaperLang.ur) {
      const urduAlphas = ['الف', 'ب', 'ج', 'د'];
      return urduAlphas[index % 4];
    }
    if (lang == PaperLang.ar) {
      const arabicAlphas = ['أ', 'ب', 'ج', 'د'];
      return arabicAlphas[index % 4];
    }
    return String.fromCharCode(97 + index);
  }

  Future<String> generateAndInstall() async {
    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    final margins = PdfMargins();
    margins.left = 40;
    margins.right = 40;
    margins.top = 40;
    margins.bottom = 40;
    document.pageSettings.margins = margins;

    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final paperPage = pages[pageIndex];
      final page = document.pages.add();
      final graphics = page.graphics;
      final width = page.getClientSize().width;
      final height = page.getClientSize().height;
      double yPos = 0;

      if (pageIndex == 0) {
        yPos = _drawFullHeader(graphics, width, height, yPos);
      } else {
        yPos = _drawSimpleHeader(graphics, width, height, yPos);
      }

      yPos += 10;

      for (final block in paperPage.blocks) {
        if (yPos > height - 100) {
          final newPage = document.pages.add();
          final newWidth = newPage.getClientSize().width;
          final newHeight = newPage.getClientSize().height;
          yPos = _drawSimpleHeader(newPage.graphics, newWidth, newHeight, 0);
          yPos += 10;
        }

        yPos = _drawQuestionBlock(graphics, width, height, block, yPos);
      }

      // Watermark
      final watermarkFont = PdfStandardFont(PdfFontFamily.helvetica, 7);
      graphics.drawString("Made by Starlight", watermarkFont,
        brush: PdfSolidBrush(PdfColor(180, 180, 180)),
        bounds: Rect.fromLTWH(width - 110, height - 18, 100, 12),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
    }

    final bytes = await document.save();
    document.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = "STARLIGHT_${subject.replaceAll(' ', '_')}_${paperType.replaceAll(' ', '_')}_${timestamp}.pdf";
    final file = File("${dir.path}/$fileName");
    await file.writeAsBytes(bytes);

    await OpenFile.open(file.path);
    return file.path;
  }

  double _drawFullHeader(PdfGraphics graphics, double width, double height, double yPos) {
    final navy = PdfColor(26, 35, 126);
    final gold = PdfColor(255, 193, 7);
    final white = PdfColor(255, 255, 255);
    final darkGrey = PdfColor(50, 50, 50);
    final lightGrey = PdfColor(240, 240, 245);

    final whiteBold = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final metaFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final smallItalicFont = PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.italic);

    final whiteBrush = PdfSolidBrush(white);
    final navyBrush = PdfSolidBrush(navy);
    final goldBrush = PdfSolidBrush(gold);
    final lightBrush = PdfSolidBrush(lightGrey);

    // Draw dark navy top band
    graphics.drawRectangle(brush: navyBrush, bounds: Rect.fromLTWH(0, yPos, width, 52));

    // Logo
    double textOffset = 4;
    if (logoBytes != null) {
      try {
        final logo = PdfBitmap(logoBytes!);
        const logoSize = 38.0;
        if (logoShape == 'circle') {
          // White circle background
          graphics.drawEllipse(Rect.fromLTWH(8, yPos + 7, logoSize, logoSize),
              brush: PdfBrushes.white, pen: PdfPen(PdfColor(255, 255, 255)));
          // Clip to circle by only drawing within the ellipse area
          // Draw white background then image on top
          graphics.drawImage(logo, Rect.fromLTWH(10, yPos + 9, logoSize - 4, logoSize - 4));
        } else {
          // White square background
          graphics.drawRectangle(brush: PdfBrushes.white, bounds: Rect.fromLTWH(8, yPos + 7, logoSize, logoSize));
          graphics.drawImage(logo, Rect.fromLTWH(10, yPos + 9, logoSize - 4, logoSize - 4));
        }
        textOffset = logoSize + 20;
      } catch (_) {}
    }

    // Institution name in white
    graphics.drawString(instName.toUpperCase(), whiteBold,
      brush: whiteBrush,
      bounds: Rect.fromLTWH(textOffset, yPos + 14, width - textOffset - 8, 22),
      format: PdfStringFormat(alignment: textOffset > 4 ? PdfTextAlignment.left : PdfTextAlignment.center),
    );

    // Gold accent line below navy band
    graphics.drawRectangle(brush: goldBrush, bounds: Rect.fromLTWH(0, yPos + 52, width, 3));

    // Light grey metadata band
    graphics.drawRectangle(brush: lightBrush, bounds: Rect.fromLTWH(0, yPos + 55, width, 40));

    final subLabel = _getLocalizedText("subject");
    final classLabel = _getLocalizedText("class_label");
    final typeLabel = _getLocalizedText("type_label");
    final timeLabel = _getLocalizedText("time_label");

    graphics.drawString("$subLabel: $subject", metaFont, bounds: Rect.fromLTWH(16, yPos + 58, width / 2 - 20, 14));
    graphics.drawString("$classLabel: $targetClass", metaFont, bounds: Rect.fromLTWH(width / 2 + 8, yPos + 58, width / 2 - 20, 14));
    graphics.drawString("$typeLabel: $paperType", metaFont, bounds: Rect.fromLTWH(16, yPos + 74, width / 2 - 20, 14));
    graphics.drawString("$timeLabel: $duration", metaFont, bounds: Rect.fromLTWH(width / 2 + 8, yPos + 74, width / 2 - 20, 14));

    // Bottom thin border line
    graphics.drawLine(PdfPen(darkGrey, width: 0.5), Offset(0, yPos + 95), Offset(width, yPos + 95));

    yPos += 100;

    graphics.drawString(
      institutionalNotice,
      smallItalicFont,
      bounds: Rect.fromLTWH(0, yPos, width, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    return yPos + 22;
  }

  double _drawSimpleHeader(PdfGraphics graphics, double width, double height, double yPos) {
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final thinPen = PdfPen(PdfColor(0, 0, 0), width: 0.5);

    graphics.drawString(
      instName.toUpperCase(),
      PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
      bounds: Rect.fromLTWH(0, yPos, width, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    yPos += 20;

    graphics.drawString(
      "${_getLocalizedText("sub")}: $subject  |  ${_getLocalizedText("class")}: $targetClass",
      smallFont,
      bounds: Rect.fromLTWH(0, yPos, width, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    yPos += 18;

    graphics.drawLine(
      thinPen,
      Offset(0, yPos),
      Offset(width, yPos),
    );

    return yPos + 10;
  }

  double _drawQuestionBlock(PdfGraphics graphics, double width, double height, QuestionBlock block, double yPos) {
    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final sectionFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final questionFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final subPartFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final thinPen = PdfPen(PdfColor(0, 0, 0), width: 0.5);
    final marksFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);

    final totalAvailable = block.questions.length;
    final attemptText = (block.choice < totalAvailable)
        ? "Attempt any ${block.choice} from $totalAvailable"
        : "Attempt all questions";

    // Section heading (centered)
    if (block.sectionHeading.isNotEmpty) {
      graphics.drawString(block.sectionHeading, sectionFont,
        bounds: Rect.fromLTWH(0, yPos + 2, width, 18),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      yPos += 24;
    }

    graphics.drawLine(
      thinPen,
      Offset(0, yPos),
      Offset(width, yPos),
    );

    graphics.drawString(block.headerText, headerFont, bounds: Rect.fromLTWH(0, yPos + 2, width - 80, 15));
    graphics.drawString(
      "(${block.choice * block.marks} Marks)",
      marksFont,
      bounds: Rect.fromLTWH(width - 80, yPos + 2, 80, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    yPos += 18;

    graphics.drawString(
      attemptText,
      PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.italic),
      bounds: Rect.fromLTWH(0, yPos, width, 12),
    );
    yPos += 15;

    if (block.showBubbleSheet && block.bubbleSheetPosition == 'start' && block.type == "MCQs") {
      yPos = _drawBubbleSheet(graphics, width, block, yPos);
    }

    for (int i = 0; i < block.questions.length; i++) {
      if (yPos > height - 60) {
        return yPos;
      }

      final q = block.questions[i];
      final questionText = "${_getLocalizedNum(block.startNumber + i)}. ${q.text}";

      graphics.drawString(questionText, questionFont, bounds: Rect.fromLTWH(10, yPos, width - 20, 20));
      yPos += 18;

      if (q.subParts.isNotEmpty) {
        final parts = q.subParts.asMap().entries.map((e) {
          final spIndex = e.key;
          final sp = e.value;
          final label = _getLocalizedOption(spIndex);
          return "($label) ${sp.text}";
        }).join("    ");

        graphics.drawString(parts, subPartFont, bounds: Rect.fromLTWH(30, yPos, width - 40, 20));
        yPos += 18;
      }
    }

    if (block.showBubbleSheet && block.bubbleSheetPosition == 'end' && block.type == "MCQs") {
      yPos = _drawBubbleSheet(graphics, width, block, yPos);
    }

    return yPos + 10;
  }

  double _drawBubbleSheet(PdfGraphics graphics, double width, QuestionBlock block, double yPos) {
    final numQuestions = block.questions.length;
    final optionsPerQuestion = block.bubbleOptions;
    final optionLabels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final tinyFont = PdfStandardFont(PdfFontFamily.helvetica, 7);
    final thinPen = PdfPen(PdfColor(0, 0, 0), width: 0.5);
    final borderPen = PdfPen(PdfColor(0, 0, 0), width: 1);

    // Calculate compact width: No. column + options
    final contentWidth = 28.0 + optionsPerQuestion * 18.0;
    final boxWidth = contentWidth + 16;
    final offsetX = (width - boxWidth) / 2;

    // Border box (compact width, centered)
    graphics.drawRectangle(pen: borderPen, brush: PdfBrushes.transparent,
      bounds: Rect.fromLTWH(offsetX, yPos, boxWidth, 28 + numQuestions * 14.0));

    // Title (centered within box)
    graphics.drawString("BUBBLE SHEET", smallFont,
      bounds: Rect.fromLTWH(offsetX, yPos + 2, boxWidth, 12),
      format: PdfStringFormat(alignment: PdfTextAlignment.center));
    yPos += 14;

    // Header row: No + option letters
    double xPos = offsetX + 6;
    graphics.drawString("No.", tinyFont, bounds: Rect.fromLTWH(xPos, yPos, 20, 10));
    xPos += 24;
    for (int i = 0; i < optionsPerQuestion; i++) {
      graphics.drawString(optionLabels[i], tinyFont,
        bounds: Rect.fromLTWH(xPos, yPos, 16, 10),
        format: PdfStringFormat(alignment: PdfTextAlignment.center));
      xPos += 18;
    }
    yPos += 10;

    graphics.drawLine(thinPen, Offset(offsetX, yPos), Offset(offsetX + boxWidth, yPos));

    // Question rows with circles
    for (int qIdx = 0; qIdx < numQuestions; qIdx++) {
      if (qIdx > 0) graphics.drawLine(thinPen, Offset(offsetX, yPos), Offset(offsetX + boxWidth, yPos));

      xPos = offsetX + 6;
      graphics.drawString(_getLocalizedNum(block.startNumber + qIdx), tinyFont,
        bounds: Rect.fromLTWH(xPos, yPos + 2, 20, 10));
      xPos += 24;

      for (int optIdx = 0; optIdx < optionsPerQuestion; optIdx++) {
        graphics.drawEllipse(
          Rect.fromLTWH(xPos + 1, yPos + 1, 10, 10),
          pen: thinPen,
          brush: PdfBrushes.transparent,
        );
        xPos += 18;
      }
      yPos += 14;
    }

    return yPos + 12;
  }
}
