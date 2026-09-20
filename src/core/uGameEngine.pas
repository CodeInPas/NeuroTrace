unit uGameEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, sqldb, db,
  uGameModels, uNeuralMath, uConfigLoader,
  uSQLiteManager, uAudioDSP, uTelemetryFilter;

type
  {=============================================================================
    CLASS: TGameEngine
  =============================================================================}
  TGameEngine = class
  private
    FState: TGameState;
    FConfig: TConfigManager;
    FDB: TDatabaseManager;
    FAudioDSP: TAudioDSPManager;
    FPlayer: TPlayerProfile;

    FCurrentPatient: TPatientData;
    FIsolator: TTelemetryIsolator;

    FInfectionTimer: Single;
    FAppPath: String;

    FVirusFreq: Integer;
    FRevealTimer: Single;

    FRecentRecords: TStringList;
    FActiveDifficulty: Integer; // BARU: Penyimpan Level Permainan

    procedure LoadPlayerProfile;
    procedure LoadRecentRecords;
    procedure ProcessInfectionSpread(DeltaTime: Single);
    procedure CheckWinLossConditions;
    function GetIsRevealed: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure StartDiagnosticSession;
    procedure Update(DeltaTime: Single);

    procedure AdjustTelemetryFilter(LowCutoff, HighCutoff: Single);
    function ProcessTerminalCommand(const Command: String): String;

    property State: TGameState read FState;
    property Config: TConfigManager read FConfig;
    property DB: TDatabaseManager read FDB;
    property AudioDSP: TAudioDSPManager read FAudioDSP;
    property Player: TPlayerProfile read FPlayer;
    property Patient: TPatientData read FCurrentPatient;

    property IsRevealed: Boolean read GetIsRevealed;
    property RecentRecords: TStringList read FRecentRecords;
    property ActiveDifficulty: Integer read FActiveDifficulty write FActiveDifficulty; // BARU
  end;

implementation

const
  FILE_DB = 'neurotrace.db';
  FILE_CFG = 'settings.json';

constructor TGameEngine.Create;
begin
  FState := gsBooting;
  FInfectionTimer := 0.0;
  FRevealTimer := 0.0;
  FActiveDifficulty := 1; // Default Medium
  FRecentRecords := TStringList.Create;

  FAppPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));

  FConfig := TConfigManager.Create(FAppPath + FILE_CFG);
  FConfig.LoadConfig;

  FDB := TDatabaseManager.Create(FILE_DB);
  FAudioDSP := TAudioDSPManager.Create;

  FPlayer := TPlayerProfile.Create('GUEST_TRACE');
  LoadPlayerProfile;
  LoadRecentRecords;

  FState := gsIdle;
  Randomize;
end;

destructor TGameEngine.Destroy;
begin
  FRecentRecords.Free;
  FConfig.SaveConfig;
  FPlayer.Free;
  FAudioDSP.Free;
  FDB.Free;
  FConfig.Free;
  inherited Destroy;
end;

procedure TGameEngine.LoadPlayerProfile;
var
  Query: TSQLQuery;
begin
  Query := FDB.FetchData('SELECT * FROM tb_player_profile ORDER BY id DESC LIMIT 1');
  if Assigned(Query) then
  begin
    try
      if not Query.EOF then
      begin
        FPlayer.PlayerName := Query.FieldByName('player_name').AsString;
        FPlayer.Credits := Query.FieldByName('credits').AsInteger;
        FPlayer.PatientsSaved := Query.FieldByName('patients_saved').AsInteger;
        FPlayer.PatientsLost := Query.FieldByName('patients_lost').AsInteger;
        FPlayer.HasOverclock := Query.FieldByName('has_overclock').AsInteger = 1;
        FPlayer.AutoPurges := Query.FieldByName('auto_purges').AsInteger;
        FPlayer.HasNeuralShield := Query.FieldByName('has_shield').AsInteger = 1;
      end
      else
      begin
        FDB.ExecuteSQL('INSERT INTO tb_player_profile (player_name) VALUES (''NEURO_TECH_01'')');
        FPlayer.PlayerName := 'NEURO_TECH_01';
      end;
    finally
      Query.Free;
    end;
  end;
end;

procedure TGameEngine.LoadRecentRecords;
var
  Query: TSQLQuery;
begin
  FRecentRecords.Clear;
  Query := FDB.FetchData('SELECT patient_code, survival_status FROM tb_patient_records ORDER BY record_id DESC LIMIT 6');
  if Assigned(Query) then
  begin
    try
      while not Query.EOF do
      begin
        if Query.FieldByName('survival_status').AsInteger = 1 then
          FRecentRecords.Add(Query.FieldByName('patient_code').AsString + '=1')
        else
          FRecentRecords.Add(Query.FieldByName('patient_code').AsString + '=0');
        Query.Next;
      end;
    finally
      Query.Free;
    end;
  end;
end;

function TGameEngine.GetIsRevealed: Boolean;
begin
  Result := FRevealTimer > 0.0;
end;

procedure TGameEngine.StartDiagnosticSession;
var
  NewID: String;
  i, RandIndex, NodeCount, VirusCount: Integer;
begin
  FState := gsScanning;
  FInfectionTimer := 0.0;

  FVirusFreq := (Random(9) + 4) * 100;
  FRevealTimer := 0.0;

  // BARU: Konfigurasi Level Permainan
  case FActiveDifficulty of
    0: begin NodeCount := 40; VirusCount := 5; end;   // LEVEL 1: Mudah
    1: begin NodeCount := 64; VirusCount := 8; end;   // LEVEL 2: Sedang
    2: begin NodeCount := 100; VirusCount := 10; end;  // LEVEL 3: Sulit
    else begin NodeCount := 64; VirusCount := 8; end;
  end;

  NewID := 'PT-' + IntToHex(Random(999999), 6);
  FCurrentPatient.Initialize(NewID, 'SUBJECT_' + IntToStr(Random(100)), NodeCount);
  FCurrentPatient.SystemVitality := 100.0;

  TNeuralMath.GenerateNodeTopology(FCurrentPatient.Nodes, 0, 0, 300.0);

  // BARU: Tanam virus sesuai jumlah level
  for i := 1 to VirusCount do
  begin
    RandIndex := Random(Length(FCurrentPatient.Nodes));
    FCurrentPatient.Nodes[RandIndex].State := nsEncrypted;
  end;

  if FAudioDSP.IsInitialized then
  begin
    if FAudioDSP.LoadTargetSignal(FAppPath + 'data\signal.mp3') then
      FAudioDSP.Play;

  end;

  FState := gsFiltering;

end;

procedure TGameEngine.Update(DeltaTime: Single);
begin
  if (FState = gsIdle) or (FState = gsPatientDead) or (FState = gsPatientStable) then
    Exit;

  if FState in [gsFiltering, gsDecrypting] then
  begin
    if FRevealTimer > 0 then
      FRevealTimer := Max(0.0, FRevealTimer - DeltaTime);

    ProcessInfectionSpread(DeltaTime);
    CheckWinLossConditions;
  end;
end;

procedure TGameEngine.ProcessInfectionSpread(DeltaTime: Single);
var
  i, j, EncryptedCount: Integer;
  DamageRate, Dist: Single;
begin
  EncryptedCount := 0;
  FInfectionTimer := FInfectionTimer + DeltaTime;

  for i := 0 to High(FCurrentPatient.Nodes) do
  begin
    if FCurrentPatient.Nodes[i].State in [nsAnomalous, nsEncrypted, nsCritical] then
      Inc(EncryptedCount);
  end;

  // 1. PERLAMBAT PENURUNAN VITALITAS (Health Bar)
  // Ubah pengali dari 0.2 menjadi 0.05 agar darah turun sangat lambat
  DamageRate := EncryptedCount * 0.05;
  FCurrentPatient.SystemVitality := Max(0.0, FCurrentPatient.SystemVitality - (DamageRate * DeltaTime));

  // 2. PERLAMBAT PENYEBARAN VIRUS
  // Ubah dari 2.0 (detik) menjadi 5.0 atau 8.0 (detik)
  // agar virus lebih lama menunggu sebelum melompat ke node lain
  if FInfectionTimer >= 5.0 then
  begin
    FInfectionTimer := 0.0;
    for i := 0 to High(FCurrentPatient.Nodes) do
    begin
      if FCurrentPatient.Nodes[i].State = nsEncrypted then
      begin
        for j := 0 to High(FCurrentPatient.Nodes) do
        begin
          if (i <> j) and (FCurrentPatient.Nodes[j].State = nsHealthy) then
          begin
            Dist := TNeuralMath.CalculateSynapseDistance(FCurrentPatient.Nodes[i], FCurrentPatient.Nodes[j]);
            if (Dist < 65.0) and (Random < 0.15) then
            begin
              FCurrentPatient.Nodes[j].State := nsAnomalous;
              Break;
            end;
          end;
        end;
      end
      else if FCurrentPatient.Nodes[i].State = nsAnomalous then
      begin
        if Random < 0.25 then
          FCurrentPatient.Nodes[i].State := nsEncrypted;
      end;
    end;
  end;
end;

procedure TGameEngine.CheckWinLossConditions;
var
  i, ThreatCount: Integer;
begin
  if FCurrentPatient.SystemVitality <= 0.0 then
  begin
    FCurrentPatient.SystemVitality := 0.0;
    FState := gsPatientDead;
    FPlayer.AddDefeat;
    FDB.ExecuteSQL('UPDATE tb_player_profile SET patients_lost = ' + IntToStr(FPlayer.PatientsLost) + ' WHERE player_name = ''' + FPlayer.PlayerName + '''');
    FDB.ExecuteSQL('INSERT INTO tb_patient_records (patient_code, survival_status) VALUES (''' + FCurrentPatient.PatientID + ''', 0)');
    LoadRecentRecords;

    if FAudioDSP.IsInitialized then FAudioDSP.Stop;
    FState := gsIdle;
    Exit;
  end;

  if FState in [gsFiltering, gsDecrypting] then
  begin
    ThreatCount := 0;
    for i := 0 to High(FCurrentPatient.Nodes) do
    begin
      if FCurrentPatient.Nodes[i].State in [nsAnomalous, nsEncrypted, nsCritical] then
        Inc(ThreatCount);
    end;

    if ThreatCount = 0 then
    begin
      FState := gsPatientStable;
      FPlayer.AddVictory(150);
      FDB.ExecuteSQL('UPDATE tb_player_profile SET credits = ' + IntToStr(FPlayer.Credits) + ', patients_saved = ' + IntToStr(FPlayer.PatientsSaved) + ' WHERE player_name = ''' + FPlayer.PlayerName + '''');
      FDB.ExecuteSQL('INSERT INTO tb_patient_records (patient_code, survival_status) VALUES (''' + FCurrentPatient.PatientID + ''', 1)');
      LoadRecentRecords;

      if FAudioDSP.IsInitialized then FAudioDSP.Stop;
      FState := gsIdle;
    end;
  end;
end;

procedure TGameEngine.AdjustTelemetryFilter(LowCutoff, HighCutoff: Single);
begin
  FIsolator.SetIsolationBand(LowCutoff, HighCutoff, 44100.0);
end;

function TGameEngine.ProcessTerminalCommand(const Command: String): String;
var
  CmdLine, Cmd, Args: String;
  SpacePos, NodeIdx, InputFreq, i: Integer;
begin
  CmdLine := UpperCase(Trim(Command));
  if CmdLine = '' then Exit('');

  SpacePos := Pos(' ', CmdLine);
  if SpacePos > 0 then
  begin
    Cmd := Copy(CmdLine, 1, SpacePos - 1);
    Args := Trim(Copy(CmdLine, SpacePos + 1, Length(CmdLine)));
  end
  else
  begin
    Cmd := CmdLine;
    Args := '';
  end;

  if Cmd = 'HELP' then
    Result := 'COMMANDS: DIAG, ISOLATE [FREQ], PURGE [ID], AUTOPURGE, MARKET, BUY [ITEM], PROFILE, DISCONNECT'

  else if Cmd = 'PROFILE' then
  begin
    Result := 'USER: ' + FPlayer.PlayerName + ' | CREDITS: ' + IntToStr(FPlayer.Credits) +
              ' | SAVED: ' + IntToStr(FPlayer.PatientsSaved) + ' | LOST: ' + IntToStr(FPlayer.PatientsLost) + sLineBreak +
              'INV: [OVERCLOCK: ' + BoolToStr(FPlayer.HasOverclock, 'ON', 'OFF') +
              '] [SHIELD: ' + BoolToStr(FPlayer.HasNeuralShield, 'ON', 'OFF') +
              '] [AUTO-PURGE: ' + IntToStr(FPlayer.AutoPurges) + ']';
  end
  else if Cmd = 'MARKET' then
  begin
    Result := 'BLACK MARKET CATALOG (TYPE ''BUY [ITEM]'' TO PURCHASE):' + sLineBreak +
              '1. OVERCLOCK (500C)  - EXTENDS ISOLATION REVEAL TO 30 SECONDS.' + sLineBreak +
              '2. SHIELD (800C)     - ABSORBS 1 ACCIDENTAL HEALTHY NODE PURGE.' + sLineBreak +
              '3. AUTOPURGE (100C)  - INSTANTLY DESTROYS 1 RANDOM VIRUS NODE.';
  end
  else if Cmd = 'BUY' then
  begin
    if Args = 'OVERCLOCK' then
    begin
      if FPlayer.HasOverclock then Result := 'ERROR: OVERCLOCK ALREADY INSTALLED.'
      else if FPlayer.Credits >= 500 then
      begin
        FPlayer.Credits := FPlayer.Credits - 500;
        FPlayer.HasOverclock := True;
        FDB.ExecuteSQL('UPDATE tb_player_profile SET credits = ' + IntToStr(FPlayer.Credits) + ', has_overclock = 1 WHERE player_name = ''' + FPlayer.PlayerName + '''');
        Result := 'TRANSACTION SUCCESS. OVERCLOCK PERMANENTLY INSTALLED.';
      end else Result := 'ERROR: INSUFFICIENT CREDITS.';
    end
    else if Args = 'SHIELD' then
    begin
      if FPlayer.HasNeuralShield then Result := 'ERROR: NEURAL SHIELD ALREADY ACTIVE.'
      else if FPlayer.Credits >= 800 then
      begin
        FPlayer.Credits := FPlayer.Credits - 800;
        FPlayer.HasNeuralShield := True;
        FDB.ExecuteSQL('UPDATE tb_player_profile SET credits = ' + IntToStr(FPlayer.Credits) + ', has_shield = 1 WHERE player_name = ''' + FPlayer.PlayerName + '''');
        Result := 'TRANSACTION SUCCESS. NEURAL SHIELD ACTIVATED.';
      end else Result := 'ERROR: INSUFFICIENT CREDITS.';
    end
    else if Args = 'AUTOPURGE' then
    begin
      if FPlayer.Credits >= 100 then
      begin
        FPlayer.Credits := FPlayer.Credits - 100;
        FPlayer.AutoPurges := FPlayer.AutoPurges + 1;
        FDB.ExecuteSQL('UPDATE tb_player_profile SET credits = ' + IntToStr(FPlayer.Credits) + ', auto_purges = ' + IntToStr(FPlayer.AutoPurges) + ' WHERE player_name = ''' + FPlayer.PlayerName + '''');
        Result := 'TRANSACTION SUCCESS. AUTO-PURGE SCRIPT OBTAINED. TOTAL: ' + IntToStr(FPlayer.AutoPurges);
      end else Result := 'ERROR: INSUFFICIENT CREDITS.';
    end
    else Result := 'ERROR: UNKNOWN ITEM. VALID OPTIONS: OVERCLOCK, SHIELD, AUTOPURGE.';
  end
  else if Cmd = 'DIAG' then
  begin
    if FState = gsIdle then
    begin
      StartDiagnosticSession;
      Result := 'DIAGNOSTIC INITIATED... VIRUS CAMOUFLAGED. CARRIER SCANNED AT ~' + IntToStr(FVirusFreq) + ' HZ.';
    end
    else
      Result := 'ERROR: DIAGNOSTIC ALREADY IN PROGRESS.';
  end
  else if Cmd = 'ISOLATE' then
  begin
    if FState <> gsFiltering then Exit('ERROR: NO ACTIVE DIAGNOSTIC SESSION.');

    if TryStrToInt(Args, InputFreq) then
    begin
      if Abs(InputFreq - FVirusFreq) <= 50 then
      begin
        if FPlayer.HasOverclock then
        begin
          FRevealTimer := 30.0;
          Result := 'ISOLATION SUCCESSFUL (OVERCLOCK ACTIVE): CAMOUFLAGE NEUTRALIZED FOR 30 SECONDS.';
        end
        else
        begin
          FRevealTimer := 15.0;
          Result := 'ISOLATION SUCCESSFUL: CAMOUFLAGE NEUTRALIZED FOR 15 SECONDS.';
        end;
      end
      else
      begin
        FCurrentPatient.SystemVitality := FCurrentPatient.SystemVitality - 5.0;
        Result := 'ISOLATION FAILED: FREQUENCY MISMATCH. PATIENT STRESSED (-5% VIT).';
      end;
    end
    else
      Result := 'ERROR: INVALID SYNTAX. USAGE: ISOLATE [FREQ]';
  end
  else if Cmd = 'AUTOPURGE' then
  begin
    if FState <> gsFiltering then Exit('ERROR: NO ACTIVE DIAGNOSTIC SESSION.');

    if FPlayer.AutoPurges > 0 then
    begin
      NodeIdx := -1;
      for i := 0 to High(FCurrentPatient.Nodes) do
      begin
        if FCurrentPatient.Nodes[i].State in [nsAnomalous, nsEncrypted, nsCritical] then
        begin
          NodeIdx := i;
          Break;
        end;
      end;

      if NodeIdx <> -1 then
      begin
        FCurrentPatient.Nodes[NodeIdx].State := nsPurged;
        FPlayer.AutoPurges := FPlayer.AutoPurges - 1;
        FDB.ExecuteSQL('UPDATE tb_player_profile SET auto_purges = ' + IntToStr(FPlayer.AutoPurges) + ' WHERE player_name = ''' + FPlayer.PlayerName + '''');
        Result := 'AUTO-PURGE EXECUTED ON NODE [' + IntToStr(NodeIdx) + ']. CHARGES LEFT: ' + IntToStr(FPlayer.AutoPurges);
      end
      else Result := 'NO ACTIVE THREATS DETECTED. SAVE YOUR CHARGE.';
    end
    else Result := 'ERROR: NO AUTO-PURGE SCRIPTS AVAILABLE. BUY AT MARKET.';
  end
  else if Cmd = 'PURGE' then
  begin
    if FState <> gsFiltering then Exit('ERROR: NO ACTIVE DIAGNOSTIC SESSION.');

    if TryStrToInt(Args, NodeIdx) then
    begin
      if (NodeIdx >= 0) and (NodeIdx <= High(FCurrentPatient.Nodes)) then
      begin
        if FCurrentPatient.Nodes[NodeIdx].State in [nsAnomalous, nsEncrypted, nsCritical] then
        begin
          FCurrentPatient.Nodes[NodeIdx].State := nsPurged;
          Result := 'NODE [' + IntToStr(NodeIdx) + '] PURGED SUCCESSFULLY. VIRUS NEUTRALIZED.';
        end
        else if FCurrentPatient.Nodes[NodeIdx].State = nsHealthy then
        begin
          if FPlayer.HasNeuralShield then
          begin
            FPlayer.HasNeuralShield := False;
            FDB.ExecuteSQL('UPDATE tb_player_profile SET has_shield = 0 WHERE player_name = ''' + FPlayer.PlayerName + '''');
            Result := 'SHIELD ACTIVATED: HEALTHY TISSUE PROTECTED FROM PURGE. SHIELD DESTROYED.';
          end
          else
          begin
            FCurrentPatient.SystemVitality := FCurrentPatient.SystemVitality - 25.0;
            Result := 'CRITICAL ERROR: HEALTHY TISSUE DESTROYED! PATIENT VITALITY -25%.';
          end;
        end
        else
          Result := 'NODE [' + IntToStr(NodeIdx) + '] IS ALREADY CLEAN.';
      end
      else
        Result := 'ERROR: INVALID NODE ID. VALID RANGE IS 0 TO ' + IntToStr(High(FCurrentPatient.Nodes)) + '.';
    end
    else
      Result := 'ERROR: INVALID SYNTAX. USAGE: PURGE [NODE_ID]';
  end
  else if Cmd = 'DISCONNECT' then
  begin
    FState := gsIdle;
    if FAudioDSP.IsInitialized then FAudioDSP.Stop;
    Result := 'NEURO-LINK SEVERED. CONNECTION TERMINATED.';
  end
  else
    Result := 'ERROR: UNKNOWN SYNTAX. TYPE ''HELP'' FOR COMMAND LIST.';
end;

end.
