unit uTelemetryFilter;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$inline on} // Sangat penting untuk menghilangkan overhead pemanggilan fungsi di dalam loop DSP

interface

uses
  Classes, SysUtils, Math;

type
  {=============================================================================
    ENUM: TFilterType
    Jenis filter yang akan diterapkan pada sinyal EEG pasien
  =============================================================================}
  TFilterType = (ftLowPass, ftHighPass);

  {=============================================================================
    RECORD: TSignalFilter
    Implementasi IIR (Infinite Impulse Response) Filter yang efisien.
    Menyimpan state internal (PrevX, PrevY) untuk perhitungan sekuensial beruntun.
  =============================================================================}
  TSignalFilter = record
  private
    FType: TFilterType;
    FAlpha: Single;      // Konstanta smoothing/cutoff
    FPrevX: Single;      // Sampel input sebelumnya (X[n-1])
    FPrevY: Single;      // Sampel output sebelumnya (Y[n-1])
  public
    // Konfigurasi matematis filter berdasarkan frekuensi Cut-off yang dipilih pemain
    procedure Configure(AFilterType: TFilterType; CutoffFreq, SampleRate: Single);

    // Pemrosesan satu sampel data. Di-inline agar sangat cepat.
    function ProcessSample(X: Single): Single; inline;

    // Pemrosesan buffer array sekaligus secara in-place (tanpa duplikasi memori)
    procedure ProcessBuffer(var Buffer: array of Single);

    // Reset state jika pindah pasien atau node
    procedure ResetState;
  end;

  {=============================================================================
    RECORD: TTelemetryIsolator
    Mekanik utama game: Menggabungkan Low-Pass dan High-Pass menjadi Band-Pass
    untuk "mengisolasi" frekuensi virus dari frekuensi dasar otak (noise).
  =============================================================================}
  TTelemetryIsolator = record
  private
    FLowPassFilter: TSignalFilter;
    FHighPassFilter: TSignalFilter;
  public
    // Rentang frekuensi yang dicurigai sebagai virus
    procedure SetIsolationBand(LowCutoff, HighCutoff, SampleRate: Single);
    procedure IsolateAnomaly(var DataBuffer: array of Single);
  end;

implementation

{===============================================================================
  IMPLEMENTASI RECORD TSignalFilter
===============================================================================}

procedure TSignalFilter.Configure(AFilterType: TFilterType; CutoffFreq, SampleRate: Single);
var
  dt, RC: Single;
begin
  FType := AFilterType;
  ResetState;

  // Pencegahan pembagian dengan nol
  if CutoffFreq <= 0.0 then CutoffFreq := 0.1;
  if SampleRate <= 0.0 then SampleRate := 44100.0;

  // Waktu sampel (Delta Time)
  dt := 1.0 / SampleRate;

  // Time Constant (RC) untuk filter RC analog yang disimulasikan secara digital
  RC := 1.0 / (2.0 * Pi * CutoffFreq);

  // Perhitungan koefisien Alpha (bobot) berdasarkan jenis filter
  if FType = ftLowPass then
    FAlpha := dt / (RC + dt)
  else
    FAlpha := RC / (RC + dt); // High-Pass
end;

function TSignalFilter.ProcessSample(X: Single): Single;
begin
  if FType = ftLowPass then
    // Persamaan Low-Pass: Mengambil rata-rata berbobot antara input saat ini dan output sebelumnya
    Result := FPrevY + FAlpha * (X - FPrevY)
  else
    // Persamaan High-Pass: Mengambil perubahan sinyal, meredam sinyal berfrekuensi rendah
    Result := FAlpha * (FPrevY + X - FPrevX);

  // Simpan state untuk iterasi selanjutnya (Memory persistence)
  FPrevX := X;
  FPrevY := Result;
end;

procedure TSignalFilter.ProcessBuffer(var Buffer: array of Single);
var
  i, BufferCount: Integer;
begin
  BufferCount := Length(Buffer);
  // Loop dioptimasi. Karena ProcessSample di-inline, ini secepat iterasi array biasa
  for i := 0 to BufferCount - 1 do
    Buffer[i] := ProcessSample(Buffer[i]);
end;

procedure TSignalFilter.ResetState;
begin
  FPrevX := 0.0;
  FPrevY := 0.0;
end;

{===============================================================================
  IMPLEMENTASI RECORD TTelemetryIsolator (Mekanik Gameplay)
===============================================================================}

procedure TTelemetryIsolator.SetIsolationBand(LowCutoff, HighCutoff, SampleRate: Single);
begin
  // Atur High-Pass filter untuk memotong frekuensi di bawah batas bawah (membuang bass noise otak)
  FHighPassFilter.Configure(ftHighPass, LowCutoff, SampleRate);

  // Atur Low-Pass filter untuk memotong frekuensi di atas batas atas (membuang static noise)
  FLowPassFilter.Configure(ftLowPass, HighCutoff, SampleRate);
end;

procedure TTelemetryIsolator.IsolateAnomaly(var DataBuffer: array of Single);
begin
  // Band-pass filtering: Data dilewatkan secara berurutan ke High-Pass lalu Low-Pass.
  // Sinyal yang tersisa di dalam DataBuffer adalah frekuensi murni dari anomali/virus neural.
  FHighPassFilter.ProcessBuffer(DataBuffer);
  FLowPassFilter.ProcessBuffer(DataBuffer);
end;

end.

