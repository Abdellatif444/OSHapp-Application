import 'package:flutter/material.dart';
import 'package:oshapp/shared/models/company.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/errors/api_exception.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'edit_company_profile_screen.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  late final ApiService _apiService;
  Company? _company;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _fetchCompanyProfile();
  }

  Future<void> _fetchCompanyProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final company = await _apiService.getCompanyProfile();
      if (mounted) {
        setState(() {
          _company = company;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.statusCode == 404) {
          // No company profile yet: show empty state instead of an error
          setState(() {
            _company = null;
            _error = null;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Erreur de chargement du profil: ${e.toString()}';
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil de l\'entreprise'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCompanyProfile,
        child: _buildBody(),
      ),
      floatingActionButton: _buildEditButton(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchCompanyProfile, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    if (_company == null) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final cs = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.apartment, size: 72, color: cs.primary),
              const SizedBox(height: 16),
              Text("Aucune donnée d'entreprise trouvée", style: textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                "Créez le profil de l'entreprise pour commencer.",
                style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                textAlign: TextAlign.center,
              ),
              if (authService.roles.contains('ADMIN')) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditCompanyProfileScreen(company: _blankCompany()),
                      ),
                    );
                    if (result == true) {
                      _fetchCompanyProfile();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Créer le profil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildProfileCard(_company!),
          const SizedBox(height: 20),
          _buildContactInfo(_company!),
          const SizedBox(height: 20),
          _buildCompanyDetails(_company!),
          const SizedBox(height: 20),
          _buildInsurersAndContributions(_company!),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Company company) {
    final cs = Theme.of(context).colorScheme;
    final onContainer = cs.onPrimaryContainer;
    final String? logoFullUrl = _apiService.getPublicFileUrl(company.logoUrl);
    return Card
    (
      color: cs.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            logoFullUrl != null
                ? ClipOval(
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: Image.network(
                        logoFullUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => CircleAvatar(
                          radius: 36,
                          backgroundColor: onContainer.withOpacity(0.1),
                          child: Icon(Icons.apartment, size: 36, color: onContainer),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 36,
                    backgroundColor: onContainer.withOpacity(0.1),
                    child: Icon(Icons.apartment, size: 36, color: onContainer),
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name.isEmpty ? '—' : company.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: onContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (company.sector.isEmpty ? 'Secteur non renseigné' : company.sector),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: onContainer.withOpacity(0.9),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo(Company company) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
        title: const Text('Adresse'),
        subtitle: Text(company.address),
      ),
    );
  }

  Widget _buildCompanyDetails(Company company) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.badge, size: 18),
                  label: Text('SIRET: ${company.siret}'),
                  backgroundColor: cs.secondaryContainer,
                  labelStyle: TextStyle(color: cs.onSecondaryContainer),
                ),
                Chip(
                  avatar: const Icon(Icons.people, size: 18),
                  label: Text('Effectif: ${company.headcount}'),
                  backgroundColor: cs.secondaryContainer,
                  labelStyle: TextStyle(color: cs.onSecondaryContainer),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.phone, color: Theme.of(context).colorScheme.primary),
            title: const Text('Téléphone'),
            subtitle: Text(company.phone),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
            title: const Text('Email'),
            subtitle: Text(company.email),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.web, color: Theme.of(context).colorScheme.primary),
            title: const Text('Site Web'),
            subtitle: Text(company.website ?? 'Non disponible'),
          ),
        ],
      ),
    );
  }

  Widget _buildInsurersAndContributions(Company company) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Assureurs et cotisations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.policy, color: Theme.of(context).colorScheme.primary),
            title: const Text('Assureur AT/MP'),
            subtitle: Text(company.insurerAtMp ?? 'Non renseigné'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.policy, color: Theme.of(context).colorScheme.primary),
            title: const Text('Assureur spécialisé hors AT/MP'),
            subtitle: Text(company.insurerHorsAtMp ?? 'Non renseigné'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
            title: const Text('Autres cotisations sociales'),
            subtitle: Text(company.otherSocialContributions ?? 'Non renseigné'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.article, color: Theme.of(context).colorScheme.primary),
            title: const Text('Détails supplémentaires'),
            subtitle: Text(company.additionalDetails ?? 'Non renseigné'),
          ),
        ],
      ),
    );
  }

  Company _blankCompany() {
    return Company(
      id: null,
      name: '',
      address: '',
      phone: '',
      email: '',
      sector: '',
      siret: '',
      headcount: 0,
      website: null,
      insurerAtMp: null,
      insurerHorsAtMp: null,
      otherSocialContributions: null,
      additionalDetails: null,
    );
  }

  Widget? _buildEditButton() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.roles.contains('ADMIN')) {
      final bool creating = _company == null;
      return FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditCompanyProfileScreen(company: _company ?? _blankCompany()),
            ),
          );
          if (result == true) {
            _fetchCompanyProfile(); // Refresh data if changes were made
          }
        },
        tooltip: creating ? 'Créer le profil' : 'Modifier le profil',
        child: Icon(creating ? Icons.add : Icons.edit),
      );
    }
    return null;
  }
}
