# Design system — Conecta Pastores

Este documento formaliza a referência visual de [`design_system.png`](design_system.png) para implementação e revisão do Flutter. A imagem continua sendo a fonte visual primária; este arquivo registra como os elementos aprovados estão representados no código.

## Princípios

- Visual institucional, acolhedor e limpo.
- Fundo claro, superfícies brancas, bordas discretas e cantos arredondados.
- Azul-petróleo como ação primária, turquesa como ação selecionada e verde/amarelo/vermelho para estados.
- Mobile com experiência própria e navegação inferior; web com sidebar e conteúdo central.
- Nenhuma tela nova deve ser criada sem uma composição visual correspondente e validada.

## Tokens

| Grupo | Token | Valor |
| --- | --- | --- |
| Cor | `AppColors.primary` | `#0F4C5C` |
| Cor | `AppColors.secondary` | `#14B8A6` |
| Cor | `AppColors.accent` | `#F5B008` |
| Cor | `AppColors.success` | `#22C55E` |
| Cor | `AppColors.alert` | `#EF4444` |
| Cor | `AppColors.neutral` | `#687280` |
| Cor | `AppColors.background` | `#F8FAFB` |
| Cor | `AppColors.surface` | `#FFFFFF` |
| Espaçamento | `space4 / 8 / 12 / 16 / 20 / 24 / 32` | escala base |
| Raio | `radius8 / 12 / 16 / 24` | escala de componentes |
| Raio | `pill` | `999` |

Fonte e tema: `core/theme/app_theme.dart`. A família Inter está embutida em
`assets/fonts/` nos pesos 400, 500, 600, 700 e 800. Os tokens de cor,
espaçamento e raio ficam em `core/theme/`.

## Componentes compartilhados

- `AppBrandMark` e `AppBrandLockup`: marca do Login, Credencial e sidebar web.
- A marca é renderizada a partir de `assets/Logo.svg`; o componente aplica a
  cor contextual sem redesenhar o símbolo em Canvas.
- `AppCard`: superfície com borda/raio e suporte opcional a toque.
- `MetricCard`: métricas do dashboard com ação opcional.
- `AppFilterChip`: filtros selecionáveis de Canal, Rede e Solicitações.
- `AppBottomNav`: navegação mobile com cinco destinos.
- `AppAvatar`: avatar com iniciais e asset de imagem como fallback.
- `StatusChip`: estados de sucesso, atenção, erro e informação.
- `SectionHeader`: títulos e ações de seção.
- `PageHeader`: cabeçalho compacto reutilizado nas listas e formulários.
- `AppLoadingState`, `AppErrorState` e `AppEmptyState`: estados comuns.
- `FlutterMap`/`TileLayer`: mapa cartográfico com tiles reais, pan, pinch zoom,
  controles de zoom, atribuição visível e fallback para `world_map.png` quando
  a rede não estiver disponível.

## Matriz de telas

| Composição na referência | Implementação |
| --- | --- |
| Splash / abertura | `features/auth/presentation/splash_screen.dart` |
| Login | `features/auth/presentation/login_screen.dart` |
| Início do pastor | `features/dashboard/presentation/pastor_dashboard_screen.dart` |
| Início da liderança | `features/dashboard/presentation/leader_dashboard_screen.dart` |
| Minha Rede / organograma | `features/network/presentation/network_screen.dart` |
| Perfil 360 | `features/profile/presentation/profile_screen.dart` |
| Credencial Digital | `features/credentials/presentation/credential_screen.dart` |
| Mapa Mundial | `features/map/presentation/world_map_screen.dart` |
| Canal | `features/channel/presentation/channel_screen.dart` |
| Agenda | `features/schedule/presentation/schedule_screen.dart` |
| Solicitações | `features/requests/presentation/requests_screen.dart` |
| Dashboard web | `features/dashboard/presentation/web_dashboard_screen.dart` |
| Lista de Pastores | `features/pastors/presentation/pastors_screen.dart` |
| Cadastro de Pastor | `features/pastors/presentation/pastor_form_screen.dart` |
| Igrejas | `features/churches/presentation/churches_screen.dart` |
| Cadastro de Igreja | `features/churches/presentation/church_form_screen.dart` |
| Cuidado Pastoral | `features/care/presentation/care_screen.dart` |
| Registrar Acompanhamento | `features/care/presentation/care_form_screen.dart` |
| Relatórios | `features/reports/presentation/reports_screen.dart` |
| Administração | `features/admin/presentation/admin_screen.dart` |
| QR Code | `features/credentials/presentation/qr_code_screen.dart` |

## Contrato de interação mockada

- Card de pessoa abre `ProfileScreen` com dados de `MockPastors`.
- Filtros alteram imediatamente o conjunto visível.
- Barras do gráfico alteram mês, destaque e valor selecionado.
- País abre `WorldMapScreen(initialCountry: ..., focusCountry: true)` com
  marcadores agrupados nas coordenadas mockadas daquele país.
- Resumo do mapa abre a lista de pastores do país; marcador e item da lista abrem o perfil.
- Busca do Canal abre um diálogo de publicações; o resultado selecionado abre seu conteúdo.
- Métricas da liderança abrem Rede ou Solicitações; a métrica `> 30 dias` abre a Rede já filtrada.
- Notificações encaminham para a área relacionada (Agenda, Canal, Formação ou Documentos).
- Ações sem backend exibem modal ou `SnackBar` explicativo, nunca ficam sem resposta.
- No desktop, os destinos da sidebar permanecem no painel central via `IndexedStack`.
- `MockAppDataStore` é a fonte única dos vínculos entre pastor, igreja e acompanhamento;
  os formulários notificam as listas e preservam os mesmos IDs.

## Validação

- Viewport mobile de referência automatizada: `390×844`.
- Viewport web de referência automatizada: `1180×800` e shell `1280×900`.
- Goldens: `apps/mobile/test/goldens/`.
- O harness dos goldens usa `AppTheme.light`, evitando diferenças do tema
  padrão do Flutter nas telas capturadas isoladamente.
- Suíte atual: `flutter analyze` sem issues e 39 testes passando.
- Build: `flutter build web --release` concluído com sucesso.
- Runtime web validado localmente em mobile e desktop com Playwright + SwiftShader;
  logo, fonte, imagens e navegação renderizaram sem erros de página.
- A comparação manual em navegador/emulador real ainda é uma etapa externa pendente quando uma superfície gráfica estiver disponível.
