import 'package:flutter/material.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ApiService _apiService;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic> _settings = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final settings = await _apiService.getSettings();
      const defaultSettings = {
        'notifications.email.enabled': 'true',
        'notifications.sms.enabled': 'false',
        'security.session.timeout.minutes': '30',
        'system.maintenance.mode': 'false',
      };
      defaultSettings.forEach((key, value) {
        settings.putIfAbsent(key, () => value);
      });

      setState(() {
        _settings = settings;
        _settings.forEach((key, value) {
          _controllers[key] = TextEditingController(text: value.toString());
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement des paramètres: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      try {
        final Map<String, dynamic> updatedSettings = {};
        _controllers.forEach((key, controller) {
          updatedSettings[key] = controller.text;
        });

        await _apiService.updateSettings(updatedSettings);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paramètres mis à jour avec succès !'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la sauvegarde: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres Généraux'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: _buildSettingTiles(),
                  ),
                ),
    );
  }

  List<Widget> _buildSettingTiles() {
    if (_controllers.isEmpty) {
      return [const Center(child: Text('Aucun paramètre trouvé.'))];
    }
    
    final Map<String, List<String>> groupedKeys = {
      'Notifications': [
        'notifications.email.enabled',
        'notifications.sms.enabled'
      ],
      'Sécurité': [
        'security.session.timeout.minutes'
      ],
      'Application': [
        'system.maintenance.mode'
      ]
    };

    List<Widget> widgets = [];
    groupedKeys.forEach((groupTitle, keys) {
      widgets.add(_buildSectionTitle(groupTitle));
      for (var key in keys) {
        if (_controllers.containsKey(key)) {
          widgets.add(_buildSettingEditor(key, _controllers[key]!));
          widgets.add(const SizedBox(height: 8));
        }
      }
      widgets.add(const Divider());
    });

    return widgets;
  }

  Widget _buildSettingEditor(String key, TextEditingController controller) {
    String label = _getLabelForKey(key);
    String? subTitle = _getSubtitleForKey(key);

    if (controller.text == 'true' || controller.text == 'false') {
      bool currentValue = controller.text == 'true';
      return SwitchListTile(
        title: Text(label),
        subtitle: subTitle != null ? Text(subTitle) : null,
        value: currentValue,
        onChanged: (value) {
          setState(() {
            controller.text = value.toString();
          });
        },
        activeColor: key.contains('maintenance') ? Colors.red : Theme.of(context).colorScheme.primary,
      );
    }

    return TextFormField(
      controller: controller,
      keyboardType: _getKeyboardTypeForKey(key),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ce champ ne peut être vide.';
        }
        if (key.contains('minutes') && int.tryParse(value) == null) {
          return 'Veuillez entrer un nombre valide.';
        }
        return null;
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 16, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  String _getLabelForKey(String key) {
    switch (key) {
      case 'notifications.email.enabled':
        return 'Activer les notifications par email';
      case 'notifications.sms.enabled':
        return 'Activer les notifications par SMS';
      case 'security.session.timeout.minutes':
        return 'Délai d\'expiration de la session (minutes)';
      case 'system.maintenance.mode':
        return 'Activer le mode maintenance';
      default:
        return key;
    }
  }
  
  String? _getSubtitleForKey(String key) {
    switch (key) {
      case 'system.maintenance.mode':
        return 'Les utilisateurs non-administrateurs seront déconnectés.';
      default:
        return null;
    }
  }

  TextInputType _getKeyboardTypeForKey(String key) {
    if (key.contains('minutes')) {
      return TextInputType.number;
    }
    return TextInputType.text;
  }
}
