import 'package:flutter/material.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:provider/provider.dart';

class CreateRoleScreen extends StatefulWidget {
  const CreateRoleScreen({super.key});

  @override
  State<CreateRoleScreen> createState() => _CreateRoleScreenState();
}

class _CreateRoleScreenState extends State<CreateRoleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final Set<String> _selectedPermissions = {};
  bool _isLoading = false;
  late final ApiService _apiService;

  // This list would ideally come from the backend or a shared config

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
  }

  final List<String> _allPermissions = [
    'read',
    'write',
    'delete',
    'manage_users',
    'manage_employees',
    'write_medical_records',
    'read_profile',
    'generate_reports',
    'view_dashboard_stats',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins une permission.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
            await _apiService.createRole(
        _nameController.text,
        _selectedPermissions.toList(), // Passer les permissions
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rôle créé avec succès!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true); // Return true to refresh the previous screen
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
        title: const Text('Créer un Rôle'),
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
                decoration: const InputDecoration(
                  labelText: 'Nom du Rôle',
                  hintText: 'Ex: ROLE_AUDITEUR',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le nom du rôle est obligatoire.';
                  }
                  if (!value.startsWith('ROLE_')) {
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
                  final isSelected = _selectedPermissions.contains(permission);
                  return FilterChip(
                    label: Text(permission),
                    selected: isSelected,
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
                    : const Text('Créer le Rôle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
