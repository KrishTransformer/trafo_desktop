import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart';

class GlbModelViewer extends StatefulWidget {
  const GlbModelViewer({required this.bytes, super.key});

  final List<int> bytes;

  @override
  State<GlbModelViewer> createState() => _GlbModelViewerState();
}

class _GlbModelViewerState extends State<GlbModelViewer> {
  final WebviewController _controller = WebviewController();
  StreamSubscription<dynamic>? _messageSubscription;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeViewer();
  }

  Future<void> _initializeViewer() async {
    try {
      final viewerDirectory = await _writeViewerFiles();
      await _controller.initialize();
      _messageSubscription = _controller.webMessage.listen(_handleMessage);
      await _controller.addVirtualHostNameMapping(
        'trafo-model.local',
        viewerDirectory.path,
        WebviewHostResourceAccessKind.allow,
      );
      await _controller.loadUrl('https://trafo-model.local/viewer.html');
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'The 3D viewer could not start. Install the Microsoft Edge WebView2 Runtime and reopen the page.';
        });
      }
    }
  }

  void _handleMessage(dynamic message) {
    if (!mounted || message is! Map || message['type'] != 'error') {
      return;
    }

    setState(() {
      _errorMessage = 'Unable to load this GLB model: ${message['message']}';
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _ViewerMessage(icon: Icons.error_outline, message: errorMessage);
    }

    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Webview(_controller),
    );
  }

  Future<Directory> _writeViewerFiles() async {
    final cacheDirectory = await getTemporaryDirectory();
    final viewerDirectory = Directory(
      '${cacheDirectory.path}${Platform.pathSeparator}trafo_glb_viewer',
    );
    await viewerDirectory.create(recursive: true);
    await File(
      '${viewerDirectory.path}${Platform.pathSeparator}model.glb',
    ).writeAsBytes(widget.bytes, flush: true);
    await File(
      '${viewerDirectory.path}${Platform.pathSeparator}model-viewer.min.js',
    ).writeAsString(
      await rootBundle.loadString('assets/vendor/model-viewer.min.js'),
      flush: true,
    );
    await File(
      '${viewerDirectory.path}${Platform.pathSeparator}viewer.html',
    ).writeAsString(_viewerHtml(), flush: true);
    return viewerDirectory;
  }

  String _viewerHtml() {
    return '''<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script type="module" src="model-viewer.min.js"></script>
  <style>
    html, body, model-viewer { width: 100%; height: 100%; margin: 0; overflow: hidden; background: #f7f7f8; }
    model-viewer { --poster-color: #f7f7f8; }
  </style>
</head>
<body>
  <model-viewer id="viewer" src="model.glb" alt="Fabrication 3D model" camera-controls interaction-prompt="none" shadow-intensity="1" exposure="1.1"></model-viewer>
  <script>
    const viewer = document.getElementById('viewer');
    const post = (type, message) => window.chrome?.webview?.postMessage({ type, message });
    viewer.addEventListener('load', () => post('loaded', ''));
    viewer.addEventListener('error', (event) => post('error', event.detail?.message || 'The model file is invalid or could not be read.'));
  </script>
</body>
</html>''';
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
