unit uNeuralMath;

{$mode objfpc}{$H+}
{$inline on}

interface

uses
  Classes, SysUtils, Math, uGameModels;

type
  TNeuralMath = class
  public
    class procedure GenerateNodeTopology(var Nodes: array of TNeuralNode; CenterX, CenterY, MaxRadius: Single);
    class function CalculateSynapseDistance(const NodeA, NodeB: TNeuralNode): Single; inline;
    class function GenerateEncryptionHash(ComplexityLevel: Integer): String;
    class function CalculateInversePhase(AnomalyFreq, BaselineFreq: Single): Single; inline;
  end;

implementation

const
  GOLDEN_ANGLE = 2.39996323;

{===============================================================================
  Distribusi Node Organik (Constant Density Vogel Spiral)
===============================================================================}
class procedure TNeuralMath.GenerateNodeTopology(var Nodes: array of TNeuralNode; CenterX, CenterY, MaxRadius: Single);
var
  i, NodeCount: Integer;
  RadiusFactor, Theta, R: Single;
begin
  NodeCount := Length(Nodes);
  if NodeCount = 0 then Exit;

  // PERBAIKAN: Terapkan Kepadatan Konstan.
  // Alih-alih menyebarkan jumlah node yang sedikit untuk menutupi radius maksimum,
  // kita mengunci RadiusFactor. Angka 10.0 didapat dari Akar Kuadrat 100 node (Level Tersulit)
  // Ini memastikan jarak antar node selalu rapat (di bawah batas 65.0).
  RadiusFactor := MaxRadius / 10.0;

  for i := 0 to NodeCount - 1 do
  begin
    Theta := i * GOLDEN_ANGLE;
    R := RadiusFactor * Sqrt(i);

    Nodes[i].VectorX := CenterX + (R * Cos(Theta));
    Nodes[i].VectorY := CenterY + (R * Sin(Theta));

    // PERBAIKAN: Kurangi distorsi jitter acak dari 15.0 menjadi 6.0
    // agar posisi node tidak terlempar keluar dari zona koneksi sinapsis
    Nodes[i].VectorX := Nodes[i].VectorX + ((Random - 0.5) * 6.0);
    Nodes[i].VectorY := Nodes[i].VectorY + ((Random - 0.5) * 6.0);
  end;
end;

class function TNeuralMath.CalculateSynapseDistance(const NodeA, NodeB: TNeuralNode): Single;
begin
  Result := Hypot(NodeB.VectorX - NodeA.VectorX, NodeB.VectorY - NodeA.VectorY);
end;

class function TNeuralMath.GenerateEncryptionHash(ComplexityLevel: Integer): String;
var
  i, HashLength: Integer;
  HexChars: String = '0123456789ABCDEF';
begin
  Result := '';
  HashLength := 4 + (ComplexityLevel * 2);
  for i := 1 to HashLength do
    Result := Result + HexChars[Random(16) + 1];
end;

class function TNeuralMath.CalculateInversePhase(AnomalyFreq, BaselineFreq: Single): Single;
var
  Deviation: Single;
begin
  Deviation := AnomalyFreq - BaselineFreq;
  if Deviation <> 0 then
    Result := BaselineFreq - (Deviation * Pi)
  else
    Result := 0.0;
end;

end.
