import 'package:flutter/material.dart';

import '../services/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final Settings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _hostController;
  late bool _useFahrenheit;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.settings.host);
    _useFahrenheit = widget.settings.useFahrenheit;
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    final settings = Settings(
      host: host.isEmpty ? Settings.defaultHost : host,
      useFahrenheit: _useFahrenheit,
    );
    await settings.save();
    if (mounted) Navigator.pop(context, settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _hostController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Device address',
              hintText: Settings.defaultHost,
              helperText:
                  'Hostname or IP of the ESP32. If pooltemp.local doesn\'t '
                  'resolve (common on Android), use the IP address instead.',
              helperMaxLines: 3,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Fahrenheit'),
            subtitle: const Text('Show temperatures in °F instead of °C'),
            value: _useFahrenheit,
            onChanged: (v) => setState(() => _useFahrenheit = v),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
