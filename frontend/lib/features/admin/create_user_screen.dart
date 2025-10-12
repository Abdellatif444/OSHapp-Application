import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/services/api_service.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  CreateUserScreenState createState() => CreateUserScreenState();
}

class CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Set<String> _selectedRoles = {};
  bool _isLoading = false;
  bool _isPasswordObscured = true;

  // Liste des rôles disponibles. En production, cela pourrait venir d'une API.
  final List<String> _availableRoles = [
    'ROLE_ADMIN',
    'ROLE_RH',
    'ROLE_NURSE',
    'ROLE_DOCTOR',
    'ROLE_HSE',
    'ROLE_EMPLOYEE'
  ];

  @override
  void initState() {
    super.initState();
  }

  

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins un rôle.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      await apiService.createUser(
        _emailController.text,
        _passwordController.text,
        _selectedRoles.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur créé avec succès !')),
        );
        Navigator.of(context).pop(true); // Retourne true pour indiquer un succès
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
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
        title: const Text('Créer un utilisateur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', hintText: 'nouvel.utilisateur@domaine.com'),
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Veuillez entrer un email valide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
                            TextFormField(
                controller: _passwordController,
                // Use the state variable to control visibility
                obscureText: _isPasswordObscured, 
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  hintText: 'Mot de passe (6+ caractères)',
                  // Add the icon button to the decoration
                  suffixIcon: IconButton(
                    icon: Icon(
                      // Change icon based on state
                      _isPasswordObscured ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      // Update the state on press
                      setState(() {
                        _isPasswordObscured = !_isPasswordObscured;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 6) {
                    return 'Le mot de passe doit contenir au moins 6 caractères.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text('Rôles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                children: _availableRoles.map((role) {
                  final isSelected = _selectedRoles.contains(role);
                  return FilterChip(
                    label: Text(role.replaceFirst('ROLE_', '')),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedRoles.add(role);
                        } else {
                          _selectedRoles.remove(role);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text('Note: Les managers N+1/N+2 peuvent être assignés après la création via l\'écran de gestion des utilisateurs.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _createUser,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Créer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
