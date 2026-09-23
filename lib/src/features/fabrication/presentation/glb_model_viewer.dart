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
    model-viewer { display: block; }
    model-viewer { --poster-color: #f7f7f8; }
    #status {
      position: fixed;
      inset: 0;
      display: grid;
      place-items: center;
      padding: 24px;
      color: #3f3f46;
      font: 14px/1.45 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      text-align: center;
      pointer-events: none;
    }
    #status[hidden] { display: none; }
  </style>
</head>
<body>
  <model-viewer id="viewer" src="model.glb" alt="Fabrication 3D model" camera-controls interaction-prompt="none" shadow-intensity="1" exposure="1.1"></model-viewer>
  <div id="status">Loading 3D model...</div>
  <script>
    const viewer = document.getElementById('viewer');
    const status = document.getElementById('status');
    const post = (type, message) => window.chrome?.webview?.postMessage({ type, message });
    const fail = (message) => {
      status.hidden = false;
      status.textContent = message;
      post('error', message);
    };

    window.addEventListener('error', (event) => {
      fail(event.message || 'The model viewer script could not be loaded.');
    });
    window.addEventListener('unhandledrejection', (event) => {
      fail(event.reason?.message || String(event.reason || 'The model viewer could not start.'));
    });
    customElements.whenDefined('model-viewer').catch(() => {
      fail('The model viewer component could not be initialized.');
    });

    viewer.addEventListener('progress', (event) => {
      const progress = Math.round((event.detail?.totalProgress || 0) * 100);
      status.textContent = progress > 0 ? `Loading 3D model... \${progress}%` : 'Loading 3D model...';
    });
    viewer.addEventListener('load', () => {
      status.hidden = true;
      post('loaded', '');
    });
    viewer.addEventListener('error', (event) => {
      fail(event.detail?.message || 'The model file is invalid or could not be read.');
    });
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
