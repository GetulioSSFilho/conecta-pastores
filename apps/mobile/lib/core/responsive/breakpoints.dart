import 'package:flutter/widgets.dart';

/// Sistema unico de responsividade.
///
/// Nenhuma tela deve comparar larguras "na mao": use `context.windowSize`
/// ou [ResponsiveBuilder]. Assim os pontos de quebra mudam em um lugar so.
///
/// Faixas baseadas nas window size classes do Material 3:
///  - compact  (< 600)   celular: bottom navigation, uma coluna.
///  - medium   (600-1199) tablet / janela estreita: navigation rail, 1-2 colunas.
///  - expanded (>= 1200) desktop: sidebar com rotulos, grids de 3+ colunas.
enum WindowSize {
  compact,
  medium,
  expanded;

  static const mediumMin = 600.0;
  static const expandedMin = 1200.0;

  static WindowSize fromWidth(double width) {
    if (width >= expandedMin) return WindowSize.expanded;
    if (width >= mediumMin) return WindowSize.medium;
    return WindowSize.compact;
  }

  bool get isCompact => this == WindowSize.compact;
  bool get isMedium => this == WindowSize.medium;
  bool get isExpanded => this == WindowSize.expanded;

  /// Pelo menos tablet.
  bool get isAtLeastMedium => this != WindowSize.compact;

  /// Colunas sugeridas para grids de cards.
  int get gridColumns => switch (this) {
    WindowSize.compact => 1,
    WindowSize.medium => 2,
    WindowSize.expanded => 3,
  };

  /// Padding horizontal padrao do conteudo.
  double get pagePadding => switch (this) {
    WindowSize.compact => 16,
    WindowSize.medium => 24,
    WindowSize.expanded => 32,
  };
}

extension WindowSizeContext on BuildContext {
  WindowSize get windowSize =>
      WindowSize.fromWidth(MediaQuery.sizeOf(this).width);
}

/// Constroi layouts diferentes por faixa, usando a largura disponivel (nao a da tela).
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          switch (WindowSize.fromWidth(constraints.maxWidth)) {
            WindowSize.expanded => (expanded ?? medium ?? compact)(context),
            WindowSize.medium => (medium ?? compact)(context),
            WindowSize.compact => compact(context),
          },
    );
  }
}
