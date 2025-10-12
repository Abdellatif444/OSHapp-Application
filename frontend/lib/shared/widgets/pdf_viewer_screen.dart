import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart' as fs;

class PdfViewerScreen extends StatefulWidget {
  final String? url;
  final File? file;
  final String? title;

  const PdfViewerScreen({super.key, this.url, this.file, this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  bool _downloading = false;
  final PdfViewerController _pdfController = PdfViewerController();
  int _totalPages = 0;
  int _currentPage = 1;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    // Proactively download to memory for more reliable rendering on some devices
    if (widget.file == null &&
        widget.url != null &&
        widget.url!.trim().isNotEmpty) {
      // Fire and forget; UI shows a spinner overlay while downloading
      _downloadToMemory();
    }
  }

  Future<void> _downloadToMemory() async {
    if (widget.url == null || widget.url!.trim().isEmpty) return;
    try {
      setState(() => _downloading = true);
      final resp = await http.get(Uri.parse(widget.url!));
      if (resp.statusCode == 200) {
        setState(() => _bytes = resp.bodyBytes);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Téléchargement échoué (${resp.statusCode}).')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de téléchargement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? url = widget.url;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title?.trim().isNotEmpty == true
            ? widget.title!
            : 'Aperçu du PDF'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          if (url != null && url.trim().isNotEmpty)
            IconButton(
              tooltip: 'Ouvrir dans le navigateur',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Impossible d\'ouvrir dans le navigateur.')),
                    );
                  }
                }
              },
            ),
          IconButton(
            tooltip: 'Télécharger',
            icon: const Icon(Icons.download_rounded),
            onPressed: _savePdf,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildViewer(url),
                if (_downloading)
                  const Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: ColoredBox(
                        color: Color(0x33FFFFFF),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildViewer(String? url) {
    if (widget.file != null) {
      return SfPdfViewer.file(
        widget.file!,
        controller: _pdfController,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        pageLayoutMode: PdfPageLayoutMode.continuous,
        onDocumentLoaded: (details) {
          setState(() {
            _totalPages = details.document.pages.count;
            _currentPage = _pdfController.pageNumber;
            _zoomLevel = _pdfController.zoomLevel;
          });
        },
        onPageChanged: (details) {
          setState(() => _currentPage = details.newPageNumber);
        },
        onDocumentLoadFailed: (details) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Échec du chargement du PDF: ${details.error}')),
            );
          }
        },
      );
    }
    if (_bytes != null) {
      return SfPdfViewer.memory(
        _bytes!,
        controller: _pdfController,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        pageLayoutMode: PdfPageLayoutMode.continuous,
        onDocumentLoaded: (details) {
          setState(() {
            _totalPages = details.document.pages.count;
            _currentPage = _pdfController.pageNumber;
            _zoomLevel = _pdfController.zoomLevel;
          });
        },
        onPageChanged: (details) {
          setState(() => _currentPage = details.newPageNumber);
        },
      );
    }
    return SfPdfViewer.network(
      url ?? '',
      controller: _pdfController,
      canShowScrollStatus: true,
      canShowPaginationDialog: true,
      pageLayoutMode: PdfPageLayoutMode.continuous,
      onDocumentLoaded: (details) {
        setState(() {
          _totalPages = details.document.pages.count;
          _currentPage = _pdfController.pageNumber;
          _zoomLevel = _pdfController.zoomLevel;
        });
      },
      onDocumentLoadFailed: (details) async {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Échec du chargement du PDF, tentative de téléchargement...')),
          );
        }
        await _downloadToMemory();
      },
      onPageChanged: (details) {
        setState(() => _currentPage = details.newPageNumber);
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Page précédente',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentPage > 1
                    ? () {
                        _pdfController.previousPage();
                      }
                    : null,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  _totalPages > 0 ? '$_currentPage / $_totalPages' : '-- / --',
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              IconButton(
                tooltip: 'Page suivante',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: (_totalPages > 0 && _currentPage < _totalPages)
                    ? () {
                        _pdfController.nextPage();
                      }
                    : null,
              ),
              const SizedBox(width: 12),
              const VerticalDivider(width: 1),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Zoom -',
                icon: const Icon(Icons.zoom_out_rounded),
                onPressed: () {
                  final next = math.max(0.5, _pdfController.zoomLevel - 0.25);
                  _pdfController.zoomLevel = next;
                  setState(() => _zoomLevel = next);
                },
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, maxWidth: 64),
                child: Text(
                  '${(_zoomLevel * 100).round()}%',
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Zoom +',
                icon: const Icon(Icons.zoom_in_rounded),
                onPressed: () {
                  final next = math.min(4.0, _pdfController.zoomLevel + 0.25);
                  _pdfController.zoomLevel = next;
                  setState(() => _zoomLevel = next);
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Télécharger',
                onPressed: _savePdf,
                icon: const Icon(Icons.download_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePdf() async {
    try {
      Uint8List? bytes = _bytes;
      if (bytes == null) {
        if (widget.file != null) {
          bytes = await widget.file!.readAsBytes();
        } else if (widget.url != null && widget.url!.trim().isNotEmpty) {
          final resp = await http.get(Uri.parse(widget.url!));
          if (resp.statusCode == 200) bytes = resp.bodyBytes;
        }
      }
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de télécharger le PDF.')),
          );
        }
        return;
      }

      final suggested = (widget.title?.trim().isNotEmpty == true
              ? widget.title!.trim()
              : 'certificat_medical')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName =
          '${suggested}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // 1) Try native folder picker, then save into chosen folder
      try {
        final String? dir = await fs.getDirectoryPath(confirmButtonText: 'Enregistrer');
        if (dir != null && dir.trim().isNotEmpty) {
          final String sep = Platform.pathSeparator;
          final String fullPath = dir.endsWith(sep) ? '$dir$fileName' : '$dir$sep$fileName';
          final file = File(fullPath);
          await file.writeAsBytes(bytes, flush: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('PDF enregistré: $fullPath')),
            );
          }
          return;
        } else {
          // Cancelled by user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enregistrement annulé.')),
            );
          }
          return;
        }
      } catch (_) {
        // 2) Fallback: direct save via FileSaver (emplacement par défaut)
        await FileSaver.instance
            .saveFile(name: fileName, bytes: bytes, mimeType: MimeType.other);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF enregistré sur l\'appareil.')),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')),
        );
      }
    }
  }
}
