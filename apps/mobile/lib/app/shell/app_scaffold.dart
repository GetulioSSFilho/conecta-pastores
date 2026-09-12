import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_brand.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/notifications/data/notifications_providers.dart';
import 'destinations.dart';

/// Moldura autenticada da aplicacao.
///
///  - expanded (>= 1200): sidebar com rotulos agrupados + barra superior.
///  - medium (600-1199): rail so com icones (tooltip) + barra superior.
///  - compact (< 600): bottom navigation; cada tela desenha seu proprio cabecalho.
///
/// A URL e a fonte da verdade do item selecionado: F5 e "voltar" do navegador
/// mantem a navegacao coerente.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthSignedIn) return const SizedBox.shrink();
    final user = auth.user;
    final size = context.windowSize;

    final body = Column(
      children: [
        if (auth.offline) const _OfflineBanner(),
        Expanded(child: child),
      ],
    );

    if (size.isCompact) {
      final items = compactDestinationsFor(user);
      final index = items.indexWhere((d) => d.matches(location));
      return Scaffold(
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index >= 0 ? index : items.length,
          onDestinationSelected: (i) =>
              context.go(i < items.length ? items[i].path : '/more'),
          destinations: [
            for (final d in items)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
            const NavigationDestination(
              icon: Icon(Icons.menu_rounded),
              selectedIcon: Icon(Icons.menu_open_rounded),
              label: 'Mais',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          size.isExpanded
              ? _Sidebar(user: user, location: location)
              : _Rail(user: user, location: location),
          Expanded(
            child: Column(
              children: [
                _TopBar(user: user, compactBrand: false),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sidebar (expanded)
// -----------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.user, required this.location});

  final AuthUser user;
  final String location;

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(user);
    return Container(
      width: 256,
      color: AppColors.primary,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: InkWell(
                onTap: () => context.go('/dashboard'),
                borderRadius: BorderRadius.circular(AppTokens.radius12),
                child: const AppBrandLockup(
                  color: Colors.white,
                  markSize: 34,
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final group in NavGroup.values) ...[
                    if (destinations.any((d) => d.group == group)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                        child: Text(
                          groupLabel(group).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final d in destinations.where(
                        (d) => d.group == group,
                      ))
                        _SidebarTile(
                          destination: d,
                          selected: d.matches(location),
                        ),
                    ],
                  ],
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            _SidebarTile(
              destination: AppDestination(
                path: '/settings',
                label: 'Configurações',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                group: NavGroup.management,
                visibleFor: (_) => true,
              ),
              selected: location.startsWith('/settings'),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.destination,
    required this.selected,
    this.padding = const EdgeInsets.only(bottom: 2),
  });

  final AppDestination destination;
  final bool selected;
  final EdgeInsets padding;

  // ListTile ja expoe papel de botao, rotulo e estado selecionado para leitores
  // de tela (um Semantics manual sobre InkWell nao gerava no na arvore web).
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: Colors.white.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        horizontalTitleGap: 12,
        minLeadingWidth: 20,
        leading: Icon(
          selected ? destination.selectedIcon : destination.icon,
          size: 20,
          color: selected ? AppColors.secondary : Colors.white70,
        ),
        title: Text(
          destination.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.82),
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: () => context.go(destination.path),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Rail (medium)
// -----------------------------------------------------------------------------

class _Rail extends StatelessWidget {
  const _Rail({required this.user, required this.location});

  final AuthUser user;
  final String location;

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(user);
    return Container(
      width: 76,
      color: AppColors.primary,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 20),
            IconButton(
              tooltip: 'Início',
              onPressed: () => context.go('/dashboard'),
              icon: const AppBrandMark(size: 30, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  for (final d in destinations)
                    _RailButton(destination: d, selected: d.matches(location)),
                ],
              ),
            ),
            _RailButton(
              destination: AppDestination(
                path: '/settings',
                label: 'Configurações',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                group: NavGroup.management,
                visibleFor: (_) => true,
              ),
              selected: location.startsWith('/settings'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.destination, required this.selected});

  final AppDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: IconButton(
        tooltip: destination.label,
        isSelected: selected,
        onPressed: () => context.go(destination.path),
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius12),
          ),
          minimumSize: const Size(48, 44),
        ),
        icon: Icon(
          selected ? destination.selectedIcon : destination.icon,
          color: selected ? AppColors.secondary : Colors.white70,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Barra superior (medium/expanded)
// -----------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.user, required this.compactBrand});

  final AuthUser user;
  final bool compactBrand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (user.can('pastor.read') && user.isLeader)
            SizedBox(
              width: 320,
              child: _SearchLauncher(onTap: () => context.go('/pastors')),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Notificações',
            onPressed: () => context.go('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 8),
          UserMenuButton(user: user),
        ],
      ),
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppTokens.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.pill),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: AppColors.mutedInk),
              SizedBox(width: 10),
              Text(
                'Buscar pastores',
                style: TextStyle(color: AppColors.mutedInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar com menu da conta. Reutilizado pelo cabecalho mobile das telas.
class UserMenuButton extends ConsumerWidget {
  const UserMenuButton({super.key, required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Conta',
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            context.go('/profile');
          case 'settings':
            context.go('/settings');
          case 'logout':
            await ref.read(authControllerProvider.notifier).logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                user.email,
                style: const TextStyle(fontSize: 12, color: AppColors.mutedInk),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (user.pastorId != null)
          const PopupMenuItem(
            value: 'profile',
            child: ListTile(
              leading: Icon(Icons.person_outline_rounded),
              title: Text('Meu perfil'),
            ),
          ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Configurações'),
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout_rounded),
            title: Text('Sair'),
          ),
        ),
      ],
      child: Tooltip(
        message: 'Menu da conta',
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.softPrimary,
          foregroundImage: user.avatarUrl != null
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: Text(
            user.initials,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialBanner(
      backgroundColor: AppColors.softOrange,
      leading: const Icon(Icons.cloud_off_rounded, color: AppColors.ink),
      content: const Text(
        'Sem conexão com o servidor. Exibindo dados recentes.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              ref.read(authControllerProvider.notifier).retryRestore(),
          child: const Text('Tentar novamente'),
        ),
      ],
    );
  }
}
