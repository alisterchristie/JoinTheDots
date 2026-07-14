unit uJoinTheDotsGame;

interface

uses
  System.Math, System.Types;

type
  TBoardStyle = (bsSquares, bsHexagons);

  TMoveTarget = record
    EdgeIndex: Integer;
    Distance: Single;
  end;

  TBoardEdge = record
    Dot1: Integer;
    Dot2: Integer;
    Owner: Integer;
  end;

  TBoardCell = record
    EdgeCount: Integer;
    Edges: array[0..5] of Integer;
    Dots: array[0..5] of Integer;
    Owner: Integer;
    Center: TPointF;
  end;

  TJoinTheDotsGame = class
  public const
    MinDotCount = 4;
    MediumDotCount = 6;
    MaxDotCount = 8;
    PlayerCount = 2;
  private
    FDots: array of TPointF;
    FEdges: array of TBoardEdge;
    FCells: array of TBoardCell;
    FCurrentPlayer: Integer;
    FDotCount: Integer;
    FBoxCount: Integer;
    FBoardStyle: TBoardStyle;
    FScores: array[1..PlayerCount] of Integer;
    function AddDot(const APoint: TPointF): Integer;
    function AddEdge(const ADot1, ADot2: Integer): Integer;
    function CellSidesClaimed(const ACellIndex: Integer; const AMove: TMoveTarget): Integer;
    function CountCompletedCellsForMove(const AMove: TMoveTarget): Integer;
    function MoveCreatesAlmostCompleteCell(const AMove: TMoveTarget): Boolean;
    function TryCompleteCell(const ACellIndex: Integer): Boolean;
    procedure BuildBoard;
    procedure BuildHexBoard;
    procedure BuildSquareBoard;
  public
    constructor Create;
    function Cell(const AIndex: Integer): TBoardCell;
    function CellCount: Integer;
    function ClaimLine(const AMove: TMoveTarget): Integer;
    function Dot(const AIndex: Integer): TPointF;
    function DotCountTotal: Integer;
    function Edge(const AIndex: Integer): TBoardEdge;
    function EdgeCount: Integer;
    function FindAIMove(out AMove: TMoveTarget): Boolean;
    function IsGameOver: Boolean;
    function LineAlreadyClaimed(const AMove: TMoveTarget): Boolean;
    function Score(const APlayer: Integer): Integer;
    procedure NewGame;
    procedure SetBoardStyle(const AStyle: TBoardStyle);
    procedure SetGridSize(const ADotCount: Integer);
    procedure SwitchPlayer;
    property BoardStyle: TBoardStyle read FBoardStyle;
    property BoxCount: Integer read FBoxCount;
    property CurrentPlayer: Integer read FCurrentPlayer;
    property DotCount: Integer read FDotCount;
  end;

implementation

constructor TJoinTheDotsGame.Create;
begin
  inherited Create;
  FDotCount := MediumDotCount;
  FBoxCount := FDotCount - 1;
  FBoardStyle := bsSquares;
  NewGame;
end;

function TJoinTheDotsGame.AddDot(const APoint: TPointF): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FDots) do
    if (Abs(FDots[I].X - APoint.X) < 0.0001) and (Abs(FDots[I].Y - APoint.Y) < 0.0001) then
      Exit(I);

  Result := Length(FDots);
  SetLength(FDots, Result + 1);
  FDots[Result] := APoint;
end;

function TJoinTheDotsGame.AddEdge(const ADot1, ADot2: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FEdges) do
    if ((FEdges[I].Dot1 = ADot1) and (FEdges[I].Dot2 = ADot2))
      or ((FEdges[I].Dot1 = ADot2) and (FEdges[I].Dot2 = ADot1)) then
      Exit(I);

  Result := Length(FEdges);
  SetLength(FEdges, Result + 1);
  FEdges[Result].Dot1 := ADot1;
  FEdges[Result].Dot2 := ADot2;
  FEdges[Result].Owner := 0;
end;

procedure TJoinTheDotsGame.BuildBoard;
begin
  SetLength(FDots, 0);
  SetLength(FEdges, 0);
  SetLength(FCells, 0);

  case FBoardStyle of
    bsSquares:
      BuildSquareBoard;
    bsHexagons:
      BuildHexBoard;
  end;
end;

procedure TJoinTheDotsGame.BuildSquareBoard;
var
  Row: Integer;
  Col: Integer;
  DotIndex: Integer;
  CellIndex: Integer;
begin
  SetLength(FDots, FDotCount * FDotCount);
  for Row := 0 to FDotCount - 1 do
    for Col := 0 to FDotCount - 1 do
    begin
      DotIndex := Row * FDotCount + Col;
      FDots[DotIndex] := PointF(Col / FBoxCount, Row / FBoxCount);
    end;

  SetLength(FCells, FBoxCount * FBoxCount);
  for Row := 0 to FBoxCount - 1 do
    for Col := 0 to FBoxCount - 1 do
    begin
      CellIndex := Row * FBoxCount + Col;
      FCells[CellIndex].EdgeCount := 4;
      FCells[CellIndex].Dots[0] := Row * FDotCount + Col;
      FCells[CellIndex].Dots[1] := Row * FDotCount + Col + 1;
      FCells[CellIndex].Dots[2] := (Row + 1) * FDotCount + Col + 1;
      FCells[CellIndex].Dots[3] := (Row + 1) * FDotCount + Col;
      FCells[CellIndex].Edges[0] := AddEdge(FCells[CellIndex].Dots[0], FCells[CellIndex].Dots[1]);
      FCells[CellIndex].Edges[1] := AddEdge(FCells[CellIndex].Dots[1], FCells[CellIndex].Dots[2]);
      FCells[CellIndex].Edges[2] := AddEdge(FCells[CellIndex].Dots[2], FCells[CellIndex].Dots[3]);
      FCells[CellIndex].Edges[3] := AddEdge(FCells[CellIndex].Dots[3], FCells[CellIndex].Dots[0]);
      FCells[CellIndex].Owner := 0;
      FCells[CellIndex].Center := PointF((Col + 0.5) / FBoxCount, (Row + 0.5) / FBoxCount);
    end;
end;

procedure TJoinTheDotsGame.BuildHexBoard;
type
  THexCellPoints = record
    Vertices: array[0..5] of TPointF;
    Center: TPointF;
  end;
var
  RawCells: array of THexCellPoints;
  Row: Integer;
  Col: Integer;
  I: Integer;
  CellIndex: Integer;
  DotIndex1: Integer;
  DotIndex2: Integer;
  MinX: Single;
  MaxX: Single;
  MinY: Single;
  MaxY: Single;
  Center: TPointF;
  Angle: Single;
  NormalizedPoint: TPointF;
begin
  SetLength(RawCells, FBoxCount * FBoxCount);
  MinX := MaxSingle;
  MinY := MaxSingle;
  MaxX := -MaxSingle;
  MaxY := -MaxSingle;

  for Row := 0 to FBoxCount - 1 do
    for Col := 0 to FBoxCount - 1 do
    begin
      CellIndex := Row * FBoxCount + Col;
      Center := PointF(1 + Col * 1.5, Sqrt(3) / 2 + Row * Sqrt(3));
      if Odd(Col) then
        Center.Y := Center.Y + Sqrt(3) / 2;
      RawCells[CellIndex].Center := Center;

      MinX := Min(MinX, Center.X);
      MaxX := Max(MaxX, Center.X);
      MinY := Min(MinY, Center.Y);
      MaxY := Max(MaxY, Center.Y);

      for I := 0 to 5 do
      begin
        Angle := DegToRad(I * 60);
        RawCells[CellIndex].Vertices[I] := PointF(Center.X + Cos(Angle), Center.Y + Sin(Angle));
        MinX := Min(MinX, RawCells[CellIndex].Vertices[I].X);
        MaxX := Max(MaxX, RawCells[CellIndex].Vertices[I].X);
        MinY := Min(MinY, RawCells[CellIndex].Vertices[I].Y);
        MaxY := Max(MaxY, RawCells[CellIndex].Vertices[I].Y);
      end;
    end;

  SetLength(FCells, Length(RawCells));
  for CellIndex := 0 to High(RawCells) do
  begin
    FCells[CellIndex].EdgeCount := 6;
    FCells[CellIndex].Owner := 0;
    FCells[CellIndex].Center := PointF((RawCells[CellIndex].Center.X - MinX) / (MaxX - MinX),
      (RawCells[CellIndex].Center.Y - MinY) / (MaxY - MinY));

    for I := 0 to 5 do
    begin
      NormalizedPoint := PointF((RawCells[CellIndex].Vertices[I].X - MinX) / (MaxX - MinX),
        (RawCells[CellIndex].Vertices[I].Y - MinY) / (MaxY - MinY));
      FCells[CellIndex].Dots[I] := AddDot(NormalizedPoint);
    end;

    for I := 0 to 5 do
    begin
      DotIndex1 := FCells[CellIndex].Dots[I];
      DotIndex2 := FCells[CellIndex].Dots[(I + 1) mod 6];
      FCells[CellIndex].Edges[I] := AddEdge(DotIndex1, DotIndex2);
    end;
  end;
end;

function TJoinTheDotsGame.Cell(const AIndex: Integer): TBoardCell;
begin
  Result := FCells[AIndex];
end;

function TJoinTheDotsGame.CellCount: Integer;
begin
  Result := Length(FCells);
end;

function TJoinTheDotsGame.CellSidesClaimed(const ACellIndex: Integer; const AMove: TMoveTarget): Integer;
var
  I: Integer;
  EdgeIndex: Integer;
begin
  Result := 0;
  for I := 0 to FCells[ACellIndex].EdgeCount - 1 do
  begin
    EdgeIndex := FCells[ACellIndex].Edges[I];
    if (FEdges[EdgeIndex].Owner > 0) or (EdgeIndex = AMove.EdgeIndex) then
      Inc(Result);
  end;
end;

function TJoinTheDotsGame.ClaimLine(const AMove: TMoveTarget): Integer;
var
  I: Integer;
begin
  Result := 0;
  if LineAlreadyClaimed(AMove) then
    Exit;

  FEdges[AMove.EdgeIndex].Owner := FCurrentPlayer;
  for I := 0 to High(FCells) do
    if TryCompleteCell(I) then
      Inc(Result);
end;

function TJoinTheDotsGame.CountCompletedCellsForMove(const AMove: TMoveTarget): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FCells) do
    if (FCells[I].Owner = 0) and (CellSidesClaimed(I, AMove) = FCells[I].EdgeCount) then
      Inc(Result);
end;

function TJoinTheDotsGame.Dot(const AIndex: Integer): TPointF;
begin
  Result := FDots[AIndex];
end;

function TJoinTheDotsGame.DotCountTotal: Integer;
begin
  Result := Length(FDots);
end;

function TJoinTheDotsGame.Edge(const AIndex: Integer): TBoardEdge;
begin
  Result := FEdges[AIndex];
end;

function TJoinTheDotsGame.EdgeCount: Integer;
begin
  Result := Length(FEdges);
end;

function TJoinTheDotsGame.FindAIMove(out AMove: TMoveTarget): Boolean;
var
  Candidate: TMoveTarget;
  I: Integer;
  CandidateScore: Integer;
  BestScore: Integer;
  PickCount: Integer;

  procedure ConsiderMove(const AMoveToConsider: TMoveTarget; const ARequireSafe: Boolean);
  var
    SafeMove: Boolean;
  begin
    if LineAlreadyClaimed(AMoveToConsider) then
      Exit;

    CandidateScore := CountCompletedCellsForMove(AMoveToConsider);
    if CandidateScore > 0 then
    begin
      if CandidateScore > BestScore then
      begin
        BestScore := CandidateScore;
        PickCount := 1;
        AMove := AMoveToConsider;
      end
      else if CandidateScore = BestScore then
      begin
        Inc(PickCount);
        if Random(PickCount) = 0 then
          AMove := AMoveToConsider;
      end;
      Exit;
    end;

    if BestScore > 0 then
      Exit;

    SafeMove := not MoveCreatesAlmostCompleteCell(AMoveToConsider);
    if ARequireSafe and (not SafeMove) then
      Exit;

    Inc(PickCount);
    if Random(PickCount) = 0 then
      AMove := AMoveToConsider;
  end;

begin
  AMove.EdgeIndex := -1;
  AMove.Distance := 0;
  BestScore := 0;
  PickCount := 0;

  for I := 0 to High(FEdges) do
  begin
    Candidate.EdgeIndex := I;
    Candidate.Distance := 0;
    ConsiderMove(Candidate, True);
  end;

  if PickCount = 0 then
    for I := 0 to High(FEdges) do
    begin
      Candidate.EdgeIndex := I;
      Candidate.Distance := 0;
      ConsiderMove(Candidate, False);
    end;

  Result := AMove.EdgeIndex >= 0;
end;

function TJoinTheDotsGame.IsGameOver: Boolean;
begin
  Result := FScores[1] + FScores[2] = Length(FCells);
end;

function TJoinTheDotsGame.LineAlreadyClaimed(const AMove: TMoveTarget): Boolean;
begin
  Result := (AMove.EdgeIndex < 0) or (AMove.EdgeIndex > High(FEdges)) or (FEdges[AMove.EdgeIndex].Owner > 0);
end;

function TJoinTheDotsGame.MoveCreatesAlmostCompleteCell(const AMove: TMoveTarget): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FCells) do
    if (FCells[I].Owner = 0) and (CellSidesClaimed(I, AMove) = FCells[I].EdgeCount - 1) then
      Exit(True);
end;

procedure TJoinTheDotsGame.NewGame;
begin
  BuildBoard;
  FScores[1] := 0;
  FScores[2] := 0;
  FCurrentPlayer := 1;
end;

function TJoinTheDotsGame.Score(const APlayer: Integer): Integer;
begin
  if (APlayer >= Low(FScores)) and (APlayer <= High(FScores)) then
    Result := FScores[APlayer]
  else
    Result := 0;
end;

procedure TJoinTheDotsGame.SetBoardStyle(const AStyle: TBoardStyle);
begin
  if FBoardStyle <> AStyle then
  begin
    FBoardStyle := AStyle;
    NewGame;
  end;
end;

procedure TJoinTheDotsGame.SetGridSize(const ADotCount: Integer);
begin
  FDotCount := EnsureRange(ADotCount, MinDotCount, MaxDotCount);
  FBoxCount := FDotCount - 1;
  NewGame;
end;

procedure TJoinTheDotsGame.SwitchPlayer;
begin
  if FCurrentPlayer = 1 then
    FCurrentPlayer := 2
  else
    FCurrentPlayer := 1;
end;

function TJoinTheDotsGame.TryCompleteCell(const ACellIndex: Integer): Boolean;
var
  EmptyMove: TMoveTarget;
begin
  Result := False;
  if (ACellIndex < 0) or (ACellIndex > High(FCells)) or (FCells[ACellIndex].Owner <> 0) then
    Exit;

  EmptyMove.EdgeIndex := -1;
  EmptyMove.Distance := 0;
  if CellSidesClaimed(ACellIndex, EmptyMove) = FCells[ACellIndex].EdgeCount then
  begin
    FCells[ACellIndex].Owner := FCurrentPlayer;
    Inc(FScores[FCurrentPlayer]);
    Result := True;
  end;
end;

end.
