import 'package:flutter/material.dart';
import 'package:oshapp/shared/models/employee.dart';
import 'package:oshapp/shared/models/employee_creation_request_dto.dart';
import 'package:oshapp/shared/models/user.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/widgets/progress_overlay.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  const ProfileScreen({super.key, required this.user});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

enum _ProfileMenuAction { settings, support, logout }

class ProfileScreenState extends State<ProfileScreen> {
  Future<Employee>? _employeeFuture;
  bool _isEditing = false;
  String? _gender; // HOMME | FEMME

  // Controllers for the form fields
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _departmentController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _jobTitleController = TextEditingController();
    _departmentController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _jobTitleController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _loadProfile() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _employeeFuture = apiService.getCurrentEmployeeProfile().then((employee) {
        // Initialize controllers with the latest employee data
        _phoneController.text = employee.phoneNumber ?? '';
        _addressController.text = employee.address ?? '';
        _jobTitleController.text = employee.jobTitle ?? '';
        _departmentController.text = employee.department ?? '';
        _gender = _normalizeGenderValue(employee.gender);
        return employee;
      });
    });
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  String _genderLabel(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'HOMME':
        return 'Homme';
      case 'FEMME':
        return 'Femme';
      default:
        return '-';
    }
  }

  String? _normalizeGenderValue(String? value) {
    if (value == null) return null;
    final s = value.trim().toUpperCase();
    if (s == 'HOMME' || s == 'FEMME') return s;
    return null;
  }

  void _saveProfile(Employee currentEmployee) async {
    final apiService = Provider.of<ApiService>(context, listen: false);

    final requestDto = EmployeeCreationRequestDTO(
      id: currentEmployee.id,
      firstName: currentEmployee.firstName ?? '',
      lastName: currentEmployee.lastName ?? '',
      email: widget.user.email,
      phoneNumber: _phoneController.text,
      address: _addressController.text,
      position: _jobTitleController.text,
      department: _departmentController.text,
      gender: _normalizeGenderValue(_gender),
    );

    try {
      final updatedEmployee =
          await apiService.updateEmployeeProfile(requestDto);

      // Push the update to the global auth state so the whole app reflects changes.
      final authService = Provider.of<AuthService>(context, listen: false);
      authService.applyEmployeeUpdate(updatedEmployee);

      if (!mounted) return; // Check if the widget is still in the tree

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profil mis à jour avec succès !'),
            backgroundColor: Colors.green),
      );
      setState(() {
        _isEditing = false;
        // Refresh the profile data with the response from the server
        _employeeFuture = Future.value(updatedEmployee);
        // Re-initialize controllers with the new data
        _phoneController.text = updatedEmployee.phoneNumber ?? '';
        _addressController.text = updatedEmployee.address ?? '';
        _jobTitleController.text = updatedEmployee.jobTitle ?? '';
        _departmentController.text = updatedEmployee.department ?? '';
        _gender = _normalizeGenderValue(updatedEmployee.gender);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de la mise à jour : $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _handleMenuSelection(_ProfileMenuAction action) {
    switch (action) {
      case _ProfileMenuAction.logout:
        final authService = Provider.of<AuthService>(context, listen: false);
        final lang = Localizations.localeOf(context).languageCode;
        final isFr = lang.toLowerCase().startsWith('fr');

        final title = isFr ? 'Déconnexion en cours' : 'Logging out';
        final successTitle = isFr ? 'Déconnecté' : 'Logged out';
        final serverMsg =
            isFr ? 'Déconnexion du serveur...' : 'Signing out from server...';
        final googleMsg = isFr
            ? 'Nettoyage de la session Google...'
            : 'Cleaning Google session...';
        final localMsg = isFr
            ? 'Nettoyage des données locales...'
            : 'Clearing local data...';
        final finalMsg = isFr ? 'Finalisation...' : 'Finalizing...';

        showThemedProgressDialog(
          context: context,
          title: title,
          successTitle: successTitle,
          initialMessage: serverMsg,
          task: (onProgress) async {
            String _msgFor(double p) {
              if (p < 0.2) return serverMsg;
              if (p < 0.6) return googleMsg;
              if (p < 0.9) return localMsg;
              return finalMsg;
            }

            await authService.logout(
              navigate: true,
              onProgress: (p, _m) => onProgress(p, _msgFor(p)),
            );
          },
        );
        break;
      case _ProfileMenuAction.settings:
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Page Paramètres à implémenter')));
        break;
      case _ProfileMenuAction.support:
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Page Support à implémenter')));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Employee>(
        future: _employeeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorState(snapshot.error);
          }
          final employee = snapshot.data!;
          return _buildProfileView(employee);
        },
      ),
    );
  }

  Widget _buildProfileView(Employee employee) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 250.0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context)),
          actions: [
            _isEditing
                ? IconButton(
                    icon: const Icon(Icons.save_outlined),
                    onPressed: () => _saveProfile(employee))
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _toggleEdit),
            _buildPopupMenu(),
          ],
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: true,
            titlePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: Text(
              employee.fullName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            background: _buildProfileHeader(employee),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildInfoSection(
                title: 'Informations Personnelles',
                children: {
                  'Email': Text(widget.user.email,
                      style: Theme.of(context).textTheme.bodyLarge),
                  'Téléphone': _isEditing
                      ? TextFormField(controller: _phoneController)
                      : Text(_phoneController.text),
                  'Sexe': _isEditing
                      ? DropdownButtonFormField<String>(
                          value: _gender,
                          items: const [
                            DropdownMenuItem<String>(value: 'HOMME', child: Text('Homme')),
                            DropdownMenuItem<String>(value: 'FEMME', child: Text('Femme')),
                          ],
                          onChanged: (v) => setState(() => _gender = _normalizeGenderValue(v)),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.wc),
                          ),
                        )
                      : Text(_genderLabel(_gender)),
                  'Adresse': _isEditing
                      ? TextFormField(
                          controller: _addressController, maxLines: null)
                      : Text(_addressController.text),
                },
              ),
              const SizedBox(height: 24),
              _buildInfoSection(
                title: 'Informations Professionnelles',
                children: {
                  'Poste': _isEditing
                      ? TextFormField(controller: _jobTitleController)
                      : Text(_jobTitleController.text),
                  'Département': _isEditing
                      ? TextFormField(controller: _departmentController)
                      : Text(_departmentController.text),
                  'Matricule': Text(employee.id,
                      style: Theme.of(context).textTheme.bodyLarge),
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(
      {required String title, required Map<String, Widget> children}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: children.entries.map((entry) {
              return ListTile(
                title: Text(entry.key, style: theme.textTheme.bodySmall),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                  child: entry.value,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(Employee employee) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withAlpha(26),
            theme.colorScheme.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: employee.profilePicture != null
                  ? NetworkImage(employee.profilePicture!)
                  : null,
              child: employee.profilePicture == null
                  ? Text(employee.initials,
                      style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(employee.jobTitle ?? '', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  PopupMenuButton<_ProfileMenuAction> _buildPopupMenu() {
    return PopupMenuButton<_ProfileMenuAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: _handleMenuSelection,
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<_ProfileMenuAction>>[
        const PopupMenuItem<_ProfileMenuAction>(
          value: _ProfileMenuAction.settings,
          child: ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Paramètres')),
        ),
        const PopupMenuItem<_ProfileMenuAction>(
          value: _ProfileMenuAction.support,
          child: ListTile(
              leading: Icon(Icons.help_outline), title: Text('Support')),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_ProfileMenuAction>(
          value: _ProfileMenuAction.logout,
          child: ListTile(
            leading:
                Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Déconnexion',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 16),
            const Text('Impossible de charger le profil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error?.toString() ?? 'Une erreur inconnue est survenue.',
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: _loadProfile,
            ),
          ],
        ),
      ),
    );
  }
}
