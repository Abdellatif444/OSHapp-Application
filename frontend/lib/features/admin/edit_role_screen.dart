import 'package:flutter/material.dart';
import 'package:oshapp/shared/models/role.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:provider/provider.dart';

class EditRoleScreen extends StatefulWidget {
  final Role role;

  const EditRoleScreen({super.key, required this.role});

  @override
  State<EditRoleScreen> createState() => _EditRoleScreenState();
}

class _EditRoleScreenState extends State<EditRoleScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late Set<String> _selectedPermissions;
  bool _isLoading = false;
  late final ApiService _apiService;

  final List<String> _allPermissions = [
    'read', 'write', 'delete', 'manage_users', 'manage_employees',
    'write_medical_records', 'read_profile', 'generate_reports', 'view_dashboard_stats',
  ];

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _nameController = TextEditingController(text: widget.role.name);
    _selectedPermissions = Set<String>.from(widget.role.permissions);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _apiService.updateRole(widget.role.id, _nameController.text, _selectedPermissions.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rôle mis à jour avec succès!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true); // Return true to refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le Rôle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom du Rôle'),
                validator: (value) {
                  if (value == null || !value.startsWith('ROLE_')) {
                    return 'Le nom doit commencer par "ROLE_".';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text('Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                children: _allPermissions.map((permission) {
                  return FilterChip(
                    label: Text(permission),
                    selected: _selectedPermissions.contains(permission),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedPermissions.add(permission);
                        } else {
                          _selectedPermissions.remove(permission);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Mettre à jour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
