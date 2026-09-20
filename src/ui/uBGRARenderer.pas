unit uBGRARenderer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Math,
  BGRABitmap, BGRABitmapTypes,
  uGameModels, uConfigLoader, uNeuralMath;

type
  {=============================================================================
    RECORD: TCellularDust (Partikel latar belakang organik)
  =============================================================================}
  TCellularDust = record
    X, Y: Single;
    SpeedY: Single;
    Radius: Single;
    Alpha: Byte;
    Seed: Integer;
  end;

  {=============================================================================
    CLASS: TCyberRenderer
  =============================================================================}
  TCyberRenderer = class
  private
    FBuffer: TBGRABitmap;
    FWidth: Integer;
    FHeight: Integer;

    FDust: array[0..149] of TCellularDust;

    procedure InitDustParticles;
    procedure DrawDeepBackground(const ThemeHex: String);
    procedure DrawSynapses(const Patient: TPatientData; const ThemeHex: String);
    procedure DrawBrainNodes(const Patient: TPatientData; const ThemeHex: String; AIsRevealed: Boolean);

    function HexToBGRA(const HexColor: String; Alpha: Byte = 255): TBGRAPixel;
  public
    constructor Create(AWidth, AHeight: Integer);
    destructor Destroy; override;

    procedure ResizeBuffer(NewWidth, NewHeight: Integer);
    procedure RenderFrame(const Patient: TPatientData; const Settings: TEngineSettings; AIsRevealed: Boolean);
    procedure DrawToCanvas(DestCanvas: TCanvas; X, Y: Integer);
  end;

implementation

constructor TCyberRenderer.Create(AWidth, AHeight: Integer);
begin
  FWidth := AWidth;
  FHeight := AHeight;
  FBuffer := TBGRABitmap.Create(FWidth, FHeight);
  InitDustParticles;
end;

destructor TCyberRenderer.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TCyberRenderer.InitDustParticles;
var
  i: Integer;
begin
  for i := 0 to High(FDust) do
  begin
    FDust[i].X := Random(2000);
    FDust[i].Y := Random(2000);
    FDust[i].SpeedY := 0.1 + (Random(100) / 100.0) * 1.2;
    FDust[i].Radius := 0.5 + (Random(100) / 100.0) * 2.5;
    FDust[i].Alpha := 10 + Random(60);
    FDust[i].Seed := Random(360);
  end;
end;

procedure TCyberRenderer.ResizeBuffer(NewWidth, NewHeight: Integer);
begin
  if (FWidth = NewWidth) and (FHeight = NewHeight) then Exit;

  FWidth := NewWidth;
  FHeight := NewHeight;

  FBuffer.Free;
  FBuffer := TBGRABitmap.Create(FWidth, FHeight);
end;

function TCyberRenderer.HexToBGRA(const HexColor: String; Alpha: Byte): TBGRAPixel;
var
  CleanHex: String;
  R, G, B: Byte;
begin
  CleanHex := StringReplace(HexColor, '#', '', [rfReplaceAll]);

  if Length(CleanHex) = 6 then
  begin
    R := StrToIntDef('$' + Copy(CleanHex, 1, 2), 255);
    G := StrToIntDef('$' + Copy(CleanHex, 3, 2), 255);
    B := StrToIntDef('$' + Copy(CleanHex, 5, 2), 255);
    Result := BGRA(R, G, B, Alpha);
  end
  else
    Result := BGRA(255, 255, 255, Alpha);
end;

procedure TCyberRenderer.DrawDeepBackground(const ThemeHex: String);
var
  i: Integer;
  GridColor, ScanlineColor, DustColor: TBGRAPixel;
  ThemeBase: TBGRAPixel;
  Tick: Int64;
begin
  FBuffer.Fill(BGRA(8, 10, 14, 255));
  Tick := GetTickCount64;
  ThemeBase := HexToBGRA(ThemeHex, 255);

  for i := 0 to High(FDust) do
  begin
    FDust[i].Y := FDust[i].Y - FDust[i].SpeedY;
    FDust[i].X := FDust[i].X + Sin((Tick + FDust[i].Seed * 10) / 400.0) * 0.3;

    if FDust[i].Y < -10 then
    begin
      FDust[i].Y := FHeight + 10;
      FDust[i].X := Random(FWidth);
    end;

    DustColor := BGRA(ThemeBase.red, ThemeBase.green, ThemeBase.blue, FDust[i].Alpha);
    FBuffer.FillEllipseAntialias(FDust[i].X, FDust[i].Y, FDust[i].Radius, FDust[i].Radius, DustColor);
  end;

  GridColor := HexToBGRA(ThemeHex, 15);
  i := 0;
  while i < FWidth do
  begin
    FBuffer.DrawLineAntialias(i, 0, i, FHeight, GridColor, 1.0);
    Inc(i, 40);
  end;
  i := 0;
  while i < FHeight do
  begin
    FBuffer.DrawLineAntialias(0, i, FWidth, i, GridColor, 1.0);
    Inc(i, 40);
  end;

  ScanlineColor := BGRA(0, 0, 0, 40);
  i := 0;
  while i < FHeight do
  begin
    FBuffer.DrawLineAntialias(0, i, FWidth, i, ScanlineColor, 1.0);
    Inc(i, 3);
  end;
end;

procedure TCyberRenderer.DrawSynapses(const Patient: TPatientData; const ThemeHex: String);
var
  i, j: Integer;
  Dist, Progress, PulseX, PulseY: Single;
  LineColor, PulseColor: TBGRAPixel;
  CenterX, CenterY: Single;
  Tick: Int64;
begin
  if Length(Patient.Nodes) = 0 then Exit;

  CenterX := FWidth * 0.35;
  CenterY := FHeight / 2;

  LineColor := HexToBGRA(ThemeHex, 40);
  PulseColor := HexToBGRA(ThemeHex, 255);
  Tick := GetTickCount64;

  for i := 0 to High(Patient.Nodes) do
  begin
    for j := i + 1 to High(Patient.Nodes) do
    begin
      Dist := TNeuralMath.CalculateSynapseDistance(Patient.Nodes[i], Patient.Nodes[j]);

      if Dist < 65.0 then
      begin
        FBuffer.DrawLineAntialias(
          Patient.Nodes[i].VectorX + CenterX, Patient.Nodes[i].VectorY + CenterY,
          Patient.Nodes[j].VectorX + CenterX, Patient.Nodes[j].VectorY + CenterY,
          LineColor, 1.0
        );

        Progress := ((Tick div 20) + (i * 15) + (j * 10)) mod 100 / 100.0;
        PulseX := (Patient.Nodes[i].VectorX + CenterX) + (Patient.Nodes[j].VectorX - Patient.Nodes[i].VectorX) * Progress;
        PulseY := (Patient.Nodes[i].VectorY + CenterY) + (Patient.Nodes[j].VectorY - Patient.Nodes[i].VectorY) * Progress;

        FBuffer.FillEllipseAntialias(PulseX, PulseY, 1.5, 1.5, PulseColor);
      end;
    end;
  end;
end;

procedure TCyberRenderer.DrawBrainNodes(const Patient: TPatientData; const ThemeHex: String; AIsRevealed: Boolean);
var
  i: Integer;
  Node: TNeuralNode;
  NodeColor: TBGRAPixel;
  CenterX, CenterY: Single;
  IsWarningPulse: Boolean;
begin
  CenterX := FWidth * 0.35;
  CenterY := FHeight / 2;

  FBuffer.FontHeight := 16;
  FBuffer.FontName := 'Consolas';
  FBuffer.FontAntialias := True;
  FBuffer.FontStyle := [fsBold];

  for i := 0 to High(Patient.Nodes) do
  begin
    Node := Patient.Nodes[i];
    IsWarningPulse := False;

    // Tentukan warna titik node sesuai status
    if (not AIsRevealed) and (Node.State in [nsAnomalous, nsEncrypted, nsCritical]) then
    begin
      NodeColor := HexToBGRA(ThemeHex, 200);
    end
    else
    begin
      case Node.State of
        nsHealthy:   NodeColor := HexToBGRA(ThemeHex, 200);
        nsAnomalous: NodeColor := BGRA(255, 165, 0, 255);
        nsEncrypted: NodeColor := BGRA(255, 50, 50, 255);
        nsCritical:  NodeColor := BGRA(255, 0, 0, 255);
        nsPurged:    NodeColor := BGRA(100, 150, 255, 255);
      else
        NodeColor := BGRA(255, 255, 255, 255);
      end;

      if Node.State in [nsEncrypted, nsCritical] then
        IsWarningPulse := True;
    end;

    // Menggambar efek memendar (Glow) di bawah node
    FBuffer.FillEllipseAntialias(
      Node.VectorX + CenterX,
      Node.VectorY + CenterY,
      9.0, 9.0, BGRA(NodeColor.red, NodeColor.green, NodeColor.blue, 30)
    );

    // Menggambar titik node itu sendiri
    FBuffer.FillEllipseAntialias(
      Node.VectorX + CenterX,
      Node.VectorY + CenterY,
      3.0, 3.0, NodeColor
    );

    // PERBAIKAN: Menggambar teks ID dengan warna kuning statis, bukan NodeColor
    FBuffer.TextOut(
      Round(Node.VectorX + CenterX + 8),
      Round(Node.VectorY + CenterY - 10),
      IntToStr(i),
      BGRA(255, 255, 0, 255) // Warna kuning solid
    );

    // Animasi peringatan jika node terinfeksi
    if IsWarningPulse then
      FBuffer.EllipseAntialias(
        Node.VectorX + CenterX, Node.VectorY + CenterY,
        6.0 + (Sin(GetTickCount64 / 150.0) * 2.0),
        6.0 + (Sin(GetTickCount64 / 150.0) * 2.0),
        NodeColor, 1.5
      );
  end;
end;

procedure TCyberRenderer.RenderFrame(const Patient: TPatientData; const Settings: TEngineSettings; AIsRevealed: Boolean);
begin
  DrawDeepBackground(Settings.UIThemeColor);

  if Length(Patient.Nodes) > 0 then
  begin
    DrawSynapses(Patient, Settings.UIThemeColor);
    DrawBrainNodes(Patient, Settings.UIThemeColor, AIsRevealed);
  end;
end;

procedure TCyberRenderer.DrawToCanvas(DestCanvas: TCanvas; X, Y: Integer);
begin
  FBuffer.Draw(DestCanvas, X, Y, True);
end;

end.
