import 'package:blocksort/domain/models/game_level.dart';

class CellRules {
  const CellRules._();

  static bool canPlacePiece(
    BlockPiece piece,
    int r,
    int c,
    int gridSize,
    Set<Coord> occupiedCells,
  ) {
    for (final cell in piece.cells) {
      final targetR = r + cell.r;
      final targetC = c + cell.c;
      if (targetR < 0 || targetR >= gridSize || targetC < 0 || targetC >= gridSize) {
        return false;
      }
      if (occupiedCells.contains(Coord(targetR, targetC))) {
        return false;
      }
    }
    return true;
  }

  static Map<Coord, int> buildOccupiedMap(
    List<PlacedPiece> placedPieces,
    GameLevel level,
  ) {
    final map = <Coord, int>{};
    for (final placed in placedPieces) {
      final piece = level.getPieceById(placed.pieceId);
      if (piece == null) continue;
      for (final cell in piece.cells) {
        map[Coord(placed.r + cell.r, placed.c + cell.c)] = placed.pieceId;
      }
    }
    return map;
  }

  static bool isComplete(List<PlacedPiece> placedPieces, GameLevel level) {
    if (placedPieces.length != level.pieces.length) return false;
    final totalCells = level.gridSize * level.gridSize;
    final occupied = <Coord>{};

    for (final placed in placedPieces) {
      final piece = level.getPieceById(placed.pieceId);
      if (piece == null) return false;
      for (final cell in piece.cells) {
        final target = Coord(placed.r + cell.r, placed.c + cell.c);
        if (target.r < 0 ||
            target.r >= level.gridSize ||
            target.c < 0 ||
            target.c >= level.gridSize) {
          return false;
        }
        if (!occupied.add(target)) {
          return false;
        }
      }
    }

    return occupied.length == totalCells;
  }

  static PlacedPiece? suggestHint(
    List<PlacedPiece> placedPieces,
    GameLevel level,
  ) {
    for (final piece in level.pieces) {
      final placedIndex =
          placedPieces.indexWhere((p) => p.pieceId == piece.id);
      if (placedIndex == -1) {
        return PlacedPiece(
          pieceId: piece.id,
          r: piece.targetPos.r,
          c: piece.targetPos.c,
        );
      }
      final currentPlaced = placedPieces[placedIndex];
      if (currentPlaced.r != piece.targetPos.r ||
          currentPlaced.c != piece.targetPos.c) {
        return PlacedPiece(
          pieceId: piece.id,
          r: piece.targetPos.r,
          c: piece.targetPos.c,
        );
      }
    }
    return null;
  }
}
