unit TestuJoinTheDotsGame;

interface

uses
  DUnitX.TestFramework,
  uJoinTheDotsGame;

type
  [TestFixture]
  TJoinTheDotsGameTests = class
  private
    function MoveForEdge(const AEdgeIndex: Integer): TMoveTarget;
  public
    [Test]
    procedure NewGameCreatesDefaultMediumSquareBoard;
    [Test]
    procedure SetGridSizeRebuildsSquareBoard;
    [Test]
    procedure SetBoardStyleCreatesHexagonCells;
    [Test]
    procedure CompletingCellScoresPointAndMarksOwner;
    [Test]
    procedure ClaimingSameLineTwiceIsIgnored;
    [Test]
    procedure SwitchPlayerAlternatesCurrentPlayer;
    [Test]
    procedure AIChoosesMoveThatCompletesCell;
  end;

implementation

function TJoinTheDotsGameTests.MoveForEdge(const AEdgeIndex: Integer): TMoveTarget;
begin
  Result.EdgeIndex := AEdgeIndex;
  Result.Distance := 0;
end;

procedure TJoinTheDotsGameTests.NewGameCreatesDefaultMediumSquareBoard;
var
  Game: TJoinTheDotsGame;
begin
  Game := TJoinTheDotsGame.Create;
  try
    Assert.AreEqual(TJoinTheDotsGame.MediumDotCount, Game.DotCount);
    Assert.AreEqual(5, Game.BoxCount);
    Assert.AreEqual(25, Game.CellCount);
    Assert.AreEqual(60, Game.EdgeCount);
    Assert.AreEqual(36, Game.DotCountTotal);
    Assert.AreEqual(1, Game.CurrentPlayer);
    Assert.AreEqual(0, Game.Score(1));
    Assert.AreEqual(0, Game.Score(2));
    Assert.IsFalse(Game.IsGameOver);
  finally
    Game.Free;
  end;
end;

procedure TJoinTheDotsGameTests.SetGridSizeRebuildsSquareBoard;
var
  Game: TJoinTheDotsGame;
begin
  Game := TJoinTheDotsGame.Create;
  try
    Game.SetGridSize(TJoinTheDotsGame.MinDotCount);

    Assert.AreEqual(TJoinTheDotsGame.MinDotCount, Game.DotCount);
    Assert.AreEqual(3, Game.BoxCount);
    Assert.AreEqual(9, Game.CellCount);
    Assert.AreEqual(24, Game.EdgeCount);
    Assert.AreEqual(16, Game.DotCountTotal);
  finally
    Game.Free;
  end;
end;

procedure TJoinTheDotsGameTests.SetBoardStyleCreatesHexagonCells;
var
  Game: TJoinTheDotsGame;
  I: Integer;
begin
  Game := TJoinTheDotsGame.Create;
  try
    Game.SetGridSize(TJoinTheDotsGame.MinDotCount);
    Game.SetBoardStyle(bsHexagons);

    Assert.AreEqual(bsHexagons, Game.BoardStyle);
    Assert.AreEqual(9, Game.CellCount);
    Assert.IsTrue(Game.EdgeCount > Game.CellCount);
    Assert.IsTrue(Game.DotCountTotal > 0);

    for I := 0 to Game.CellCount - 1 do
      Assert.AreEqual(6, Game.Cell(I).EdgeCount);
  finally
    Game.Free;
  end;
end;

procedure TJoinTheDotsGameTests.CompletingCellScoresPointAndMarksOwner;
var
  Game: TJoinTheDotsGame;
  Cell: TBoardCell;
  I: Integer;
  Completed: Integer;
begin
  Game := TJoinTheDotsGame.Create;
  try
    Game.SetGridSize(TJoinTheDotsGame.MinDotCount);
    Cell := Game.Cell(0);

    for I := 0 to Cell.EdgeCount - 2 do
      Assert.AreEqual(0, Game.ClaimLine(MoveForEdge(Cell.Edges[I])));

    Completed := Game.ClaimLine(MoveForEdge(Cell.Edges[Cell.EdgeCount - 1]));

    Assert.AreEqual(1, Completed);
    Assert.AreEqual(1, Game.Score(1));
    Assert.AreEqual(1, Game.Cell(0).Owner);
  finally
    Game.Free;
  end;
end;

procedure TJoinTheDotsGameTests.ClaimingSameLineTwiceIsIgnored;
var
  Game: TJoinTheDotsGame;
  Move: TMoveTarget;
begin
  Game := TJoinTheDotsGame.Create;
  try
    Move := MoveForEdge(0);

    Assert.AreEqual(0, Game.ClaimLine(Move));
    Assert.IsTrue(Game.LineAlreadyClaimed(Move));
    Assert.AreEqual(0, Game.ClaimLine(Move));
    Assert.AreEqual(0, Game.Score(1));
  finally
    Game.Free;
  end;
end;

procedure TJoinTheDotsGameTests.SwitchPlayerAlternatesCurrentPlayer;
var
  Game: TJoinTheDotsGame;
begin
  Game := TJoinTheDotsGame.Create;
  try
    Assert.AreEqual(1, Game.CurrentPlayer);
    Game.SwitchPlayer;
    Assert.AreEqual(2, Game.CurrentPlayer);
    Game.SwitchPlayer;
    Assert.AreEqual(1, Game.CurrentPlayer);
  finally
    Game.Free;
  end;
end;

procedure TJoinTheDotsGameTests.AIChoosesMoveThatCompletesCell;
var
  Game: TJoinTheDotsGame;
  Cell: TBoardCell;
  Move: TMoveTarget;
  I: Integer;
begin
  Game := TJoinTheDotsGame.Create;
  try
    Game.SetGridSize(TJoinTheDotsGame.MinDotCount);
    Cell := Game.Cell(0);

    for I := 0 to Cell.EdgeCount - 2 do
      Game.ClaimLine(MoveForEdge(Cell.Edges[I]));

    Assert.IsTrue(Game.FindAIMove(Move));
    Assert.AreEqual(Cell.Edges[Cell.EdgeCount - 1], Move.EdgeIndex);
  finally
    Game.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TJoinTheDotsGameTests);

end.
