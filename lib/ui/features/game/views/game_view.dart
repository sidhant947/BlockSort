import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blocksort/domain/models/game_level.dart';
import 'package:blocksort/ui/core/theme/app_colors.dart';
import 'package:blocksort/ui/core/utils/app_haptics.dart';
import 'package:blocksort/ui/core/widgets/tangible_button.dart';
import 'package:blocksort/ui/features/game/view_models/game_view_model.dart';
import 'package:blocksort/ui/providers.dart';

class _BlockTheme {
  final Color bg;
  final Color textColor;
  final Color shadowColor;
  const _BlockTheme(this.bg, this.textColor, this.shadowColor);
}

const List<_BlockTheme> _blockThemes = [
  _BlockTheme(Color(0xFFF7D547), Color(0xFF594300), Color(0xFFD8B324)),
  _BlockTheme(Color(0xFF5F72E4), Color(0xFF16236B), Color(0xFF3F51C4)),
  _BlockTheme(Color(0xFFFF5953), Color(0xFF6B0F0C), Color(0xFFD63C36)),
  _BlockTheme(Color(0xFFBDB2FA), Color(0xFF3B277E), Color(0xFF998BE0)),
  _BlockTheme(Color(0xFF98E674), Color(0xFF26540F), Color(0xFF75C24F)),
  _BlockTheme(Color(0xFFFF9D54), Color(0xFF662900), Color(0xFFD67932)),
  _BlockTheme(Color(0xFF52E3D0), Color(0xFF0C544B), Color(0xFF32C0AE)),
  _BlockTheme(Color(0xFFFF7FB2), Color(0xFF6B0C39), Color(0xFFD9578A)),
];

class GameView extends ConsumerStatefulWidget {
  const GameView({
    super.key,
    required this.levelNumber,
    this.isRandom = false,
    this.randomDifficulty = '5x5',
  });

  final int levelNumber;
  final bool isRandom;
  final String randomDifficulty;

  @override
  ConsumerState<GameView> createState() => _GameViewState();
}

class _GameViewState extends ConsumerState<GameView> {
  final GlobalKey _gridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      if (widget.isRandom) {
        ref
            .read(gameViewModelProvider.notifier)
            .loadRandomLevel(widget.randomDifficulty);
      } else {
        ref.read(gameViewModelProvider.notifier).loadLevel(widget.levelNumber);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final state = ref.watch(gameViewModelProvider);
    AppColors.currentTheme = settings.theme;
    AppHaptics.isEnabled = settings.isHapticsEnabled;

    ref.listen<GameViewModelState>(gameViewModelProvider, (prev, next) {
      if (next.isComplete && !(prev?.isComplete ?? false)) {
        _onLevelComplete(next);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        iconSize: 18,
                        onTap: () => Navigator.pop(context),
                      ),
                      Text(
                        state.isRandomMode
                            ? '${state.level?.gridSize ?? state.randomGridSize ?? 5}x${state.level?.gridSize ?? state.randomGridSize ?? 5}'
                            : 'Level ${widget.levelNumber}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.headingDark,
                        ),
                      ),
                      _circleButton(
                        icon: Icons.refresh_rounded,
                        iconSize: 20,
                        onTap: () => ref
                            .read(gameViewModelProvider.notifier)
                            .resetLevel(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : state.error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    state.error!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => ref
                                        .read(gameViewModelProvider.notifier)
                                        .resetLevel(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _buildGame(state),
                ),
              ],
            ),
            ConfettiExplosion(trigger: state.isComplete),
          ],
        ),
      ),
    );
  }

  Widget _buildGame(GameViewModelState state) {
    final level = state.level;
    if (level == null) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('Moves', '${state.moveCount}', Icons.trending_up_rounded),
              _verticalDivider(),
              _stat(
                'Time',
                _formatTime(state.elapsedSeconds),
                Icons.timer_outlined,
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _buildGrid(state, level),
              ),
            ),
          ),
        ),
        if (state.isComplete)
          _buildCompletionBottomBar(state)
        else ...[
          SizedBox(
            height: 104,
            child: _buildPieceTray(state, level),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: (state.canUndo && !state.isComplete)
                    ? () {
                        AppHaptics.lightImpact();
                        ref.read(gameViewModelProvider.notifier).undo();
                      }
                    : null,
                child: Opacity(
                  opacity: (state.canUndo && !state.isComplete) ? 1.0 : 0.35,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (state.canUndo && !state.isComplete)
                            ? AppColors.border
                            : AppColors.border.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.headingDark.withValues(alpha: 0.08),
                          offset: const Offset(0, 3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.undo_rounded,
                          color: AppColors.headingDark,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Undo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.headingDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (ref.watch(settingsProvider).isHintEnabled) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: !state.isComplete
                      ? () =>
                          ref.read(gameViewModelProvider.notifier).revealHint()
                      : null,
                  child: Opacity(
                    opacity: !state.isComplete ? 1.0 : 0.35,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: !state.isComplete
                              ? AppColors.border
                              : AppColors.border.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.headingDark.withValues(alpha: 0.08),
                            offset: const Offset(0, 3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lightbulb_rounded,
                            color: Color(0xFFFFCC00),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hint',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.headingDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Drag piece to grid or tap to place  |  Tap placed block to return',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.subtext,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGrid(GameViewModelState state, GameLevel level) {
    final n = level.gridSize;
    final isDark = AppColors.currentTheme.isDark;
    final occupiedMap = state.occupiedMap;

    Set<Coord> previewCoords = {};
    if (state.previewPlacement != null) {
      final p = level.getPieceById(state.previewPlacement!.pieceId);
      if (p != null) {
        previewCoords = p
            .placedCoords(
              state.previewPlacement!.r,
              state.previewPlacement!.c,
            )
            .toSet();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideLength =
            math.min(constraints.maxWidth, constraints.maxHeight);
        final cellSize = sideLength / n;

        return DragTarget<BlockPiece>(
          key: _gridKey,
          onWillAcceptWithDetails: (details) {
            final box =
                _gridKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return false;
            final local = box.globalToLocal(details.offset);
            final c = (local.dx / cellSize).floor();
            final r = (local.dy / cellSize).floor();
            ref
                .read(gameViewModelProvider.notifier)
                .updatePreview(details.data.id, r, c);
            return true;
          },
          onMove: (details) {
            final box =
                _gridKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = box.globalToLocal(details.offset);
            final c = (local.dx / cellSize).floor();
            final r = (local.dy / cellSize).floor();
            ref
                .read(gameViewModelProvider.notifier)
                .updatePreview(details.data.id, r, c);
          },
          onLeave: (_) {
            ref.read(gameViewModelProvider.notifier).clearPreview();
          },
          onAcceptWithDetails: (details) {
            final box =
                _gridKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = box.globalToLocal(details.offset);
            final c = (local.dx / cellSize).floor();
            final r = (local.dy / cellSize).floor();
            ref
                .read(gameViewModelProvider.notifier)
                .placePiece(details.data.id, r, c);
          },
          builder: (context, candidateData, rejectedData) {
            return SizedBox(
              width: sideLength,
              height: sideLength,
              child: Stack(
                children: [
                  Column(
                    children: List.generate(n, (r) {
                      return Expanded(
                        child: Row(
                          children: List.generate(n, (c) {
                            final coord = Coord(r, c);
                            final pieceId = occupiedMap[coord];
                            final isPreview = previewCoords.contains(coord);
                            final isValidPreview = state.isValidPreview;

                            Widget cellWidget;
                            if (pieceId != null) {
                              final piece = level.getPieceById(pieceId);
                              final theme = _blockThemes[
                                  (piece?.colorIndex ?? pieceId) %
                                      _blockThemes.length];
                              cellWidget = GestureDetector(
                                onTap: () {
                                  ref
                                      .read(gameViewModelProvider.notifier)
                                      .removePiece(pieceId);
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(2.0),
                                  decoration: BoxDecoration(
                                    color: theme.bg,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.shadowColor,
                                        offset: const Offset(0, 3),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else if (isPreview) {
                              final previewPiece = state.previewPlacement != null
                                  ? level.getPieceById(
                                      state.previewPlacement!.pieceId)
                                  : null;
                              final previewTheme = _blockThemes[
                                  (previewPiece?.colorIndex ?? 0) %
                                      _blockThemes.length];

                              cellWidget = Container(
                                margin: const EdgeInsets.all(2.0),
                                decoration: BoxDecoration(
                                  color: isValidPreview
                                      ? previewTheme.bg
                                          .withValues(alpha: 0.75)
                                      : Colors.red.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isValidPreview
                                        ? Colors.white
                                        : Colors.red,
                                    width: 2.0,
                                  ),
                                ),
                              );
                            } else {
                              cellWidget = GestureDetector(
                                onTap: () {
                                  if (state.selectedPieceId != null) {
                                    ref
                                        .read(gameViewModelProvider.notifier)
                                        .placePiece(
                                            state.selectedPieceId!, r, c);
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(2.0),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.surface
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isDark
                                        ? Border.all(
                                            color: AppColors.gridLines,
                                            width: 1.0)
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? const Color(0xFF0A0A0A)
                                            : const Color(0xFFE4E2DC),
                                        offset: const Offset(0, 3),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Expanded(child: cellWidget);
                          }),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPieceTray(GameViewModelState state, GameLevel level) {
    final unplaced = state.unplacedPieces;
    if (unplaced.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: unplaced.map((piece) {
              final isSelected = state.selectedPieceId == piece.id;
              final theme =
                  _blockThemes[piece.colorIndex % _blockThemes.length];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Draggable<BlockPiece>(
                  data: piece,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Transform.scale(
                      scale: 1.15,
                      child: _renderPieceWidget(piece, theme, cellSize: 24),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _pieceCard(piece, theme, isSelected: false),
                  ),
                  onDragStarted: () {
                    AppHaptics.selectionClick();
                  },
                  onDragEnd: (_) {
                    ref.read(gameViewModelProvider.notifier).clearPreview();
                  },
                  child: GestureDetector(
                    onTap: () {
                      ref
                          .read(gameViewModelProvider.notifier)
                          .selectPiece(piece.id);
                    },
                    child: _pieceCard(piece, theme, isSelected: isSelected),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _pieceCard(
    BlockPiece piece,
    _BlockTheme theme, {
    required bool isSelected,
  }) {
    final maxDim = math.max(piece.width, piece.height);
    final double cellSize = math.min(48.0 / maxDim, 15.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.accent : AppColors.border,
          width: isSelected ? 2.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.25)
                : AppColors.headingDark.withValues(alpha: 0.08),
            offset: isSelected ? const Offset(0, 4) : const Offset(0, 2),
            blurRadius: isSelected ? 8 : 4,
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: _renderPieceWidget(piece, theme, cellSize: cellSize),
        ),
      ),
    );
  }

  Widget _renderPieceWidget(
    BlockPiece piece,
    _BlockTheme theme, {
    required double cellSize,
  }) {
    final cellSet = piece.cells.toSet();

    return SizedBox(
      width: piece.width * cellSize,
      height: piece.height * cellSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(piece.height, (r) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(piece.width, (c) {
              final exists = cellSet.contains(Coord(r, c));
              if (!exists) {
                return SizedBox(width: cellSize, height: cellSize);
              }
              return Container(
                width: cellSize,
                height: cellSize,
                padding: const EdgeInsets.all(1.2),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.bg,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor,
                        offset: const Offset(0, 1.5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 20,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled
          ? () {
              AppHaptics.selectionClick();
              onTap();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.border,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.headingDark.withValues(alpha: 0.08),
                offset: const Offset(0, 3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: AppColors.headingDark,
          ),
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _stat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: AppColors.headingDark,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.headingDark,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.subtext,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.gridLines,
    );
  }

  Future<void> _onLevelComplete(GameViewModelState state) async {
    await ref.read(gameViewModelProvider.notifier).completeLevel();
  }

  Widget _buildCompletionBottomBar(GameViewModelState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Congratulations!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: 10),
          TangibleButton(
            text: state.isRandomMode ? 'Play Again' : 'Next Level',
            height: 42,
            backgroundColor: AppColors.primary,
            textColor: AppColors.headingDark,
            borderColor: AppColors.border,
            onPressed: () {
              final notifier = ref.read(gameViewModelProvider.notifier);
              if (state.isRandomMode) {
                notifier.loadRandomLevel(state.randomDifficulty ?? '5x5');
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        GameView(levelNumber: widget.levelNumber + 1),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          TangibleButton(
            text: 'Home',
            isSecondary: true,
            height: 42,
            backgroundColor: AppColors.surface,
            textColor: AppColors.headingDark,
            borderColor: AppColors.border,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
          TangibleButton(
            text: 'Buy Me a Coffee',
            isSecondary: true,
            height: 42,
            backgroundColor: AppColors.surface,
            textColor: AppColors.headingDark,
            borderColor: AppColors.border,
            onPressed: _openKoFiUrl,
          ),
        ],
      ),
    );
  }

  Future<void> _openKoFiUrl() async {
    final Uri uri = Uri.parse('https://ko-fi.com/sidhant947');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {}
    }
  }
}

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double rotation;
  double rotationSpeed;
  Color color;
  bool isCircle;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.isCircle,
  });

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 300.0 * dt;
    vx *= math.pow(0.98, dt * 60);
    vy *= math.pow(0.98, dt * 60);
    rotation += rotationSpeed * dt;
  }
}

class ConfettiExplosion extends StatefulWidget {
  final bool trigger;
  const ConfettiExplosion({super.key, required this.trigger});

  @override
  State<ConfettiExplosion> createState() => _ConfettiExplosionState();
}

class _ConfettiExplosionState extends State<ConfettiExplosion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(_tick);

    if (widget.trigger) {
      _burst();
    }
  }

  @override
  void didUpdateWidget(covariant ConfettiExplosion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _burst();
    }
  }

  void _burst() {
    _particles.clear();
    final List<Color> colors = [
      Colors.white,
      Colors.white70,
      Colors.white54,
      Colors.white30,
      const Color(0xFF888888),
      const Color(0xFFCCCCCC),
      const Color(0xFF555555),
      const Color(0xFFAAAAAA),
    ];

    for (int i = 0; i < 80; i++) {
      final double angle = _random.nextDouble() * 2 * math.pi;
      final double speed = 150 + _random.nextDouble() * 250;
      _particles.add(ConfettiParticle(
        x: 0.5,
        y: 0.4,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 150,
        size: 6 + _random.nextDouble() * 8,
        rotation: _random.nextDouble() * 2 * math.pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 10,
        color: colors[_random.nextInt(colors.length)],
        isCircle: _random.nextBool(),
      ));
    }
    _controller.forward(from: 0.0);
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.update(0.016);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: ConfettiPainter(particles: _particles),
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final double px = p.x * size.width;
      final double py = p.y * size.height;

      if (px < 0 || px > size.width || py > size.height) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      final Paint paint = Paint()..color = p.color;

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}
