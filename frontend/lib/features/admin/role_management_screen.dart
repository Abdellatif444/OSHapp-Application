import 'package:flutter/material.dart';
import 'package:oshapp/shared/models/role.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/services/auth_service.dart';

import 'create_role_screen.dart';
import 'edit_role_screen.dart';
import 'package:provider/provider.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  RoleManagementScreenState createState() => RoleManagementScreenState();
}

class RoleManagementScreenState extends State<RoleManagementScreen> {
  List<Role> _roles = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final roles = await apiService.getRoles();
      if (mounted) {
        setState(() {
          _roles = roles;
          // Use current user's normalized roles for permissions
          _isAdmin = authService.roles.contains('ADMIN');
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load roles: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateAndRefresh({Role? role}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => role == null
            ? const CreateRoleScreen()
            : EditRoleScreen(role: role),
      ),
    );

    if (result == true) {
      _loadRoles(); // Refresh the list if a change was made
    }
  }

  Future<void> _deleteRole(Role role) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Voulez-vous vraiment supprimer le rôle "${role.name}" ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await Provider.of<ApiService>(context, listen: false).deleteRole(role.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rôle supprimé avec succès!'), backgroundColor: Colors.green),
        );
        _loadRoles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Rôles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _roles.isEmpty
              ? const Center(
                  child: Text('Aucun rôle trouvé.'),
                )
              : ListView.builder(
                  itemCount: _roles.length,
                  itemBuilder: (context, index) {
                    final role = _roles[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(role.name),
                        trailing: _isAdmin
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _navigateAndRefresh(role: role),
                                    tooltip: 'Modifier',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteRole(role),
                                    tooltip: 'Supprimer',
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
        ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () => _navigateAndRefresh(),
              child: const Icon(Icons.add),
            )
          : null
    );
  }
}
