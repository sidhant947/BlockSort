import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:blocksort/domain/models/game_level.dart';

class LevelGenerator {
  final Map<int, GameLevel> _cache = {};
  final Set<int> _generating = {};

  static final List<List<Coord>> shapeTemplates = [
    [const Coord(0, 1), const Coord(1, 0), const Coord(1, 1), const Coord(1, 2), const Coord(2, 1)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(1, 0), const Coord(1, 1)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(0, 2), const Coord(0, 3)],
    [const Coord(0, 0), const Coord(1, 0), const Coord(2, 0), const Coord(3, 0)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(0, 2)],
    [const Coord(0, 0), const Coord(1, 0), const Coord(2, 0)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(0, 2), const Coord(1, 1)],
    [const Coord(0, 1), const Coord(1, 0), const Coord(1, 1), const Coord(2, 1)],
    [const Coord(1, 0), const Coord(1, 1), const Coord(1, 2), const Coord(0, 1)],
    [const Coord(0, 0), const Coord(1, 0), const Coord(2, 0), const Coord(1, 1)],
    [const Coord(0, 0), const Coord(1, 0), const Coord(2, 0), const Coord(2, 1)],
    [const Coord(0, 1), const Coord(1, 1), const Coord(2, 1), const Coord(2, 0)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(1, 0), const Coord(2, 0)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(1, 1), const Coord(2, 1)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(0, 2), const Coord(1, 0)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(0, 2), const Coord(1, 2)],
    [const Coord(1, 0), const Coord(0, 1), const Coord(0, 2), const Coord(0, 0)],
    [const Coord(0, 0), const Coord(1, 0), const Coord(1, 1), const Coord(1, 2)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(1, 1), const Coord(1, 2)],
    [const Coord(0, 1), const Coord(0, 2), const Coord(1, 0), const Coord(1, 1)],
    [const Coord(0, 0), const Coord(1, 0), const Coord(1, 1), const Coord(2, 1)],
    [const Coord(0, 1), const Coord(1, 0), const Coord(1, 1), const Coord(2, 0)],
    [const Coord(0, 0), const Coord(1, 0), const Coord(1, 1)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(1, 0)],
    [const Coord(0, 0), const Coord(0, 1), const Coord(1, 1)],
    [const Coord(0, 1), const Coord(1, 0), const Coord(1, 1)],
    [const Coord(0, 0), const Coord(0, 1)],
    [const Coord(0, 0), const Coord(1, 0)],
  ];

  GameLevel generate(int levelNumber) {
    if (_cache.containsKey(levelNumber)) {
      return _cache.remove(levelNumber)!;
    }
    return _generateInternal(levelNumber);
  }

  Future<GameLevel> generateAsync(int levelNumber) async {
    if (_cache.containsKey(levelNumber)) {
      return _cache.remove(levelNumber)!;
    }
    return compute(_isolateGenerate, levelNumber);
  }

  static GameLevel _isolateGenerate(int levelNumber) {
    return LevelGenerator()._generateInternal(levelNumber);
  }

  GameLevel _generateInternal(int levelNumber) {
    final gridSize = _getGridSize(levelNumber);
    final random = Random(levelNumber * 7919 + 17);
    return _generateLevelWithSeed(levelNumber, gridSize, random);
  }

  void pregenerateAround(int currentLevel, {int range = 1}) {
    for (int i = 0; i <= range; i++) {
      final levelNumber = currentLevel + i;
      if (levelNumber < 1) continue;
      if (!_cache.containsKey(levelNumber) && !_generating.contains(levelNumber)) {
        _generating.add(levelNumber);
        compute(_isolateGenerate, levelNumber).then((level) {
          _cache[levelNumber] = level;
          _generating.remove(levelNumber);
        }).catchError((e) {
          _generating.remove(levelNumber);
        });
      }
    }
  }

  Future<GameLevel> generateRandomAsync({required int gridSize, required int seed}) {
    return compute(_isolateGenerateRandom, {'gridSize': gridSize, 'seed': seed});
  }

  static GameLevel _isolateGenerateRandom(Map<String, int> params) {
    return LevelGenerator().generateRandom(
      gridSize: params['gridSize']!,
      seed: params['seed']!,
    );
  }

  GameLevel generateRandom({required int gridSize, required int seed}) {
    final random = Random(seed);
    return _generateLevelWithSeed(-1, gridSize, random);
  }

  int _getGridSize(int level) {
    if (level <= 5) return 5;
    if (level <= 15) return 6;
    if (level <= 30) return 7;
    if (level <= 50) return 8;
    if (level <= 75) return 9;
    return 10;
  }

  GameLevel _generateLevelWithSeed(int levelNumber, int gridSize, Random random) {
    for (int attempt = 0; attempt < 50; attempt++) {
      final subSeed = random.nextInt(1000000);
      final rng = Random(subSeed);
      final pieces = _tryPartition(gridSize, rng);
      if (pieces != null && pieces.isNotEmpty) {
        return GameLevel(
          levelNumber: levelNumber,
          gridSize: gridSize,
          pieces: pieces,
        );
      }
    }

    final fallbackPieces = _generateFallback(gridSize);
    return GameLevel(
      levelNumber: levelNumber,
      gridSize: gridSize,
      pieces: fallbackPieces,
    );
  }

  static List<BlockPiece>? _tryPartition(int n, Random rng) {
    final grid = List.generate(n, (_) => List<int>.filled(n, -1));
    final pieces = <BlockPiece>[];
    int nextId = 0;

    bool canPlace(List<Coord> shape, int r, int c) {
      for (final cell in shape) {
        final nr = r + cell.r;
        final nc = c + cell.c;
        if (nr < 0 || nr >= n || nc < 0 || nc >= n) return false;
        if (grid[nr][nc] != -1) return false;
      }
      return true;
    }

    void place(List<Coord> shape, int r, int c, int id) {
      for (final cell in shape) {
        grid[r + cell.r][c + cell.c] = id;
      }
    }

    void unplace(List<Coord> shape, int r, int c) {
      for (final cell in shape) {
        grid[r + cell.r][c + cell.c] = -1;
      }
    }

    bool solve() {
      int targetR = -1;
      int targetC = -1;
      for (int r = 0; r < n; r++) {
        for (int c = 0; c < n; c++) {
          if (grid[r][c] == -1) {
            targetR = r;
            targetC = c;
            break;
          }
        }
        if (targetR != -1) break;
      }

      if (targetR == -1) return true;

      final shuffledTemplates = List<List<Coord>>.from(shapeTemplates)..shuffle(rng);
      for (final tmpl in shuffledTemplates) {
        for (final anchor in tmpl) {
          final originR = targetR - anchor.r;
          final originC = targetC - anchor.c;
          if (canPlace(tmpl, originR, originC)) {
            final id = nextId++;
            place(tmpl, originR, originC, id);

            final minR = tmpl.map((c) => c.r).reduce(min);
            final minC = tmpl.map((c) => c.c).reduce(min);
            final normCells = tmpl.map((c) => Coord(c.r - minR, c.c - minC)).toList();
            final w = normCells.map((c) => c.c).reduce(max) + 1;
            final h = normCells.map((c) => c.r).reduce(max) + 1;

            final piece = BlockPiece(
              id: id,
              cells: normCells,
              width: w,
              height: h,
              colorIndex: id,
              targetPos: Coord(originR + minR, originC + minC),
            );
            pieces.add(piece);

            if (solve()) return true;

            pieces.removeLast();
            unplace(tmpl, originR, originC);
            nextId--;
          }
        }
      }
      return false;
    }

    if (solve()) {
      return pieces;
    }
    return null;
  }

  static List<BlockPiece> _generateFallback(int n) {
    final pieces = <BlockPiece>[];
    int id = 0;
    for (int r = 0; r < n; r++) {
      int c = 0;
      while (c < n) {
        final rem = n - c;
        final len = rem >= 4 ? 4 : (rem >= 3 ? 3 : rem);
        final cells = List.generate(len, (i) => Coord(0, i));
        pieces.add(
          BlockPiece(
            id: id,
            cells: cells,
            width: len,
            height: 1,
            colorIndex: id,
            targetPos: Coord(r, c),
          ),
        );
        id++;
        c += len;
      }
    }
    return pieces;
  }
}
