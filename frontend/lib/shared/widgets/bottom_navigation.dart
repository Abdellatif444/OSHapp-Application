import 'package:flutter/material.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String userRole;

  const CustomBottomNavigation({
    super.key,
    this.currentIndex = 0,
    required this.onTap,
    this.userRole = 'EMPLOYEE',
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      currentIndex: currentIndex,
      items: _getNavigationItems(),
      onTap: onTap,
    );
  }

  List<BottomNavigationBarItem> _getNavigationItems() {
    switch (userRole.toUpperCase()) {
      case 'EMPLOYEE':
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Mes RDV',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Documents',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alertes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ];
      case 'HR':
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Employés',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Certificats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Rapports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ];
      case 'NURSE':
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Consultations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Dossiers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ];
      case 'DOCTOR':
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Visites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work),
            label: 'Postes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Rapports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ];
      case 'HSE':
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: 'Sécurité',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Indicateurs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Rapports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ];
      default:
        return const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ];
    }
  }
}
