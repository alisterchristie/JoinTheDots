unit formJoinTheDots;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs;

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

  TForm51 = class(TForm)
  private const
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
    FNewGameRect: TRectF;
    FModeRect: TRectF;
    FSmallGridRect: TRectF;
    FMediumGridRect: TRectF;
    FLargeGridRect: TRectF;
    FSquareStyleRect: TRectF;
    FHexStyleRect: TRectF;
    FPlayAgainstAI: Boolean;
    FAITimer: TTimer;
    function AddDot(const APoint: TPointF): Integer;
    function AddEdge(const ADot1, ADot2: Integer): Integer;
    function BoardRect: TRectF;
    function CellSize: Single;
    function CellSidesClaimed(const ACellIndex: Integer; const AMove: TMoveTarget): Integer;
    function CountCompletedCellsForMove(const AMove: TMoveTarget): Integer;
    function DistanceToSegment(const APoint, AStart, AEnd: TPointF): Single;
    function DotPoint(const ADotIndex: Integer): TPointF;
    function FindAIMove(out AMove: TMoveTarget): Boolean;
    function FindMoveAt(const APoint: TPointF; out AMove: TMoveTarget): Boolean;
    function IsAITurn: Boolean;
    function IsGameOver: Boolean;
    function LineAlreadyClaimed(const AMove: TMoveTarget): Boolean;
    function MoveCreatesAlmostCompleteCell(const AMove: TMoveTarget): Boolean;
    function ClaimLine(const AMove: TMoveTarget): Integer;
    function TryCompleteCell(const ACellIndex: Integer): Boolean;
    procedure AITimer(Sender: TObject);
    procedure BuildBoard;
    procedure BuildHexBoard;
    procedure BuildSquareBoard;
    procedure DrawBoard;
    procedure DrawButton(const ARect: TRectF; const AText: string; const ASelected: Boolean);
    procedure DrawCellFill(const ACell: TBoardCell);
    procedure DrawScoreboard;
    procedure FormPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure NewGame;
    procedure QueueAITurn;
    procedure SetBoardStyle(const AStyle: TBoardStyle);
    procedure SetGridSize(const ADotCount: Integer);
    procedure SwitchPlayer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
  end;

var
  Form51: TForm51;

implementation

{$R *.fmx}

const
  PlayerColors: array[1..TForm51.PlayerCount] of TAlphaColor =
    ($FF2563EB, $FFE11D48);
  BoardBackgroundColor = $FFF8FAFC;
  DotColor = $FF111827;
  GridLineColor = $FFCBD5E1;
  TextColor = $FF111827;
  MutedTextColor = $FF475569;
  SelectedButtonColor = $FFE0F2FE;
  ButtonBorderColor = $FF94A3B8;

constructor TForm51.Create(AOwner: TComponent);
begin
  inherited;
  Caption := 'Join the Dots';
  Width := 860;
  Height := 760;
  OnPaint := FormPaint;
  Randomize;

  FDotCount := MediumDotCount;
  FBoxCount := FDotCount - 1;
  FBoardStyle := bsSquares;
  FPlayAgainstAI := True;

  FAITimer := TTimer.Create(Self);
  FAITimer.Enabled := False;
  FAITimer.Interval := 450;
  FAITimer.OnTimer := AITimer;

  NewGame;
end;

destructor TForm51.Destroy;
begin
  FAITimer.Enabled := False;
  inherited;
end;

function TForm51.AddDot(const APoint: TPointF): Integer;
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

function TForm51.AddEdge(const ADot1, ADot2: Integer): Integer;
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

function TForm51.BoardRect: TRectF;
var
  AvailableWidth: Single;
  AvailableHeight: Single;
  Size: Single;
  LeftPos: Single;
  TopPos: Single;
begin
  AvailableWidth := Max(240, ClientWidth - 80);
  AvailableHeight := Max(240, ClientHeight - 280);
  Size := Min(AvailableWidth, AvailableHeight);
  LeftPos := (ClientWidth - Size) / 2;
  TopPos := 225 + (AvailableHeight - Size) / 2;
  Result := RectF(LeftPos, TopPos, LeftPos + Size, TopPos + Size);
end;

function TForm51.CellSize: Single;
begin
  Result := BoardRect.Width / Max(1, FBoxCount);
end;

function TForm51.DotPoint(const ADotIndex: Integer): TPointF;
var
  R: TRectF;
begin
  R := BoardRect;
  Result := PointF(R.Left + FDots[ADotIndex].X * R.Width, R.Top + FDots[ADotIndex].Y * R.Height);
end;

function TForm51.DistanceToSegment(const APoint, AStart, AEnd: TPointF): Single;
var
  DX: Single;
  DY: Single;
  LenSquared: Single;
  T: Single;
  Projection: TPointF;
begin
  DX := AEnd.X - AStart.X;
  DY := AEnd.Y - AStart.Y;
  LenSquared := DX * DX + DY * DY;
  if LenSquared = 0 then
    Exit(Sqrt(Sqr(APoint.X - AStart.X) + Sqr(APoint.Y - AStart.Y)));

  T := ((APoint.X - AStart.X) * DX + (APoint.Y - AStart.Y) * DY) / LenSquared;
  T := EnsureRange(T, 0, 1);
  Projection := PointF(AStart.X + T * DX, AStart.Y + T * DY);
  Result := Sqrt(Sqr(APoint.X - Projection.X) + Sqr(APoint.Y - Projection.Y));
end;

procedure TForm51.BuildBoard;
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

procedure TForm51.BuildSquareBoard;
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

procedure TForm51.BuildHexBoard;
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

procedure TForm51.DrawButton(const ARect: TRectF; const AText: string; const ASelected: Boolean);
begin
  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Color := ButtonBorderColor;
  Canvas.Stroke.Thickness := 1;
  if ASelected then
    Canvas.Fill.Color := SelectedButtonColor
  else
    Canvas.Fill.Color := $FFFFFFFF;
  Canvas.FillRect(ARect, 6, 6, [], 1);
  Canvas.DrawRect(ARect, 6, 6, [], 1);
  Canvas.Font.Size := 13;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.Fill.Color := TextColor;
  Canvas.FillText(ARect, AText, False, 1, [], TTextAlign.Center, TTextAlign.Center);
  Canvas.Font.Style := [];
end;

procedure TForm51.DrawScoreboard;
var
  HeaderRect: TRectF;
  PlayerRect: TRectF;
  PlayerText: string;
  I: Integer;
begin
  HeaderRect := RectF(32, 24, ClientWidth - 32, 205);

  Canvas.Font.Size := 28;
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.Fill.Color := TextColor;
  Canvas.FillText(RectF(HeaderRect.Left, HeaderRect.Top, HeaderRect.Right, HeaderRect.Top + 36),
    'Join the Dots', False, 1, [], TTextAlign.Leading, TTextAlign.Center);

  Canvas.Font.Size := 14;
  Canvas.Font.Style := [];
  Canvas.Fill.Color := MutedTextColor;
  if IsGameOver then
  begin
    if FScores[1] = FScores[2] then
      PlayerText := 'Game over: draw'
    else if FScores[1] > FScores[2] then
      PlayerText := 'Game over: Player 1 wins'
    else if FPlayAgainstAI then
      PlayerText := 'Game over: AI wins'
    else
      PlayerText := 'Game over: Player 2 wins';
  end
  else if IsAITurn then
    PlayerText := 'AI thinking...'
  else
    PlayerText := Format('Player %d to move', [FCurrentPlayer]);

  Canvas.FillText(RectF(HeaderRect.Left, HeaderRect.Top + 39, HeaderRect.Right, HeaderRect.Top + 64),
    PlayerText, False, 1, [], TTextAlign.Leading, TTextAlign.Center);

  for I := 1 to PlayerCount do
  begin
    PlayerRect := RectF(HeaderRect.Left + (I - 1) * 165, HeaderRect.Top + 78,
      HeaderRect.Left + 147 + (I - 1) * 165, HeaderRect.Top + 110);
    Canvas.Fill.Color := PlayerColors[I];
    Canvas.FillRect(RectF(PlayerRect.Left, PlayerRect.Top + 9, PlayerRect.Left + 14, PlayerRect.Top + 23),
      3, 3, [], 1);
    Canvas.Fill.Color := TextColor;
    Canvas.Font.Size := 15;
    if (I = 2) and FPlayAgainstAI then
      Canvas.FillText(RectF(PlayerRect.Left + 22, PlayerRect.Top, PlayerRect.Right, PlayerRect.Bottom),
        Format('AI: %d', [FScores[I]]), False, 1, [], TTextAlign.Leading, TTextAlign.Center)
    else
      Canvas.FillText(RectF(PlayerRect.Left + 22, PlayerRect.Top, PlayerRect.Right, PlayerRect.Bottom),
        Format('P%d: %d', [I, FScores[I]]), False, 1, [], TTextAlign.Leading, TTextAlign.Center);
  end;

  FNewGameRect := RectF(ClientWidth - 150, 30, ClientWidth - 32, 72);
  FModeRect := RectF(ClientWidth - 150, 82, ClientWidth - 32, 124);
  FSmallGridRect := RectF(32, 144, 105, 180);
  FMediumGridRect := RectF(113, 144, 203, 180);
  FLargeGridRect := RectF(211, 144, 284, 180);
  FSquareStyleRect := RectF(315, 144, 403, 180);
  FHexStyleRect := RectF(411, 144, 499, 180);

  DrawButton(FNewGameRect, 'New game', False);
  if FPlayAgainstAI then
    DrawButton(FModeRect, 'Vs AI', True)
  else
    DrawButton(FModeRect, '2 players', True);
  DrawButton(FSmallGridRect, 'Small', FDotCount = MinDotCount);
  DrawButton(FMediumGridRect, 'Medium', FDotCount = MediumDotCount);
  DrawButton(FLargeGridRect, 'Large', FDotCount = MaxDotCount);
  DrawButton(FSquareStyleRect, 'Squares', FBoardStyle = bsSquares);
  DrawButton(FHexStyleRect, 'Hexes', FBoardStyle = bsHexagons);
end;

procedure TForm51.DrawCellFill(const ACell: TBoardCell);
var
  Path: TPathData;
  I: Integer;
  P: TPointF;
begin
  if ACell.Owner = 0 then
    Exit;

  Path := TPathData.Create;
  try
    P := DotPoint(ACell.Dots[0]);
    Path.MoveTo(P);
    for I := 1 to ACell.EdgeCount - 1 do
    begin
      P := DotPoint(ACell.Dots[I]);
      Path.LineTo(P);
    end;
    Path.ClosePath;

    Canvas.Fill.Color := PlayerColors[ACell.Owner] and $2FFFFFFF;
    Canvas.FillPath(Path, 1);
    Canvas.Stroke.Color := PlayerColors[ACell.Owner];
    Canvas.Stroke.Thickness := 1;
    Canvas.DrawPath(Path, 0.35);
  finally
    Path.Free;
  end;

  Canvas.Font.Size := Max(13, CellSize * 0.22);
  Canvas.Font.Style := [TFontStyle.fsBold];
  Canvas.Fill.Color := PlayerColors[ACell.Owner];
  P := PointF(BoardRect.Left + ACell.Center.X * BoardRect.Width, BoardRect.Top + ACell.Center.Y * BoardRect.Height);
  Canvas.FillText(RectF(P.X - 18, P.Y - 14, P.X + 18, P.Y + 14), IntToStr(ACell.Owner), False, 1, [],
    TTextAlign.Center, TTextAlign.Center);
end;

procedure TForm51.DrawBoard;
var
  R: TRectF;
  I: Integer;
  Center: TPointF;
  DotRadius: Single;
  P1: TPointF;
  P2: TPointF;
begin
  R := BoardRect;
  Canvas.Fill.Color := BoardBackgroundColor;
  Canvas.FillRect(RectF(0, 0, ClientWidth, ClientHeight), 0, 0, [], 1);

  DrawScoreboard;

  Canvas.Fill.Color := $FFFFFFFF;
  Canvas.FillRect(RectF(R.Left - 18, R.Top - 18, R.Right + 18, R.Bottom + 18), 8, 8, [], 1);

  for I := 0 to High(FCells) do
    DrawCellFill(FCells[I]);

  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Color := GridLineColor;
  Canvas.Stroke.Thickness := 2;
  for I := 0 to High(FEdges) do
  begin
    P1 := DotPoint(FEdges[I].Dot1);
    P2 := DotPoint(FEdges[I].Dot2);
    Canvas.DrawLine(P1, P2, 1);
  end;

  Canvas.Stroke.Thickness := Max(5, CellSize * 0.07);
  for I := 0 to High(FEdges) do
    if FEdges[I].Owner > 0 then
    begin
      Canvas.Stroke.Color := PlayerColors[FEdges[I].Owner];
      P1 := DotPoint(FEdges[I].Dot1);
      P2 := DotPoint(FEdges[I].Dot2);
      Canvas.DrawLine(P1, P2, 1);
    end;

  DotRadius := Max(4, CellSize * 0.055);
  Canvas.Fill.Color := DotColor;
  for I := 0 to High(FDots) do
  begin
    Center := DotPoint(I);
    Canvas.FillEllipse(RectF(Center.X - DotRadius, Center.Y - DotRadius,
      Center.X + DotRadius, Center.Y + DotRadius), 1);
  end;
end;

function TForm51.IsAITurn: Boolean;
begin
  Result := FPlayAgainstAI and (FCurrentPlayer = 2) and (not IsGameOver);
end;

function TForm51.IsGameOver: Boolean;
begin
  Result := FScores[1] + FScores[2] = Length(FCells);
end;

function TForm51.LineAlreadyClaimed(const AMove: TMoveTarget): Boolean;
begin
  Result := (AMove.EdgeIndex < 0) or (AMove.EdgeIndex > High(FEdges)) or (FEdges[AMove.EdgeIndex].Owner > 0);
end;

function TForm51.FindMoveAt(const APoint: TPointF; out AMove: TMoveTarget): Boolean;
var
  I: Integer;
  Distance: Single;
  Tolerance: Single;
begin
  Result := False;
  AMove.EdgeIndex := -1;
  AMove.Distance := MaxSingle;
  Tolerance := Max(14, CellSize * 0.18);

  for I := 0 to High(FEdges) do
    if FEdges[I].Owner = 0 then
    begin
      Distance := DistanceToSegment(APoint, DotPoint(FEdges[I].Dot1), DotPoint(FEdges[I].Dot2));
      if (Distance <= Tolerance) and (Distance < AMove.Distance) then
      begin
        AMove.EdgeIndex := I;
        AMove.Distance := Distance;
        Result := True;
      end;
    end;
end;

function TForm51.CellSidesClaimed(const ACellIndex: Integer; const AMove: TMoveTarget): Integer;
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

function TForm51.CountCompletedCellsForMove(const AMove: TMoveTarget): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FCells) do
    if (FCells[I].Owner = 0) and (CellSidesClaimed(I, AMove) = FCells[I].EdgeCount) then
      Inc(Result);
end;

function TForm51.MoveCreatesAlmostCompleteCell(const AMove: TMoveTarget): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FCells) do
    if (FCells[I].Owner = 0) and (CellSidesClaimed(I, AMove) = FCells[I].EdgeCount - 1) then
      Exit(True);
end;

function TForm51.FindAIMove(out AMove: TMoveTarget): Boolean;
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

function TForm51.TryCompleteCell(const ACellIndex: Integer): Boolean;
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

function TForm51.ClaimLine(const AMove: TMoveTarget): Integer;
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

procedure TForm51.SwitchPlayer;
begin
  if FCurrentPlayer = 1 then
    FCurrentPlayer := 2
  else
    FCurrentPlayer := 1;
end;

procedure TForm51.SetGridSize(const ADotCount: Integer);
begin
  FDotCount := EnsureRange(ADotCount, MinDotCount, MaxDotCount);
  FBoxCount := FDotCount - 1;
  NewGame;
end;

procedure TForm51.SetBoardStyle(const AStyle: TBoardStyle);
begin
  if FBoardStyle <> AStyle then
  begin
    FBoardStyle := AStyle;
    NewGame;
  end;
end;

procedure TForm51.NewGame;
begin
  if FAITimer <> nil then
    FAITimer.Enabled := False;
  BuildBoard;
  FScores[1] := 0;
  FScores[2] := 0;
  FCurrentPlayer := 1;
  Invalidate;
end;

procedure TForm51.QueueAITurn;
begin
  if IsAITurn and (FAITimer <> nil) then
    FAITimer.Enabled := True;
end;

procedure TForm51.AITimer(Sender: TObject);
var
  Move: TMoveTarget;
  CompletedCells: Integer;
begin
  FAITimer.Enabled := False;
  if not IsAITurn then
    Exit;

  if FindAIMove(Move) then
  begin
    CompletedCells := ClaimLine(Move);
    if CompletedCells = 0 then
      SwitchPlayer;
    Invalidate;
    QueueAITurn;
  end;
end;

procedure TForm51.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Move: TMoveTarget;
  CompletedCells: Integer;
  ClickPoint: TPointF;
begin
  inherited;

  if Button <> TMouseButton.mbLeft then
    Exit;

  ClickPoint := PointF(X, Y);

  if FNewGameRect.Contains(ClickPoint) then
  begin
    NewGame;
    Exit;
  end;

  if FModeRect.Contains(ClickPoint) then
  begin
    FPlayAgainstAI := not FPlayAgainstAI;
    NewGame;
    Exit;
  end;

  if FSmallGridRect.Contains(ClickPoint) then
  begin
    SetGridSize(MinDotCount);
    Exit;
  end;

  if FMediumGridRect.Contains(ClickPoint) then
  begin
    SetGridSize(MediumDotCount);
    Exit;
  end;

  if FLargeGridRect.Contains(ClickPoint) then
  begin
    SetGridSize(MaxDotCount);
    Exit;
  end;

  if FSquareStyleRect.Contains(ClickPoint) then
  begin
    SetBoardStyle(bsSquares);
    Exit;
  end;

  if FHexStyleRect.Contains(ClickPoint) then
  begin
    SetBoardStyle(bsHexagons);
    Exit;
  end;

  if IsGameOver or IsAITurn then
    Exit;

  if FindMoveAt(ClickPoint, Move) then
  begin
    CompletedCells := ClaimLine(Move);
    if CompletedCells = 0 then
      SwitchPlayer;
    Invalidate;
    QueueAITurn;
  end;
end;

procedure TForm51.FormPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
begin
  DrawBoard;
end;

end.