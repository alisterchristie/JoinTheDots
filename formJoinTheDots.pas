unit formJoinTheDots;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs;

type
  TLineKind = (lkNone, lkHorizontal, lkVertical);

  TMoveTarget = record
    Kind: TLineKind;
    Row: Integer;
    Col: Integer;
    Distance: Single;
  end;

  TForm51 = class(TForm)
  private const
    MinDotCount = 4;
    MediumDotCount = 6;
    MaxDotCount = 8;
    PlayerCount = 2;
  private
    FHorizontalLines: array[0..MaxDotCount - 1, 0..MaxDotCount - 2] of Integer;
    FVerticalLines: array[0..MaxDotCount - 2, 0..MaxDotCount - 1] of Integer;
    FBoxOwners: array[0..MaxDotCount - 2, 0..MaxDotCount - 2] of Integer;
    FCurrentPlayer: Integer;
    FDotCount: Integer;
    FBoxCount: Integer;
    FScores: array[1..PlayerCount] of Integer;
    FNewGameRect: TRectF;
    FModeRect: TRectF;
    FSmallGridRect: TRectF;
    FMediumGridRect: TRectF;
    FLargeGridRect: TRectF;
    FPlayAgainstAI: Boolean;
    FAITimer: TTimer;
    function BoardRect: TRectF;
    function CellSize: Single;
    function DotPoint(const ARow, ACol: Integer): TPointF;
    function IsAITurn: Boolean;
    function IsGameOver: Boolean;
    function IsLineClaimed(const AKind: TLineKind; const ARow, ACol: Integer): Boolean;
    function LineAlreadyClaimed(const AMove: TMoveTarget): Boolean;
    function FindMoveAt(const APoint: TPointF; out AMove: TMoveTarget): Boolean;
    function CountBoxSides(const ARow, ACol: Integer; const AMove: TMoveTarget): Integer;
    function CountCompletedBoxesForMove(const AMove: TMoveTarget): Integer;
    function MoveCreatesThreeSidedBox(const AMove: TMoveTarget): Boolean;
    function FindAIMove(out AMove: TMoveTarget): Boolean;
    function ClaimLine(const AMove: TMoveTarget): Integer;
    function TryCompleteBox(const ARow, ACol: Integer): Boolean;
    procedure AITimer(Sender: TObject);
    procedure DrawBoard;
    procedure DrawButton(const ARect: TRectF; const AText: string; const ASelected: Boolean);
    procedure DrawScoreboard;
    procedure FormPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure NewGame;
    procedure QueueAITurn;
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
  Width := 820;
  Height := 740;
  OnPaint := FormPaint;
  Randomize;

  FDotCount := MediumDotCount;
  FBoxCount := FDotCount - 1;
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

function TForm51.BoardRect: TRectF;
var
  AvailableWidth: Single;
  AvailableHeight: Single;
  Size: Single;
  LeftPos: Single;
  TopPos: Single;
begin
  AvailableWidth := Max(240, ClientWidth - 80);
  AvailableHeight := Max(240, ClientHeight - 260);
  Size := Min(AvailableWidth, AvailableHeight);
  LeftPos := (ClientWidth - Size) / 2;
  TopPos := 205 + (AvailableHeight - Size) / 2;
  Result := RectF(LeftPos, TopPos, LeftPos + Size, TopPos + Size);
end;

function TForm51.CellSize: Single;
begin
  Result := BoardRect.Width / FBoxCount;
end;

function TForm51.DotPoint(const ARow, ACol: Integer): TPointF;
var
  R: TRectF;
  Step: Single;
begin
  R := BoardRect;
  Step := R.Width / FBoxCount;
  Result := PointF(R.Left + ACol * Step, R.Top + ARow * Step);
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
  HeaderRect := RectF(32, 24, ClientWidth - 32, 185);

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

  DrawButton(FNewGameRect, 'New game', False);
  if FPlayAgainstAI then
    DrawButton(FModeRect, 'Vs AI', True)
  else
    DrawButton(FModeRect, '2 players', True);
  DrawButton(FSmallGridRect, 'Small', FDotCount = MinDotCount);
  DrawButton(FMediumGridRect, 'Medium', FDotCount = MediumDotCount);
  DrawButton(FLargeGridRect, 'Large', FDotCount = MaxDotCount);
end;

procedure TForm51.DrawBoard;
var
  R: TRectF;
  Row: Integer;
  Col: Integer;
  Center: TPointF;
  Owner: Integer;
  P1: TPointF;
  P2: TPointF;
  DotRadius: Single;
begin
  R := BoardRect;
  Canvas.Fill.Color := BoardBackgroundColor;
  Canvas.FillRect(RectF(0, 0, ClientWidth, ClientHeight), 0, 0, [], 1);

  DrawScoreboard;

  Canvas.Fill.Color := $FFFFFFFF;
  Canvas.FillRect(RectF(R.Left - 18, R.Top - 18, R.Right + 18, R.Bottom + 18), 8, 8, [], 1);

  for Row := 0 to FBoxCount - 1 do
    for Col := 0 to FBoxCount - 1 do
    begin
      Owner := FBoxOwners[Row, Col];
      if Owner > 0 then
      begin
        P1 := DotPoint(Row, Col);
        P2 := DotPoint(Row + 1, Col + 1);
        Canvas.Fill.Color := PlayerColors[Owner] and $2FFFFFFF;
        Canvas.FillRect(RectF(P1.X + 5, P1.Y + 5, P2.X - 5, P2.Y - 5), 4, 4, [], 1);
        Canvas.Font.Size := Max(18, CellSize * 0.3);
        Canvas.Font.Style := [TFontStyle.fsBold];
        Canvas.Fill.Color := PlayerColors[Owner];
        Canvas.FillText(RectF(P1.X, P1.Y, P2.X, P2.Y), IntToStr(Owner), False, 1, [],
          TTextAlign.Center, TTextAlign.Center);
      end;
    end;

  Canvas.Stroke.Kind := TBrushKind.Solid;
  Canvas.Stroke.Color := GridLineColor;
  Canvas.Stroke.Thickness := 2;
  for Row := 0 to FDotCount - 1 do
    for Col := 0 to FDotCount - 2 do
      Canvas.DrawLine(DotPoint(Row, Col), DotPoint(Row, Col + 1), 1);
  for Row := 0 to FDotCount - 2 do
    for Col := 0 to FDotCount - 1 do
      Canvas.DrawLine(DotPoint(Row, Col), DotPoint(Row + 1, Col), 1);

  Canvas.Stroke.Thickness := Max(6, CellSize * 0.08);
  for Row := 0 to FDotCount - 1 do
    for Col := 0 to FDotCount - 2 do
      if FHorizontalLines[Row, Col] > 0 then
      begin
        Canvas.Stroke.Color := PlayerColors[FHorizontalLines[Row, Col]];
        Canvas.DrawLine(DotPoint(Row, Col), DotPoint(Row, Col + 1), 1);
      end;

  for Row := 0 to FDotCount - 2 do
    for Col := 0 to FDotCount - 1 do
      if FVerticalLines[Row, Col] > 0 then
      begin
        Canvas.Stroke.Color := PlayerColors[FVerticalLines[Row, Col]];
        Canvas.DrawLine(DotPoint(Row, Col), DotPoint(Row + 1, Col), 1);
      end;

  DotRadius := Max(5, CellSize * 0.07);
  Canvas.Fill.Color := DotColor;
  for Row := 0 to FDotCount - 1 do
    for Col := 0 to FDotCount - 1 do
    begin
      Center := DotPoint(Row, Col);
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
  Result := FScores[1] + FScores[2] = FBoxCount * FBoxCount;
end;

function TForm51.IsLineClaimed(const AKind: TLineKind; const ARow, ACol: Integer): Boolean;
begin
  case AKind of
    lkHorizontal:
      Result := FHorizontalLines[ARow, ACol] > 0;
    lkVertical:
      Result := FVerticalLines[ARow, ACol] > 0;
  else
    Result := False;
  end;
end;

function TForm51.LineAlreadyClaimed(const AMove: TMoveTarget): Boolean;
begin
  Result := IsLineClaimed(AMove.Kind, AMove.Row, AMove.Col);
end;

function TForm51.FindMoveAt(const APoint: TPointF; out AMove: TMoveTarget): Boolean;
var
  R: TRectF;
  Step: Single;
  Tolerance: Single;
  Row: Integer;
  Col: Integer;
  Candidate: TMoveTarget;
  Distance: Single;
begin
  Result := False;
  AMove.Kind := lkNone;
  AMove.Row := -1;
  AMove.Col := -1;
  AMove.Distance := MaxSingle;

  R := BoardRect;
  Step := R.Width / FBoxCount;
  Tolerance := Max(16, Step * 0.22);

  Row := Round((APoint.Y - R.Top) / Step);
  if (Row >= 0) and (Row < FDotCount) and (APoint.X >= R.Left) and (APoint.X <= R.Right) then
  begin
    Col := Floor((APoint.X - R.Left) / Step);
    if (Col >= 0) and (Col < FDotCount - 1) then
    begin
      Distance := Abs(APoint.Y - (R.Top + Row * Step));
      if Distance <= Tolerance then
      begin
        Candidate.Kind := lkHorizontal;
        Candidate.Row := Row;
        Candidate.Col := Col;
        Candidate.Distance := Distance;
        if not LineAlreadyClaimed(Candidate) then
        begin
          AMove := Candidate;
          Result := True;
        end;
      end;
    end;
  end;

  Col := Round((APoint.X - R.Left) / Step);
  if (Col >= 0) and (Col < FDotCount) and (APoint.Y >= R.Top) and (APoint.Y <= R.Bottom) then
  begin
    Row := Floor((APoint.Y - R.Top) / Step);
    if (Row >= 0) and (Row < FDotCount - 1) then
    begin
      Distance := Abs(APoint.X - (R.Left + Col * Step));
      if (Distance <= Tolerance) and ((not Result) or (Distance < AMove.Distance)) then
      begin
        Candidate.Kind := lkVertical;
        Candidate.Row := Row;
        Candidate.Col := Col;
        Candidate.Distance := Distance;
        if not LineAlreadyClaimed(Candidate) then
        begin
          AMove := Candidate;
          Result := True;
        end;
      end;
    end;
  end;
end;

function TForm51.CountBoxSides(const ARow, ACol: Integer; const AMove: TMoveTarget): Integer;
begin
  Result := 0;
  if (ARow < 0) or (ARow >= FBoxCount) or (ACol < 0) or (ACol >= FBoxCount) then
    Exit;

  if (FHorizontalLines[ARow, ACol] > 0)
    or ((AMove.Kind = lkHorizontal) and (AMove.Row = ARow) and (AMove.Col = ACol)) then
    Inc(Result);
  if (FHorizontalLines[ARow + 1, ACol] > 0)
    or ((AMove.Kind = lkHorizontal) and (AMove.Row = ARow + 1) and (AMove.Col = ACol)) then
    Inc(Result);
  if (FVerticalLines[ARow, ACol] > 0)
    or ((AMove.Kind = lkVertical) and (AMove.Row = ARow) and (AMove.Col = ACol)) then
    Inc(Result);
  if (FVerticalLines[ARow, ACol + 1] > 0)
    or ((AMove.Kind = lkVertical) and (AMove.Row = ARow) and (AMove.Col = ACol + 1)) then
    Inc(Result);
end;

function TForm51.CountCompletedBoxesForMove(const AMove: TMoveTarget): Integer;
begin
  Result := 0;
  case AMove.Kind of
    lkHorizontal:
      begin
        if (AMove.Row > 0) and (FBoxOwners[AMove.Row - 1, AMove.Col] = 0)
          and (CountBoxSides(AMove.Row - 1, AMove.Col, AMove) = 4) then
          Inc(Result);
        if (AMove.Row < FBoxCount) and (FBoxOwners[AMove.Row, AMove.Col] = 0)
          and (CountBoxSides(AMove.Row, AMove.Col, AMove) = 4) then
          Inc(Result);
      end;
    lkVertical:
      begin
        if (AMove.Col > 0) and (FBoxOwners[AMove.Row, AMove.Col - 1] = 0)
          and (CountBoxSides(AMove.Row, AMove.Col - 1, AMove) = 4) then
          Inc(Result);
        if (AMove.Col < FBoxCount) and (FBoxOwners[AMove.Row, AMove.Col] = 0)
          and (CountBoxSides(AMove.Row, AMove.Col, AMove) = 4) then
          Inc(Result);
      end;
  end;
end;

function TForm51.MoveCreatesThreeSidedBox(const AMove: TMoveTarget): Boolean;
begin
  Result := False;
  case AMove.Kind of
    lkHorizontal:
      begin
        Result := ((AMove.Row > 0) and (FBoxOwners[AMove.Row - 1, AMove.Col] = 0)
          and (CountBoxSides(AMove.Row - 1, AMove.Col, AMove) = 3))
          or ((AMove.Row < FBoxCount) and (FBoxOwners[AMove.Row, AMove.Col] = 0)
          and (CountBoxSides(AMove.Row, AMove.Col, AMove) = 3));
      end;
    lkVertical:
      begin
        Result := ((AMove.Col > 0) and (FBoxOwners[AMove.Row, AMove.Col - 1] = 0)
          and (CountBoxSides(AMove.Row, AMove.Col - 1, AMove) = 3))
          or ((AMove.Col < FBoxCount) and (FBoxOwners[AMove.Row, AMove.Col] = 0)
          and (CountBoxSides(AMove.Row, AMove.Col, AMove) = 3));
      end;
  end;
end;

function TForm51.FindAIMove(out AMove: TMoveTarget): Boolean;
var
  Candidate: TMoveTarget;
  Row: Integer;
  Col: Integer;
  CandidateScore: Integer;
  BestScore: Integer;
  PickCount: Integer;

  procedure ConsiderMove(const AMoveToConsider: TMoveTarget; const ARequireSafe: Boolean);
  var
    SafeMove: Boolean;
  begin
    if LineAlreadyClaimed(AMoveToConsider) then
      Exit;

    CandidateScore := CountCompletedBoxesForMove(AMoveToConsider);
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

    SafeMove := not MoveCreatesThreeSidedBox(AMoveToConsider);
    if ARequireSafe and (not SafeMove) then
      Exit;

    Inc(PickCount);
    if Random(PickCount) = 0 then
      AMove := AMoveToConsider;
  end;

begin
  AMove.Kind := lkNone;
  AMove.Row := -1;
  AMove.Col := -1;
  AMove.Distance := 0;
  BestScore := 0;
  PickCount := 0;

  for Row := 0 to FDotCount - 1 do
    for Col := 0 to FDotCount - 2 do
    begin
      Candidate.Kind := lkHorizontal;
      Candidate.Row := Row;
      Candidate.Col := Col;
      Candidate.Distance := 0;
      ConsiderMove(Candidate, True);
    end;

  for Row := 0 to FDotCount - 2 do
    for Col := 0 to FDotCount - 1 do
    begin
      Candidate.Kind := lkVertical;
      Candidate.Row := Row;
      Candidate.Col := Col;
      Candidate.Distance := 0;
      ConsiderMove(Candidate, True);
    end;

  if PickCount = 0 then
  begin
    for Row := 0 to FDotCount - 1 do
      for Col := 0 to FDotCount - 2 do
      begin
        Candidate.Kind := lkHorizontal;
        Candidate.Row := Row;
        Candidate.Col := Col;
        Candidate.Distance := 0;
        ConsiderMove(Candidate, False);
      end;

    for Row := 0 to FDotCount - 2 do
      for Col := 0 to FDotCount - 1 do
      begin
        Candidate.Kind := lkVertical;
        Candidate.Row := Row;
        Candidate.Col := Col;
        Candidate.Distance := 0;
        ConsiderMove(Candidate, False);
      end;
  end;

  Result := AMove.Kind <> lkNone;
end;

function TForm51.TryCompleteBox(const ARow, ACol: Integer): Boolean;
begin
  Result := False;
  if (ARow < 0) or (ARow >= FBoxCount) or (ACol < 0) or (ACol >= FBoxCount) then
    Exit;

  if FBoxOwners[ARow, ACol] <> 0 then
    Exit;

  if (FHorizontalLines[ARow, ACol] > 0)
    and (FHorizontalLines[ARow + 1, ACol] > 0)
    and (FVerticalLines[ARow, ACol] > 0)
    and (FVerticalLines[ARow, ACol + 1] > 0) then
  begin
    FBoxOwners[ARow, ACol] := FCurrentPlayer;
    Inc(FScores[FCurrentPlayer]);
    Result := True;
  end;
end;

function TForm51.ClaimLine(const AMove: TMoveTarget): Integer;
begin
  Result := 0;
  case AMove.Kind of
    lkHorizontal:
      begin
        FHorizontalLines[AMove.Row, AMove.Col] := FCurrentPlayer;
        if TryCompleteBox(AMove.Row - 1, AMove.Col) then
          Inc(Result);
        if TryCompleteBox(AMove.Row, AMove.Col) then
          Inc(Result);
      end;
    lkVertical:
      begin
        FVerticalLines[AMove.Row, AMove.Col] := FCurrentPlayer;
        if TryCompleteBox(AMove.Row, AMove.Col - 1) then
          Inc(Result);
        if TryCompleteBox(AMove.Row, AMove.Col) then
          Inc(Result);
      end;
  end;
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

procedure TForm51.NewGame;
begin
  if FAITimer <> nil then
    FAITimer.Enabled := False;
  FillChar(FHorizontalLines, SizeOf(FHorizontalLines), 0);
  FillChar(FVerticalLines, SizeOf(FVerticalLines), 0);
  FillChar(FBoxOwners, SizeOf(FBoxOwners), 0);
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
  CompletedBoxes: Integer;
begin
  FAITimer.Enabled := False;
  if not IsAITurn then
    Exit;

  if FindAIMove(Move) then
  begin
    CompletedBoxes := ClaimLine(Move);
    if CompletedBoxes = 0 then
      SwitchPlayer;
    Invalidate;
    QueueAITurn;
  end;
end;

procedure TForm51.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Move: TMoveTarget;
  CompletedBoxes: Integer;
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

  if IsGameOver or IsAITurn then
    Exit;

  if FindMoveAt(ClickPoint, Move) then
  begin
    CompletedBoxes := ClaimLine(Move);
    if CompletedBoxes = 0 then
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
