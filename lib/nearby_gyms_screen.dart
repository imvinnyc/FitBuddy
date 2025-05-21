// lib/nearby_gyms_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'main.dart' show homeBtn, showErrorToast;

/// ────────────────────────────────────────────────────────────────────────────
/// NearbyGymsScreen  – find gyms around the user
/// ────────────────────────────────────────────────────────────────────────────
class NearbyGymsScreen extends StatefulWidget {
  const NearbyGymsScreen({super.key});
  @override
  State<NearbyGymsScreen> createState() => _NearbyGymsScreenState();
}

class _NearbyGymsScreenState extends State<NearbyGymsScreen> {
  bool _loading = true;
  Position? _position;
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _initLocationAndMap();
  }

  Future<void> _initLocationAndMap() async {
    final perm = await Geolocator.requestPermission();

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      showErrorToast('Location permission denied');
      setState(() => _loading = false);
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _position = pos;
        _loading = false;
      });

      if (!kIsWeb) {
        final url = _mapsEmbedUrl(pos.latitude, pos.longitude);
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(url));
      }
    } catch (e) {
      showErrorToast('Location error: $e');
      setState(() => _loading = false);
    }
  }

  String _mapsEmbedUrl(double lat, double lng) =>
      'https://www.google.com/maps/search/gyms/@$lat,$lng,14z';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Nearby Gyms'),
          actions: [homeBtn(context)],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _position == null
                ? const Center(child: Text('Location unavailable'))
                : kIsWeb
                    ? HtmlWidget(
                        '<iframe '
                        'src="${_mapsEmbedUrl(_position!.latitude, _position!.longitude)}" '
                        'width="100%" height="100%" style="border:none;"></iframe>',
                      )
                    : (_controller == null
                        ? const Center(child: CircularProgressIndicator())
                        : WebViewWidget(controller: _controller!)),
      );
}
