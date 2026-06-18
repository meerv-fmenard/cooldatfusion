import 'package:flutter/material.dart';

import '../platform/fullscreen.dart';

/// On the web build this app is required to run full screen. The gate blocks the
/// UI behind a prompt until the user enters full screen (a user gesture is
/// required by browsers), and re-appears if they leave full screen. On native
/// platforms the controller reports unsupported and the child shows directly.
class FullscreenGate extends StatefulWidget {
  const FullscreenGate({super.key, required this.child});

  final Widget child;

  @override
  State<FullscreenGate> createState() => _FullscreenGateState();
}

class _FullscreenGateState extends State<FullscreenGate> {
  late final FullscreenController _fs;

  @override
  void initState() {
    super.initState();
    _fs = createFullscreenController();
    _fs.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fs.removeListener(_onChange);
    _fs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_fs.supported || _fs.isFullscreen) return widget.child;
    return _prompt();
  }

  Widget _prompt() {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ac_unit, color: Color(0xFF4FC3F7), size: 56),
              const SizedBox(height: 18),
              const Text('CoolDatFusion',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('produce value cold-chain simulator',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(height: 28),
              const Text(
                'This high-resolution experience is designed to run full screen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 18),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: _fs.request,
                icon: const Icon(Icons.fullscreen),
                label: const Text('Enter full screen'),
              ),
              const SizedBox(height: 14),
              const Text('Press Esc to exit full screen at any time.',
                  style: TextStyle(color: Colors.white30, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
