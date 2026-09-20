unit uTerminalPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ExtCtrls, StdCtrls, LCLType,
  uGameEngine;

type
  {=============================================================================
    CLASS: TTerminalPanel
    Komponen antarmuka Terminal (Panel 1). Menangani input keyboard pemain,
    mencetak log sistem, dan berkomunikasi dengan uGameEngine.
  =============================================================================}
  TTerminalPanel = class(TCustomPanel)
  private
    FOutputLog: TMemo;
    FInputLine: TEdit;
    FEngine: TGameEngine;

    // Konfigurasi Visual Terminal
    FTerminalColor: TColor;
    FTerminalFont: String;

    procedure OnInputKeyPress(Sender: TObject; var Key: char);
    procedure ApplyStyling;
    procedure CullLogMemory;
  public
    // Reintroduce constructor untuk Dependency Injection (Game Engine)
    constructor Create(AOwner: TComponent; AEngine: TGameEngine); reintroduce;

    // Fungsi utilitas I/O
    procedure Print(const Msg: String);
    procedure ClearTerminal;
    procedure FocusInput;
  end;

implementation

const
  MAX_LOG_LINES = 500; // Mencegah TMemo memakan memori/CPU berlebih (Line Culling)

{===============================================================================
  Inisialisasi & Penyusunan Komponen Dinamis
===============================================================================}
constructor TTerminalPanel.Create(AOwner: TComponent; AEngine: TGameEngine);
begin
  inherited Create(AOwner);

  FEngine := AEngine;

  // Konfigurasi dasar Panel
  BevelOuter := bvNone;
  Color := RGBToColor(10, 12, 15); // Hitam pekat kebiruan (Material Dark)
  DoubleBuffered := True; // Mencegah flickering

  // Konfigurasi Tema (Bisa di-load dari uConfigLoader, hardcode default di sini)
  FTerminalColor := clLime; // Phosphor Green klasik
  FTerminalFont := 'Consolas'; // Font monospaced standar

  // 1. Membangun Output Log (TMemo)
  FOutputLog := TMemo.Create(Self);
  FOutputLog.Parent := Self;
  FOutputLog.Align := alClient;
  FOutputLog.ReadOnly := True;
  FOutputLog.ScrollBars := ssNone;// ssAutoVertical;
  FOutputLog.WordWrap := True;
  FOutputLog.BorderStyle := bsNone;
  FOutputLog.TabStop := False; // Pemain tidak boleh Tab ke area log

  // 2. Membangun Input Line (TEdit)
  FInputLine := TEdit.Create(Self);
  FInputLine.Color:=$00312156;
  FInputLine.Parent := Self;
  FInputLine.Align := alBottom;
  FInputLine.BorderStyle := bsNone;
  FInputLine.OnKeyPress := @OnInputKeyPress;

  ApplyStyling;

  // Cetak pesan pembuka
  Print('NEURO-TRACE OS v2.0.88');
  Print('INITIALIZING SECURE SHELL... DONE.');
  Print('TYPE ''HELP'' FOR AVAILABLE COMMANDS.');
end;

{===============================================================================
  Penerapan Gaya Visual (Cyber-Medical Aesthetic)
===============================================================================}
procedure TTerminalPanel.ApplyStyling;
begin
  self.Color:= clBlack;
  self.BorderSpacing.Around:=10;
  // Styling Output Log
  FOutputLog.Color := Self.Color;
  FOutputLog.Font.Name := FTerminalFont;
  FOutputLog.Font.Size := 10;
  FOutputLog.Font.Color := FTerminalColor;

  // Styling Input Line
  FInputLine.Color := RGBToColor(20, 24, 30); // Sedikit lebih terang dari log
  FInputLine.Font.Name := FTerminalFont;
  FInputLine.Font.Size := 11;
  FInputLine.Font.Style := [fsBold];
  FInputLine.Font.Color := FTerminalColor;
end;

{===============================================================================
  Penanganan Input Keyboard (Mendeteksi tombol Enter)
===============================================================================}
procedure TTerminalPanel.OnInputKeyPress(Sender: TObject; var Key: char);
var
  Cmd, EngineResponse: String;
begin
  // Jika tombol Enter ditekan (#13)
  if Key = #13 then
  begin
    Key := #0; // Matikan bunyi 'ding' default Windows

    Cmd := Trim(FInputLine.Text);
    if Cmd = '' then Exit;

    // 1. Echo perintah pemain ke layar (ditandai dengan '>')
    Print('> ' + Cmd);

    // 2. Kirim perintah ke Engine dan terima respon
    if Assigned(FEngine) then
    begin
      EngineResponse := FEngine.ProcessTerminalCommand(Cmd);
      if EngineResponse <> '' then
        Print(EngineResponse);
    end;

    // 3. Bersihkan baris input untuk perintah selanjutnya
    FInputLine.Clear;
  end;
end;

{===============================================================================
  Utilitas I/O dan Manajemen Memori (Line Culling)
===============================================================================}
procedure TTerminalPanel.Print(const Msg: String);
begin
  FOutputLog.Lines.Add(Msg);

  // Otomatis scroll ke baris paling bawah setiap ada pesan baru
  FOutputLog.SelStart := Length(FOutputLog.Text);
  FOutputLog.SelLength := 0;

  CullLogMemory;
end;

procedure TTerminalPanel.CullLogMemory;
var
  LinesToRemove, i: Integer;
begin
  // Jika jumlah baris melebihi batas, hapus 50 baris teratas agar UI tetap ringan
  if FOutputLog.Lines.Count > MAX_LOG_LINES then
  begin
    FOutputLog.Lines.BeginUpdate;
    try
      LinesToRemove := 50;
      for i := 1 to LinesToRemove do
        FOutputLog.Lines.Delete(0);
    finally
      FOutputLog.Lines.EndUpdate;
    end;
  end;
end;

procedure TTerminalPanel.ClearTerminal;
begin
  FOutputLog.Clear;
end;

procedure TTerminalPanel.FocusInput;
begin
  if FInputLine.CanFocus then
    FInputLine.SetFocus;
end;

end.

