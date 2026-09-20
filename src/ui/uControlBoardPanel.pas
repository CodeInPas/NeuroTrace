unit uControlBoardPanel;

{$mode objfpc}{$H+}
{$POINTERMATH ON}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, Graphics, Math,
  uGameEngine, uGameModels, uBGRARenderer;

type
  {=============================================================================
    CLASS: TControlBoardPanel
  =============================================================================}
  TControlBoardPanel = class(TCustomPanel)
  private
    FEngine: TGameEngine;
    FRenderer: TCyberRenderer;
    FPaintBox: TPaintBox;

    procedure SetupUI;
    procedure OnPaintBoxPaint(Sender: TObject);
    procedure OnPaintBoxResize(Sender: TObject);

    procedure DrawSpectrumOverlay;
    procedure DrawHUDOverlay;
    procedure DrawPatientLog;
  public
    constructor Create(AOwner: TComponent; AEngine: TGameEngine); reintroduce;
    destructor Destroy; override;

    procedure RedrawFrame;
  end;

implementation

constructor TControlBoardPanel.Create(AOwner: TComponent; AEngine: TGameEngine);
begin
  inherited Create(AOwner);
  FEngine := AEngine;

  BevelOuter := bvNone;
  Color := RGBToColor(15, 18, 22);
  DoubleBuffered := True;

  FRenderer := TCyberRenderer.Create(800, 600);
  SetupUI;
end;

destructor TControlBoardPanel.Destroy;
begin
  FRenderer.Free;
  inherited Destroy;
end;

procedure TControlBoardPanel.SetupUI;
begin
  FPaintBox := TPaintBox.Create(Self);
  FPaintBox.Parent := Self;
  FPaintBox.Align := alClient;
  FPaintBox.OnPaint := @OnPaintBoxPaint;
  FPaintBox.OnResize := @OnPaintBoxResize;
end;

procedure TControlBoardPanel.OnPaintBoxResize(Sender: TObject);
begin
  if Assigned(FRenderer) then
    FRenderer.ResizeBuffer(FPaintBox.Width, FPaintBox.Height);
end;

procedure TControlBoardPanel.RedrawFrame;
begin
  FPaintBox.Invalidate;
end;

procedure TControlBoardPanel.OnPaintBoxPaint(Sender: TObject);
begin
  if not Assigned(FEngine) then Exit;

  FRenderer.RenderFrame(FEngine.Patient, FEngine.Config.Settings, FEngine.IsRevealed);
  FRenderer.DrawToCanvas(FPaintBox.Canvas, 0, 0);

  DrawSpectrumOverlay;
  DrawHUDOverlay;
  DrawPatientLog;
end;

{===============================================================================
  RUTIN MENGGAMBAR REKAM MEDIS (Kanan Bawah)
===============================================================================}
procedure TControlBoardPanel.DrawPatientLog;
var
  RightX, BottomY, i: Integer;
  PatientData, PCode, PStatus: String;
begin
  if not Assigned(FEngine) then Exit;
  if FEngine.RecentRecords.Count = 0 then Exit;

  RightX := FPaintBox.Width - 320;
  BottomY := FPaintBox.Height - 200;

  if RightX < 400 then Exit;

  FPaintBox.Canvas.Font.Name := 'Consolas';
  FPaintBox.Canvas.Font.Size := 10;
  FPaintBox.Canvas.Font.Style := [fsBold];
  FPaintBox.Canvas.Brush.Style := bsClear;

  FPaintBox.Canvas.Font.Color := RGBToColor(100, 200, 255);
  FPaintBox.Canvas.TextOut(RightX, BottomY, 'RECENT OPERATIONS LOG:');

  FPaintBox.Canvas.Pen.Color := RGBToColor(100, 200, 255);
  FPaintBox.Canvas.Pen.Width := 1;
  FPaintBox.Canvas.MoveTo(RightX, BottomY + 18);
  FPaintBox.Canvas.LineTo(RightX + 300, BottomY + 18);

  BottomY := BottomY + 25;

  for i := 0 to FEngine.RecentRecords.Count - 1 do
  begin
    PatientData := FEngine.RecentRecords[i];
    PCode := Copy(PatientData, 1, Pos('=', PatientData) - 1);
    PStatus := Copy(PatientData, Pos('=', PatientData) + 1, Length(PatientData));

    FPaintBox.Canvas.Font.Color := clSilver;
    FPaintBox.Canvas.TextOut(RightX, BottomY + (i * 20), PCode);

    if PStatus = '1' then
    begin
      FPaintBox.Canvas.Font.Color := clLime;
      FPaintBox.Canvas.TextOut(RightX + 160, BottomY + (i * 20), '[ STABILIZED ]');
    end
    else
    begin
      FPaintBox.Canvas.Font.Color := clRed;
      FPaintBox.Canvas.TextOut(RightX + 160, BottomY + (i * 20), '[ FLATLINED  ]');
    end;
  end;
end;

{===============================================================================
  PERBAIKAN: RUTIN MENGGAMBAR HUD STATUS PASIEN (KANAN) & PATCHES (KIRI)
===============================================================================}
procedure TControlBoardPanel.DrawHUDOverlay;
var
  Vit: Single;
  C: TColor;
  BarW: Integer;
  i, ThreatCount, RightBound, LeftX: Integer;
  S: String;
begin
  if not Assigned(FEngine) or (FEngine.State = gsIdle) then Exit;

  Vit := FEngine.Patient.SystemVitality;

  ThreatCount := 0;
  for i := 0 to High(FEngine.Patient.Nodes) do
  begin
    if FEngine.Patient.Nodes[i].State in [nsAnomalous, nsEncrypted, nsCritical] then
      Inc(ThreatCount);
  end;

  if Vit > 50 then C := clLime
  else if Vit > 25 then C := RGBToColor(255, 165, 0)
  else C := clRed;

  FPaintBox.Canvas.Font.Name := 'Consolas';
  FPaintBox.Canvas.Font.Size := 11;
  FPaintBox.Canvas.Font.Style := [fsBold];
  FPaintBox.Canvas.Brush.Style := bsClear;

  // 1. PINDAHKAN SYS-PATCHES KE KIRI
  LeftX := 20;
  FPaintBox.Canvas.Font.Color := RGBToColor(100, 200, 255);
  FPaintBox.Canvas.TextOut(LeftX, 20, 'ACTIVE SYS-PATCHES:');

  FPaintBox.Canvas.Font.Color := clSilver;
  if FEngine.Player.HasOverclock then
    FPaintBox.Canvas.TextOut(LeftX, 40, 'OVERCLOCK : [ ONLINE ]')
  else
    FPaintBox.Canvas.TextOut(LeftX, 40, 'OVERCLOCK : [ OFFLINE ]');

  if FEngine.Player.HasNeuralShield then
    FPaintBox.Canvas.TextOut(LeftX, 60, 'SHIELD    : [ READY ]')
  else
    FPaintBox.Canvas.TextOut(LeftX, 60, 'SHIELD    : [ DEPLETED ]');

  FPaintBox.Canvas.TextOut(LeftX, 80, 'AUTOPURGE : [ ' + IntToStr(FEngine.Player.AutoPurges) + ' ]');

  // 2. PINDAHKAN STATUS PASIEN KE KANAN (RATA KANAN)
  RightBound := FPaintBox.Width - 20;
  FPaintBox.Canvas.Font.Color := C;

  S := 'PATIENT ID   : ' + FEngine.Patient.PatientID;
  FPaintBox.Canvas.TextOut(RightBound - FPaintBox.Canvas.TextWidth(S), 20, S);

  S := 'SYS VITALITY : ' + FormatFloat('0.00', Vit) + '%';
  FPaintBox.Canvas.TextOut(RightBound - FPaintBox.Canvas.TextWidth(S), 40, S);

  if ThreatCount > 0 then
    FPaintBox.Canvas.Font.Color := RGBToColor(255, 100, 100)
  else
    FPaintBox.Canvas.Font.Color := clLime;

  S := 'ACTIVE VIRUS : ' + IntToStr(ThreatCount) + ' NODES';
  FPaintBox.Canvas.TextOut(RightBound - FPaintBox.Canvas.TextWidth(S), 60, S);

  FPaintBox.Canvas.Font.Color := C;
  S := '';
  if (Vit < 25.0) and (Vit > 0.0) and (Odd(GetTickCount64 div 500)) then
    S := 'WARNING: IMMINENT NEURAL COLLAPSE!'
  else if Vit <= 0.0 then
    S := 'FLATLINE. CONNECTION TERMINATED.';

  if S <> '' then
    FPaintBox.Canvas.TextOut(RightBound - FPaintBox.Canvas.TextWidth(S), 80, S);

  // Gambar Health Bar Rata Kanan (Lebar 300)
  FPaintBox.Canvas.Brush.Style := bsSolid;
  FPaintBox.Canvas.Brush.Color := RGBToColor(20, 20, 20);
  FPaintBox.Canvas.Pen.Color := clDkGray;
  FPaintBox.Canvas.Rectangle(RightBound - 300, 105, RightBound, 115);

  if Vit > 0 then
  begin
    BarW := Round(298 * (Vit / 100.0));
    FPaintBox.Canvas.Brush.Color := C;
    FPaintBox.Canvas.Pen.Style := psClear;
    // Menggambar isi indikator dari kiri ke kanan di dalam area bar
    FPaintBox.Canvas.Rectangle(RightBound - 299, 106, (RightBound - 299) + BarW, 114);
    FPaintBox.Canvas.Pen.Style := psSolid;
  end;
end;

procedure TControlBoardPanel.DrawSpectrumOverlay;
var
  Spectrum: PSingle;
  i, X, Y, BaseY, BinCount: Integer;
  StepX: Single;
begin
  if not FEngine.AudioDSP.IsInitialized then Exit;

  Spectrum := FEngine.AudioDSP.GetSpectrumData;
  if Spectrum = nil then Exit;

  BaseY := FPaintBox.Height - 10;
  BinCount := 256;
  StepX := FPaintBox.Width / BinCount;

  FPaintBox.Canvas.Pen.Color := clAqua;
  FPaintBox.Canvas.Pen.Width := 1;

  FPaintBox.Canvas.MoveTo(0, BaseY);
  for i := 0 to BinCount - 1 do
  begin
    X := Round(i * StepX);
    Y := BaseY - Round(Min(1.0, Spectrum[i]) * 150.0);
    FPaintBox.Canvas.LineTo(X, Y);
  end;
end;

end.
