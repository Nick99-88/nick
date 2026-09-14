import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfViewerScreen({super.key, required this.filePath, this.title = "Document"});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _fullScreen = false;

  @override
  Widget build(BuildContext context) {
    if (_fullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            SfPdfViewer.file(File(widget.filePath)),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: GestureDetector(
                onTap: () => setState(() => _fullScreen = false),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          SfPdfViewer.file(File(widget.filePath)),
          Positioned(
            right: 12,
            bottom: 12,
            child: GestureDetector(
              onTap: () => setState(() => _fullScreen = true),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
