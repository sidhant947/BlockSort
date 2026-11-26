import 'package:material_ui/material_ui.dart';

@immutable
class Coord {
  const Coord(this.r, this.c);

  final int r;
  final int c;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coord &&
          runtimeType == other.runtimeType &&
          r == other.r &&
          c == other.c;

  @override
  int get hashCode => Object.hash(r, c);
}

@immutable
class BlockPiece {
  const BlockPiece({
    required this.id,
    required this.cells,
    required this.width,
    required this.height,
    required this.colorIndex,
    required this.targetPos,
    List<Coord>? originalCells,
    int? originalWidth,
    int? originalHeight,
  })  : originalCells = originalCells ?? cells,
        originalWidth = originalWidth ?? width,
        originalHeight = originalHeight ?? height;

  final int id;
  final List<Coord> cells;
  final int width;
  final int height;
  final int colorIndex;
  final Coord targetPos;
  final List<Coord> originalCells;
  final int originalWidth;
  final int originalHeight;

  int get area => cells.length;

  List<Coord> placedCoords(int r, int c) {
    return cells.map((cell) => Coord(r + cell.r, c + cell.c)).toList();
  }

  BlockPiece rotate90() {
    final rotatedCells =
        cells.map((cell) => Coord(cell.c, height - 1 - cell.r)).toList();
    return BlockPiece(
      id: id,
      cells: rotatedCells,
      width: height,
      height: width,
      colorIndex: colorIndex,
      targetPos: targetPos,
      originalCells: originalCells,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
    );
  }

  BlockPiece resetRotation() {
    return BlockPiece(
      id: id,
      cells: originalCells,
      width: originalWidth,
      height: originalHeight,
      colorIndex: colorIndex,
      targetPos: targetPos,
      originalCells: originalCells,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
    );
  }
}

@immutable
class PlacedPiece {
  const PlacedPiece({
    required this.pieceId,
    required this.r,
    required this.c,
  });

  final int pieceId;
  final int r;
  final int c;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacedPiece &&
          runtimeType == other.runtimeType &&
          pieceId == other.pieceId &&
          r == other.r &&
          c == other.c;

  @override
  int get hashCode => Object.hash(pieceId, r, c);
}

@immutable
class GameLevel {
  const GameLevel({
    required this.levelNumber,
    required this.gridSize,
    required this.pieces,
  });

  final int levelNumber;
  final int gridSize;
  final List<BlockPiece> pieces;

  BlockPiece? getPieceById(int id) {
    for (final p in pieces) {
      if (p.id == id) return p;
    }
    return null;
  }
}
