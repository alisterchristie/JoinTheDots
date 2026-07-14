unit formJoinTheDots;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  uJoinTheDotsGame;

type
  TForm51 = class(TForm)
  private
    FGame: TJoinTheDotsGame;
    FNewGameRect: TRectF;
    FModeRect: TRectF;
    FSmallGridRect: TRectF;
    FMediumGridRect: TRectF;
    FLargeGridRect: TRectF;
    FSquareStyleRect: TRectF;
    FHexStyleRect: TRectF;
    FPlayAgainstAI: Boolean;
    FAITimer: TTimer;
    function BoardRect: TRectF;
    function CellSize: Single;
    function DistanceToSegment(const APoint, AStart, AEnd: TPointF): Single;
    function DotPoint(const ADotIndex: Integer): TPointF;
    function FindMoveAt(const APoint: TPointF; out AMove: TMoveTarget): Boolean;
    function IsAITurn: Boolean;
    procedure AITimer(Sender: TObject);
    procedure DrawBoard;
    procedure DrawButton(const ARect: TRectF; const AText: string; const ASelected: Boolean);
    procedure DrawCellFill(const ACell: TBoardCell);
    procedure DrawScoreboard;
    procedure FormPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure NewGame;
    procedure QueueAITurn;
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
  PlayerColors: array[1..TJoinTheDotsGame.PlayerCount] of TAlphaColor =
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

  FGame := TJoinTheDotsGame.Create;
  FPlayAgainstAI := True;

  FAITimer := TTimer.Create(Self);
  FAITimer.Enabled := False;
  FAITimer.Interval := 450;
  FAITimer.OnTimer := AITimer;

  Invalidate;
end;

destructor TForm51.Destroy;
begin
  FAITimer.Enabled := False;
  FGame.Free;
  inherited;
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
  Result := BoardRect.Width / Max(1, FGame.BoxCount);
end;

function TForm51.DotPoint(const ADotIndex: Integer): TPointF;
var
  R: TRectF;
  Dot: TPointF;
begin
  R := BoardRect;
  Dot := FGame.Dot(ADotIndex);
  Result := PointF(R.Left + Dot.X * R.Width, R.Top + Dot.Y * R.Height);
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

function TForm51.FindMoveAt(const APoint: TPointF; out AMove: TMoveTarget): Boolean;
var
  I: Integer;
  Distance: Single;
  Tolerance: Single;
  Edge: TBoardEdge;
begin
  Result := False;
  AMove.EdgeIndex := -1;
  AMove.Distance := MaxSingle;
  Tolerance := Max(14, CellSize * 0.18);

  for I := 0 to FGame.EdgeCount - 1 do
  begin
    Edge := FGame.Edge(I);
    if Edge.Owner = 0 then
    begin
      Distance := DistanceToSegment(APoint, DotPoint(Edge.Dot1), DotPoint(Edge.Dot2));
      if (Distance <= Tolerance) and (Distance < AMove.Distance) then
      begin
        AMove.EdgeIndex := I;
        AMove.Distance := Distance;
        Result := True;
      end;
    end;
  end;
end;

function TForm51.IsAITurn: Boolean;
begin
  Result := FPlayAgainstAI and (FGame.CurrentPlayer = 2) and (not FGame.IsGameOver);
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
  if FGame.IsGameOver then
  begin
    if FGame.Score(1) = FGame.Score(2) then
      PlayerText := 'Game over: draw'
    else if FGame.Score(1) > FGame.Score(2) then
      PlayerText := 'Game over: Player 1 wins'
    else if FPlayAgainstAI then
      PlayerText := 'Game over: AI wins'
    else
      PlayerText := 'Game over: Player 2 wins';
  end
  else if IsAITurn then
    PlayerText := 'AI thinking...'
  else
    PlayerText := Format('Player %d to move', [FGame.CurrentPlayer]);

  Canvas.FillText(RectF(HeaderRect.Left, HeaderRect.Top + 39, HeaderRect.Right, HeaderRect.Top + 64),
    PlayerText, False, 1, [], TTextAlign.Leading, TTextAlign.Center);

  for I := 1 to TJoinTheDotsGame.PlayerCount do
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
        Format('AI: %d', [FGame.Score(I)]), False, 1, [], TTextAlign.Leading, TTextAlign.Center)
    else
      Canvas.FillText(RectF(PlayerRect.Left + 22, PlayerRect.Top, PlayerRect.Right, PlayerRect.Bottom),
        Format('P%d: %d', [I, FGame.Score(I)]), False, 1, [], TTextAlign.Leading, TTextAlign.Center);
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
  DrawButton(FSmallGridRect, 'Small', FGame.DotCount = TJoinTheDotsGame.MinDotCount);
  DrawButton(FMediumGridRect, 'Medium', FGame.DotCount = TJoinTheDotsGame.MediumDotCount);
  DrawButton(FLargeGridRect, 'Large', FGame.DotCount = TJoinTheDotsGame.MaxDotCount);
  DrawButton(FSquareStyleRect, 'Squares', FGame.BoardStyle = bsSquares);
  DrawButton(FHexStyleRect, 'Hexes', FGame.BoardStyle = bsHexagons);
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
  Edge: TBoardEdge;
begin
  R := BoardRect;
  Canvas.Fill.Color := BoardBackgroundColor;
  Canvas.FillRect(RectF(0, 0, ClientWidth, ClientHeight), 0, 0, [], 1);

  DrawScoreboard;

  Canvas.Fill.Color := $FFFFFFFF;
  Canvas.FillRect(RectF(R.Left - 18, R.Top - 18, R.Right + 18, R.Bottom + 18), 8, 8, [], 1);

  for I := 0 to FGame.CellCount - 1 do
    DrawCellFill(FGame.Cell(I));

  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Color := GridLineColor;
  Canvas.Stroke.Thickness := 2;
  for I := 0 to FGame.EdgeCount - 1 do
  begin
    Edge := FGame.Edge(I);
    P1 := DotPoint(Edge.Dot1);
    P2 := DotPoint(Edge.Dot2);
    Canvas.DrawLine(P1, P2, 1);
  end;

  Canvas.Stroke.Thickness := Max(5, CellSize * 0.07);
  for I := 0 to FGame.EdgeCount - 1 do
  begin
    Edge := FGame.Edge(I);
    if Edge.Owner > 0 then
    begin
      Canvas.Stroke.Color := PlayerColors[Edge.Owner];
      P1 := DotPoint(Edge.Dot1);
      P2 := DotPoint(Edge.Dot2);
      Canvas.DrawLine(P1, P2, 1);
    end;
  end;

  DotRadius := Max(4, CellSize * 0.055);
  Canvas.Fill.Color := DotColor;
  for I := 0 to FGame.DotCountTotal - 1 do
  begin
    Center := DotPoint(I);
    Canvas.FillEllipse(RectF(Center.X - DotRadius, Center.Y - DotRadius,
      Center.X + DotRadius, Center.Y + DotRadius), 1);
  end;
end;

procedure TForm51.NewGame;
begin
  if FAITimer <> nil then
    FAITimer.Enabled := False;
  FGame.NewGame;
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

  if FGame.FindAIMove(Move) then
  begin
    CompletedCells := FGame.ClaimLine(Move);
    if CompletedCells = 0 then
      FGame.SwitchPlayer;
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
    FGame.SetGridSize(TJoinTheDotsGame.MinDotCount);
    NewGame;
    Exit;
  end;

  if FMediumGridRect.Contains(ClickPoint) then
  begin
    FGame.SetGridSize(TJoinTheDotsGame.MediumDotCount);
    NewGame;
    Exit;
  end;

  if FLargeGridRect.Contains(ClickPoint) then
  begin
    FGame.SetGridSize(TJoinTheDotsGame.MaxDotCount);
    NewGame;
    Exit;
  end;

  if FSquareStyleRect.Contains(ClickPoint) then
  begin
    FGame.SetBoardStyle(bsSquares);
    NewGame;
    Exit;
  end;

  if FHexStyleRect.Contains(ClickPoint) then
  begin
    FGame.SetBoardStyle(bsHexagons);
    NewGame;
    Exit;
  end;

  if FGame.IsGameOver or IsAITurn then
    Exit;

  if FindMoveAt(ClickPoint, Move) then
  begin
    CompletedCells := FGame.ClaimLine(Move);
    if CompletedCells = 0 then
      FGame.SwitchPlayer;
    Invalidate;
    QueueAITurn;
  end;
end;

procedure TForm51.FormPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
begin
  DrawBoard;
end;

end.
