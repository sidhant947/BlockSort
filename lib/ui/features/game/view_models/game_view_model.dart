import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blocksort/data/repositories/progress_repository.dart';
import 'package:blocksort/data/services/settings_service.dart';
import 'package:blocksort/domain/models/game_level.dart';
import 'package:blocksort/domain/use_cases/cell_rules.dart';
import 'package:blocksort/domain/use_cases/level_generator.dart';
import 'package:blocksort/ui/core/utils/app_haptics.dart';

@immutable
class _Snapshot {
  const _Snapshot(this.placedPieces, this.moveCount);
  final List<PlacedPiece> placedPieces;
  final int moveCount;
}

@immutable
class GameViewModelState {
  const GameViewModelState({
    this.level,
    this.placedPieces = const [],
    this.selectedPieceId,
    this.previewPlacement,
    this.isValidPreview = false,
    this.isLoading = false,
    this.isComplete = false,
    this.moveCount = 0,
    this.elapsedSeconds = 0,
    this.canUndo = false,
    this.error,
    this.isRandomMode = false,
    this.randomDifficulty,
    this.randomSeed,
    this.randomGridSize,
  });

  final GameLevel? level;
  final List<PlacedPiece> placedPieces;
  final int? selectedPieceId;
  final PlacedPiece? previewPlacement;
  final bool isValidPreview;
  final bool isLoading;
  final bool isComplete;
  final int moveCount;
  final int elapsedSeconds;
  final bool canUndo;
  final String? error;
  final bool isRandomMode;
  final String? randomDifficulty;
  final int? randomSeed;
  final int? randomGridSize;

  List<BlockPiece> get unplacedPieces {
    if (level == null) return const [];
    final placedIds = placedPieces.map((p) => p.pieceId).toSet();
    return level!.pieces.where((p) => !placedIds.contains(p.id)).toList();
  }

  Map<Coord, int> get occupiedMap {
    if (level == null) return const {};
    return CellRules.buildOccupiedMap(placedPieces, level!);
  }

  GameViewModelState copyWith({
    GameLevel? level,
    List<PlacedPiece>? placedPieces,
    int? selectedPieceId,
    bool clearSelectedPiece = false,
    PlacedPiece? previewPlacement,
    bool clearPreview = false,
    bool? isValidPreview,
    bool? isLoading,
    bool? isComplete,
    int? moveCount,
    int? elapsedSeconds,
    bool? canUndo,
    String? error,
    bool? isRandomMode,
    String? randomDifficulty,
    int? randomSeed,
    int? randomGridSize,
  }) {
    return GameViewModelState(
      level: level ?? this.level,
      placedPieces: placedPieces ?? this.placedPieces,
      selectedPieceId:
          clearSelectedPiece ? null : (selectedPieceId ?? this.selectedPieceId),
      previewPlacement:
          clearPreview ? null : (previewPlacement ?? this.previewPlacement),
      isValidPreview: isValidPreview ?? this.isValidPreview,
      isLoading: isLoading ?? this.isLoading,
      isComplete: isComplete ?? this.isComplete,
      moveCount: moveCount ?? this.moveCount,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      canUndo: canUndo ?? this.canUndo,
      error: error,
      isRandomMode: isRandomMode ?? this.isRandomMode,
      randomDifficulty: randomDifficulty ?? this.randomDifficulty,
      randomSeed: randomSeed ?? this.randomSeed,
      randomGridSize: randomGridSize ?? this.randomGridSize,
    );
  }
}

class GameViewModel extends StateNotifier<GameViewModelState> {
  GameViewModel({
    required this.progressRepository,
    required this.levelGenerator,
    required this.settingsService,
  }) : super(const GameViewModelState());

  final ProgressRepository progressRepository;
  final LevelGenerator levelGenerator;
  final SettingsService settingsService;

  static const int _maxUndo = 50;
  final List<_Snapshot> _undoStack = [];
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _stopTimer();
        return;
      }
      if (state.isComplete) {
        _timer?.cancel();
        return;
      }
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> loadLevel(int levelNumber) async {
    _undoStack.clear();
    state = const GameViewModelState(isLoading: true);

    try {
      final level = await levelGenerator.generateAsync(levelNumber);
      if (!mounted) return;

      final progress = await progressRepository.getProgress();
      if (!mounted) return;

      List<PlacedPiece> placedPieces = [];
      int moveCount = 0;
      int elapsed = 0;

      if (progress.savedLevelNumber == levelNumber &&
          progress.savedPieces != null) {
        placedPieces = progress.savedPieces!
            .where((p) => p.length == 3)
            .map((p) => PlacedPiece(pieceId: p[0], r: p[1], c: p[2]))
            .toList();
        moveCount = progress.savedMoveCount;
        elapsed = progress.savedElapsedSeconds;
      }

      final isComplete = CellRules.isComplete(placedPieces, level);

      state = GameViewModelState(
        level: level,
        placedPieces: placedPieces,
        moveCount: moveCount,
        elapsedSeconds: elapsed,
        isComplete: isComplete,
      );

      if (!isComplete) _startTimer();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load level: $e',
      );
    }
  }

  int _parseGridSize(String difficulty) {
    final lower = difficulty.toLowerCase().trim();
    if (lower.contains('x')) {
      final parts = lower.split('x');
      final size = int.tryParse(parts[0].trim());
      if (size != null && size >= 5 && size <= 10) return size;
    }
    switch (lower) {
      case 'easy':
      case '5x5':
        return 5;
      case 'medium':
      case '6x6':
        return 6;
      case 'hard':
      case '7x7':
        return 7;
      case '8x8':
        return 8;
      case '9x9':
        return 9;
      case '10x10':
        return 10;
      default:
        return 5;
    }
  }

  Future<void> loadRandomLevel(String difficulty, {int? seed}) async {
    _undoStack.clear();
    final levelSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    final gridSize = _parseGridSize(difficulty);

    state = GameViewModelState(
      isLoading: true,
      isRandomMode: true,
      randomDifficulty: difficulty,
      randomSeed: levelSeed,
      randomGridSize: gridSize,
    );

    try {
      final level = await levelGenerator.generateRandomAsync(
        gridSize: gridSize,
        seed: levelSeed,
      );
      if (!mounted) return;

      state = state.copyWith(
        level: level,
        placedPieces: const [],
        moveCount: 0,
        elapsedSeconds: 0,
        canUndo: false,
        isLoading: false,
        randomGridSize: gridSize,
      );
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load random level: $e',
      );
    }
  }

  void selectPiece(int? pieceId) {
    if (state.isComplete) return;
    AppHaptics.selectionClick();
    if (state.selectedPieceId == pieceId) {
      state = state.copyWith(clearSelectedPiece: true, clearPreview: true);
    } else {
      state = state.copyWith(
        selectedPieceId: pieceId,
        clearPreview: true,
      );
    }
  }

  void rotatePiece(int pieceId) {
    final level = state.level;
    if (state.isComplete || level == null) return;
    final isPlaced = state.placedPieces.any((p) => p.pieceId == pieceId);
    if (isPlaced) return;

    final updatedPieces = level.pieces.map((p) {
      if (p.id == pieceId) {
        return p.rotate90();
      }
      return p;
    }).toList();

    AppHaptics.selectionClick();

    state = state.copyWith(
      level: GameLevel(
        levelNumber: level.levelNumber,
        gridSize: level.gridSize,
        pieces: updatedPieces,
      ),
      selectedPieceId: pieceId,
      clearPreview: true,
    );
  }

  void updatePreview(int pieceId, int r, int c) {
    final level = state.level;
    if (state.isComplete || level == null) return;
    final piece = level.getPieceById(pieceId);
    if (piece == null) return;

    final occupiedWithoutSelf = <Coord>{};
    for (final placed in state.placedPieces) {
      if (placed.pieceId == pieceId) continue;
      final p = level.getPieceById(placed.pieceId);
      if (p == null) continue;
      for (final cell in p.cells) {
        occupiedWithoutSelf.add(Coord(placed.r + cell.r, placed.c + cell.c));
      }
    }

    final isValid = CellRules.canPlacePiece(
      piece,
      r,
      c,
      level.gridSize,
      occupiedWithoutSelf,
    );

    state = state.copyWith(
      previewPlacement: PlacedPiece(pieceId: pieceId, r: r, c: c),
      isValidPreview: isValid,
    );
  }

  void clearPreview() {
    if (state.previewPlacement != null) {
      state = state.copyWith(clearPreview: true, isValidPreview: false);
    }
  }

  bool placePiece(int pieceId, int r, int c) {
    final level = state.level;
    if (state.isComplete || level == null) return false;
    final piece = level.getPieceById(pieceId);
    if (piece == null) return false;

    final occupiedWithoutSelf = <Coord>{};
    for (final placed in state.placedPieces) {
      if (placed.pieceId == pieceId) continue;
      final p = level.getPieceById(placed.pieceId);
      if (p == null) continue;
      for (final cell in p.cells) {
        occupiedWithoutSelf.add(Coord(placed.r + cell.r, placed.c + cell.c));
      }
    }

    if (!CellRules.canPlacePiece(
      piece,
      r,
      c,
      level.gridSize,
      occupiedWithoutSelf,
    )) {
      AppHaptics.lightImpact();
      clearPreview();
      return false;
    }

    _pushUndo();

    final updated =
        state.placedPieces.where((p) => p.pieceId != pieceId).toList()
          ..add(PlacedPiece(pieceId: pieceId, r: r, c: c));

    final isComplete = CellRules.isComplete(updated, level);

    if (isComplete) {
      AppHaptics.heavyImpact();
      AppHaptics.vibrate();
      _stopTimer();
    } else {
      AppHaptics.mediumImpact();
    }

    state = state.copyWith(
      placedPieces: updated,
      clearPreview: true,
      clearSelectedPiece: true,
      moveCount: state.moveCount + 1,
      isComplete: isComplete,
      canUndo: _undoStack.isNotEmpty,
    );

    _persistInProgress();
    return true;
  }

  void removePiece(int pieceId) {
    final level = state.level;
    if (state.isComplete || level == null) return;
    final idx = state.placedPieces.indexWhere((p) => p.pieceId == pieceId);
    if (idx == -1) return;

    _pushUndo();
    final updated = List<PlacedPiece>.from(state.placedPieces)..removeAt(idx);

    AppHaptics.lightImpact();

    state = state.copyWith(
      placedPieces: updated,
      clearPreview: true,
      clearSelectedPiece: true,
      moveCount: state.moveCount + 1,
      isComplete: false,
      canUndo: _undoStack.isNotEmpty,
    );

    _persistInProgress();
  }

  void _pushUndo() {
    _undoStack.add(
      _Snapshot(List<PlacedPiece>.from(state.placedPieces), state.moveCount),
    );
    if (_undoStack.length > _maxUndo) {
      _undoStack.removeAt(0);
    }
  }

  void undo() {
    if (_undoStack.isEmpty || state.level == null || state.isComplete) return;
    final snapshot = _undoStack.removeLast();
    AppHaptics.lightImpact();

    state = state.copyWith(
      placedPieces: snapshot.placedPieces,
      moveCount: snapshot.moveCount,
      canUndo: _undoStack.isNotEmpty,
      clearPreview: true,
      clearSelectedPiece: true,
    );
    _persistInProgress();
  }

  void revealHint() {
    final level = state.level;
    if (level == null || state.isComplete) return;

    final hintPlaced = CellRules.suggestHint(state.placedPieces, level);
    if (hintPlaced == null) return;

    final piece = level.getPieceById(hintPlaced.pieceId);
    if (piece == null) return;

    _pushUndo();

    final resetPiece = piece.resetRotation();
    final updatedPieces = level.pieces
        .map((p) => p.id == resetPiece.id ? resetPiece : p)
        .toList();
    final currentLevel = GameLevel(
      levelNumber: level.levelNumber,
      gridSize: level.gridSize,
      pieces: updatedPieces,
    );

    final hintCoords =
        resetPiece.placedCoords(hintPlaced.r, hintPlaced.c).toSet();
    final updated = <PlacedPiece>[];

    for (final placed in state.placedPieces) {
      if (placed.pieceId == hintPlaced.pieceId) continue;
      final p = currentLevel.getPieceById(placed.pieceId);
      if (p == null) continue;
      final coords = p.placedCoords(placed.r, placed.c);
      final hasOverlap = coords.any((c) => hintCoords.contains(c));
      if (!hasOverlap) {
        updated.add(placed);
      }
    }

    updated.add(hintPlaced);

    final isComplete = CellRules.isComplete(updated, currentLevel);
    if (isComplete) {
      AppHaptics.heavyImpact();
      AppHaptics.vibrate();
      _stopTimer();
    } else {
      AppHaptics.mediumImpact();
    }

    state = state.copyWith(
      level: currentLevel,
      placedPieces: updated,
      moveCount: state.moveCount + 1,
      isComplete: isComplete,
      canUndo: _undoStack.isNotEmpty,
      clearPreview: true,
      clearSelectedPiece: true,
    );

    _persistInProgress();
  }

  void _persistInProgress() {
    final level = state.level;
    if (level == null || state.isRandomMode || state.isComplete) return;
    progressRepository.saveInProgress(
      level.levelNumber,
      state.placedPieces,
      state.moveCount,
      state.elapsedSeconds,
    );
  }

  Future<void> completeLevel() async {
    final level = state.level;
    if (level == null || !state.isComplete) return;
    if (state.isRandomMode) {
      await progressRepository.addRandomLevelMoves(state.moveCount);
    } else {
      await progressRepository.completeLevel(level.levelNumber, state.moveCount);
      if (!mounted) return;
      await progressRepository.recordLevelResult(
        level.levelNumber,
        state.moveCount,
        state.elapsedSeconds,
      );
      if (!mounted) return;
      await progressRepository.clearInProgress();
    }
  }

  Future<void> resetLevel() async {
    final level = state.level;
    if (level == null) return;
    if (state.isRandomMode) {
      await loadRandomLevel(
        state.randomDifficulty ?? '5x5',
        seed: state.randomSeed,
      );
    } else {
      await progressRepository.clearInProgress();
      if (!mounted) return;
      await loadLevel(level.levelNumber);
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
