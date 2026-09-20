unit ufrmMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  BGRABitmap, BGRABitmapTypes, // BARU: Pustaka untuk menggambar TCyberButton
  uGameEngine, uTerminalPanel, uControlBoardPanel, uGameModels;

type
  {=============================================================================
    BARU: KELAS TCyberButton (Tombol Custom bergaya Hologram)
  =============================================================================}
  TCyberButtonState = (cbsNormal, cbsHover, cbsDown);

  TCyberButton = class(TCustomControl)
  private
    FState: TCyberButtonState;
    FBuffer: TBGRABitmap;
    procedure SetState(AState: TCyberButtonState);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  { TfrmMain }
  TfrmMain = class(TForm)
    GameTimer: TTimer;
    pnTerminal: TPanel;
    pnlControlBoardHost: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure GameTimerTimer(Sender: TObject);
  private
    FEngine: TGameEngine;
    FTerminal: TTerminalPanel;
    FControlBoard: TControlBoardPanel;
    FLastTick: Int64;
    FTerminalWindow: TForm;

    FMenuPanel: TPanel;
    procedure CreateMainMenu;
    procedure OnLevelSelect(Sender: TObject);
    procedure OnExitClick(Sender: TObject);
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

{===============================================================================
  IMPLEMENTASI: TCyberButton
===============================================================================}
constructor TCyberButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque] - [csDoubleClicks];
  Width := 200;
  Height := 50;
  FState := cbsNormal;
  FBuffer := TBGRABitmap.Create(Width, Height);
  Cursor := crHandPoint; // Kursor berubah jadi tangan saat di-hover
end;

destructor TCyberButton.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TCyberButton.SetState(AState: TCyberButtonState);
begin
  if FState <> AState then
  begin
    FState := AState;
    Invalidate; // Paksa tombol menggambar ulang dirinya
  end;
end;

procedure TCyberButton.Resize;
begin
  inherited Resize;
  if Assigned(FBuffer) then
  begin
    FBuffer.Free;
    FBuffer := TBGRABitmap.Create(Width, Height);
  end;
end;

procedure TCyberButton.MouseEnter;
begin
  inherited MouseEnter;
  SetState(cbsHover);
end;

procedure TCyberButton.MouseLeave;
begin
  inherited MouseLeave;
  SetState(cbsNormal);
end;

procedure TCyberButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then SetState(cbsDown);
end;

procedure TCyberButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  // Pastikan klik dihitung jika mouse dilepas di dalam area tombol
  if (X >= 0) and (X <= Width) and (Y >= 0) and (Y <= Height) then
  begin
    SetState(cbsHover);
    if Assigned(OnClick) then OnClick(Self);
  end
  else
    SetState(cbsNormal);
end;

procedure TCyberButton.Paint;
var
  BgColor, BorderColor, TextColor: TBGRAPixel;
begin
  if not Assigned(FBuffer) then Exit;

  // Tentukan palet warna berdasarkan status
  case FState of
    cbsNormal:
    begin
      BgColor := BGRA(15, 20, 30, 200);           // Gelap transparan
      BorderColor := BGRA(100, 200, 255, 120);    // Cyber Blue redup
      TextColor := BGRA(100, 200, 255, 200);
    end;
    cbsHover:
    begin
      BgColor := BGRA(30, 50, 70, 255);           // Terang saat di-hover
      BorderColor := BGRA(150, 220, 255, 255);    // Cyber Blue menyala
      TextColor := BGRA(255, 255, 255, 255);      // Teks putih menyala
    end;
    cbsDown:
    begin
      BgColor := BGRA(100, 200, 255, 255);        // Solid biru saat ditekan
      BorderColor := BGRA(255, 255, 255, 255);
      TextColor := BGRA(10, 15, 25, 255);         // Teks gelap (Invert)
    end;
  end;

  FBuffer.Fill(BGRA(8, 10, 14, 255)); // Warna dasar background menu (meratakan ujung transparan)

  // 1. Gambar Background Kotak
  FBuffer.FillRect(2, 2, Width-2, Height-2, BgColor, dmSet);

  // 2. Gambar Border Garis Atas & Bawah
  FBuffer.DrawLineAntialias(0, 0, Width, 0, BorderColor, 2.0);
  FBuffer.DrawLineAntialias(0, Height-1, Width, Height-1, BorderColor, 2.0);

  // 3. Gambar Hiasan Sudut (Tech Corners)
  FBuffer.FillRect(0, 0, 6, 6, BorderColor);
  FBuffer.FillRect(Width-6, 0, Width, 6, BorderColor);
  FBuffer.FillRect(0, Height-6, 6, Height, BorderColor);
  FBuffer.FillRect(Width-6, Height-6, Width, Height, BorderColor);

  // 4. Gambar Teks Judul Level
  FBuffer.FontName := 'Consolas';
  FBuffer.FontHeight := 16;
  FBuffer.FontStyle := [fsBold];
  FBuffer.FontAntialias := True;
  FBuffer.TextOut(Width div 2, (Height div 2) - 8, Caption, TextColor, taCenter);

  // Transfer render ke kanvas sistem
  FBuffer.Draw(Canvas, 0, 0, True);
end;

{===============================================================================
  IMPLEMENTASI: TfrmMain
===============================================================================}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  try
    FEngine := TGameEngine.Create;

    {
    FTerminalWindow := TForm.Create(Self);
    FTerminalWindow.Caption := 'SECURE SHELL - NEURO-LINK [ACTIVE]';

    FTerminalWindow.Align:=alClient;
    FTerminalWindow.Width := 50;
    FTerminalWindow.Height := 10;
    FTerminalWindow.Position := poDefault;
    FTerminalWindow.Color := RGBToColor(10, 10, 10);
    FTerminalWindow.FormStyle := fsStayOnTop;
    }
    FTerminal := TTerminalPanel.Create(Self, FEngine);
    FTerminal.Parent := pnTerminal;
    FTerminal.BorderStyle:=bsNone;
    FTerminal.Align:=alClient;
    FTerminal.Show;
  // FTerminal.Parent:= ;

    FControlBoard := TControlBoardPanel.Create(Self, FEngine);
    FControlBoard.Parent := pnlControlBoardHost;
    FControlBoard.Align := alClient;

    CreateMainMenu;

    GameTimer.Interval := 16;
    GameTimer.Enabled := True;
    FLastTick := GetTickCount64;

  except
    on E: Exception do
    begin
      ShowMessage('CRASH SAAT STARTUP:' + sLineBreak + E.Message);
      Application.Terminate;
    end;
  end;
end;

procedure TfrmMain.CreateMainMenu;
var
  FMenuContainer: TPanel;
  lblTitle, lblSub: TLabel;
  btnEasy, btnMed, btnHard, btnExit: TCyberButton; // PERBAIKAN: Gunakan TCyberButton
begin
  FMenuPanel := TPanel.Create(Self);
  FMenuPanel.Parent := Self;
  FMenuPanel.Align := alClient;
  FMenuPanel.Color := RGBToColor(8, 10, 14);
  FMenuPanel.BevelOuter := bvNone;
  FMenuPanel.BringToFront;

  FMenuContainer := TPanel.Create(FMenuPanel);
  FMenuContainer.Parent := FMenuPanel;
  FMenuContainer.Width := 650;
  FMenuContainer.Height := 500; // Diperbesar sedikit agar lega
  FMenuContainer.BevelOuter := bvNone;
  FMenuContainer.Color := RGBToColor(8, 10, 14);

  FMenuContainer.AnchorSideLeft.Control := FMenuPanel;
  FMenuContainer.AnchorSideLeft.Side := asrCenter;
  FMenuContainer.AnchorSideTop.Control := FMenuPanel;
  FMenuContainer.AnchorSideTop.Side := asrCenter;
  FMenuContainer.Anchors := [akTop, akLeft];

  lblTitle := TLabel.Create(FMenuContainer);
  lblTitle.Parent := FMenuContainer;
  lblTitle.Caption := 'NEURO-TRACE 2088';
  lblTitle.Font.Name := 'Consolas';
  lblTitle.Font.Size := 48;
  lblTitle.Font.Style := [fsBold];
  lblTitle.Font.Color := RGBToColor(100, 200, 255);
  lblTitle.Align := alTop;
  lblTitle.Alignment := taCenter;

  lblSub := TLabel.Create(FMenuContainer);
  lblSub.Parent := FMenuContainer;
  lblSub.Caption := 'HOLOGRAPHIC DIAGNOSTIC TERMINAL';
  lblSub.Font.Name := 'Consolas';
  lblSub.Font.Size := 14;
  lblSub.Font.Color := clSilver;
  lblSub.Align := alTop;
  lblSub.Alignment := taCenter;
  lblSub.BorderSpacing.Bottom := 50;

  // Tombol Level 1
  btnEasy := TCyberButton.Create(FMenuContainer);
  btnEasy.Parent := FMenuContainer;
  btnEasy.Caption := 'LEVEL 1: INTERN (40 Nodes / 2 Threats)';
  btnEasy.Height := 55;
  btnEasy.Align := alTop;
  btnEasy.BorderSpacing.Bottom := 15;
  btnEasy.BorderSpacing.Left := 50;
  btnEasy.BorderSpacing.Right := 50;
  btnEasy.Tag := 0;
  btnEasy.OnClick := @OnLevelSelect;

  // Tombol Level 2
  btnMed := TCyberButton.Create(FMenuContainer);
  btnMed.Parent := FMenuContainer;
  btnMed.Caption := 'LEVEL 2: SPECIALIST (64 Nodes / 4 Threats)';
  btnMed.Height := 55;
  btnMed.Align := alTop;
  btnMed.BorderSpacing.Bottom := 15;
  btnMed.BorderSpacing.Left := 50;
  btnMed.BorderSpacing.Right := 50;
  btnMed.Tag := 1;
  btnMed.OnClick := @OnLevelSelect;

  // Tombol Level 3
  btnHard := TCyberButton.Create(FMenuContainer);
  btnHard.Parent := FMenuContainer;
  btnHard.Caption := 'LEVEL 3: CHIEF SURGEON (100 Nodes / 7 Threats)';
  btnHard.Height := 55;
  btnHard.Align := alTop;
  btnHard.BorderSpacing.Bottom := 45;
  btnHard.BorderSpacing.Left := 50;
  btnHard.BorderSpacing.Right := 50;
  btnHard.Tag := 2;
  btnHard.OnClick := @OnLevelSelect;

  // Tombol Keluar
  btnExit := TCyberButton.Create(FMenuContainer);
  btnExit.Parent := FMenuContainer;
  btnExit.Caption := 'TERMINATE CONNECTION (EXIT)';
  btnExit.Height := 55;
  btnExit.Align := alTop;
  btnExit.BorderSpacing.Left := 50;
  btnExit.BorderSpacing.Right := 50;
  btnExit.OnClick := @OnExitClick;
end;

procedure TfrmMain.OnLevelSelect(Sender: TObject);
begin
  FEngine.ActiveDifficulty := (Sender as TCyberButton).Tag;
  FMenuPanel.Visible := False;
  pnTerminal.Enabled:=true;
  if Assigned(FTerminalWindow) then
    FTerminalWindow.Show;
end;

procedure TfrmMain.OnExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  GameTimer.Enabled := False;
  if Assigned(FControlBoard) then FControlBoard.Free;
  if Assigned(FTerminal) then FTerminal.Free;
  if Assigned(FEngine) then FEngine.Free;
end;

procedure TfrmMain.GameTimerTimer(Sender: TObject);
var
  CurrentTick: Int64;
  DeltaTime: Single;
  LastState: TGameState;
begin
  if not Assigned(FEngine) then Exit;
//  pnTerminal.Enabled:=true;
  CurrentTick := GetTickCount64;
  DeltaTime := (CurrentTick - FLastTick) / 1000.0;
  FLastTick := CurrentTick;
  LastState := FEngine.State;

  FEngine.Update(DeltaTime);

  if (LastState <> FEngine.State) then
  begin
    if FEngine.State = gsIdle then
    begin
      if LastState = gsPatientStable then
        ShowMessage('SUCCESS: NEURAL PATHWAYS STABILIZED. +150 CREDITS.')
      else if LastState = gsPatientDead then
        ShowMessage('CRITICAL FAILURE: PATIENT FLATLINED. CONNECTION SEVERED.');
    end;
  end;

  if Assigned(FControlBoard) then
    FControlBoard.RedrawFrame;
end;

end.
