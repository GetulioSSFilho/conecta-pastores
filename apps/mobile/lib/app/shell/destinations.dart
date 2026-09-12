import 'package:flutter/material.dart';

import '../../features/auth/domain/auth_user.dart';

/// Grupo visual da sidebar.
enum NavGroup { main, communication, resources, management }

/// Destino de navegacao principal.
///
/// `visibleFor` so decide o que APARECE no menu. Quem decide o acesso e a API:
/// abrir a URL manualmente sem permissao resulta em 403 tratado pela tela.
class AppDestination {
  const AppDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.group,
    required this.visibleFor,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final NavGroup group;
  final bool Function(AuthUser user) visibleFor;

  bool matches(String location) =>
      location == path || location.startsWith('$path/');
}

bool _always(AuthUser _) => true;

/// Catalogo unico de destinos. Sidebar, rail, bottom nav e "Mais" leem daqui.
final appDestinations = <AppDestination>[
  const AppDestination(
    path: '/dashboard',
    label: 'Início',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
    group: NavGroup.main,
    visibleFor: _always,
  ),
  const AppDestination(
    path: '/assistant',
    label: 'Assistente IA',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome_rounded,
    group: NavGroup.main,
    visibleFor: _always,
  ),
  AppDestination(
    path: '/network',
    label: 'Minha Rede',
    icon: Icons.account_tree_outlined,
    selectedIcon: Icons.account_tree_rounded,
    group: NavGroup.main,
    visibleFor: (u) => u.can('network.read') && u.isLeader,
  ),
  AppDestination(
    path: '/pastors',
    label: 'Pastores',
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
    group: NavGroup.main,
    visibleFor: (u) =>
        u.can('pastor.read') && (u.isLeader || u.can('pastor.write')),
  ),
  AppDestination(
    path: '/churches',
    label: 'Igrejas',
    icon: Icons.church_outlined,
    selectedIcon: Icons.church_rounded,
    group: NavGroup.main,
    visibleFor: (u) =>
        u.can('church.read') && (u.isLeader || u.can('church.write')),
  ),
  AppDestination(
    path: '/care',
    label: 'Acompanhamentos',
    icon: Icons.volunteer_activism_outlined,
    selectedIcon: Icons.volunteer_activism_rounded,
    group: NavGroup.main,
    visibleFor: (u) => u.can('care.read'),
  ),
  AppDestination(
    path: '/channel',
    label: 'Canal',
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign_rounded,
    group: NavGroup.communication,
    visibleFor: (u) => u.can('channel.read'),
  ),
  AppDestination(
    path: '/calendar',
    label: 'Agenda',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    group: NavGroup.communication,
    visibleFor: (u) => u.can('event.read'),
  ),
  AppDestination(
    path: '/requests',
    label: 'Solicitações',
    icon: Icons.support_agent_outlined,
    selectedIcon: Icons.support_agent_rounded,
    group: NavGroup.communication,
    visibleFor: (u) => u.can('request.read'),
  ),
  AppDestination(
    path: '/training',
    label: 'Formação',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
    group: NavGroup.resources,
    visibleFor: (u) => u.can('training.read'),
  ),
  AppDestination(
    path: '/documents',
    label: 'Documentos',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder_rounded,
    group: NavGroup.resources,
    visibleFor: (u) => u.can('document.read'),
  ),
  AppDestination(
    path: '/credential',
    label: 'Credencial',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge_rounded,
    group: NavGroup.resources,
    visibleFor: (u) => u.can('credential.read') && u.pastorId != null,
  ),
  AppDestination(
    path: '/map',
    label: 'Mapa',
    icon: Icons.public_outlined,
    selectedIcon: Icons.public_rounded,
    group: NavGroup.resources,
    visibleFor: (u) => u.can('church.read') && u.isLeader,
  ),
  AppDestination(
    path: '/reports',
    label: 'Relatórios',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    group: NavGroup.management,
    visibleFor: (u) => u.can('report.read'),
  ),
  AppDestination(
    path: '/admin',
    label: 'Administração',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings_rounded,
    group: NavGroup.management,
    visibleFor: (u) =>
        u.canAny(const ['user.read', 'role.manage', 'audit.read']),
  ),
];

List<AppDestination> destinationsFor(AuthUser user) =>
    appDestinations.where((d) => d.visibleFor(user)).toList(growable: false);

/// Bottom navigation (celular): 4 destinos fixos + "Mais".
List<AppDestination> compactDestinationsFor(AuthUser user) {
  const preferred = ['/dashboard', '/channel', '/network', '/calendar'];
  final allowed = destinationsFor(user);
  final primary = [
    for (final path in preferred) ...allowed.where((d) => d.path == path),
  ];
  // Pastor sem rede: ocupa a vaga com o proximo destino disponivel.
  for (final d in allowed) {
    if (primary.length >= 4) break;
    if (!primary.contains(d)) primary.add(d);
  }
  return primary;
}

String groupLabel(NavGroup group) => switch (group) {
  NavGroup.main => 'Pastoral',
  NavGroup.communication => 'Comunicação',
  NavGroup.resources => 'Recursos',
  NavGroup.management => 'Gestão',
};
