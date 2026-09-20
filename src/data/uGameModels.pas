unit uGameModels;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, Generics.Collections;

type
  {=============================================================================
    ENUMERATIONS: Status Sistem dan Permainan
  =============================================================================}
  TGameState = (gsBooting, gsIdle, gsScanning, gsFiltering, gsDecrypting, gsPurging, gsPatientDead, gsPatientStable);
  TNodeState = (nsHealthy, nsAnomalous, nsEncrypted, nsCritical, nsPurged);
  TVirusClass = (vcPolymorphic, vcCascading, vcStealth, vcBruteForce);

  {=============================================================================
    RECORD: TNeuralNode
  =============================================================================}
  TNeuralNode = record
    NodeID: Integer;
    VectorX, VectorY: Single;
    State: TNodeState;
    BaseFrequency: Single;
    AnomalyFreq: Single;
    EncryptionHash: String;
    Stability: Single;

    procedure ResetToHealthy(NewID: Integer; X, Y: Single);
  end;

  {=============================================================================
    RECORD: TVirusSignature
  =============================================================================}
  TVirusSignature = record
    VirusID: Integer;
    CodeName: String;
    VClass: TVirusClass;
    TargetFreqRange: Single;
    MutationRate: Single;
  end;

  {=============================================================================
    RECORD: TPatientData
  =============================================================================}
  TPatientData = record
    PatientID: String;
    Alias: String;
    NeuralIntegrity: Single;
    SystemVitality: Single;
    Nodes: array of TNeuralNode;

    procedure Initialize(ID, NAlias: String; NodeCount: Integer);
  end;

  {=============================================================================
    CLASS: TPlayerProfile
  =============================================================================}
  TPlayerProfile = class
  private
    FPlayerName: String;
    FCredits: Integer;
    FSuccessRate: Single;
    FPatientsSaved: Integer;
    FPatientsLost: Integer;

    // BARU: Inventaris Black Market
    FHasOverclock: Boolean;
    FAutoPurges: Integer;
    FHasNeuralShield: Boolean;

    procedure RecalculateSuccessRate;
  public
    property PlayerName: String read FPlayerName write FPlayerName;
    property Credits: Integer read FCredits write FCredits;
    property SuccessRate: Single read FSuccessRate;
    property PatientsSaved: Integer read FPatientsSaved write FPatientsSaved;
    property PatientsLost: Integer read FPatientsLost write FPatientsLost;

    // BARU: Properti Black Market untuk diakses oleh Engine
    property HasOverclock: Boolean read FHasOverclock write FHasOverclock;
    property AutoPurges: Integer read FAutoPurges write FAutoPurges;
    property HasNeuralShield: Boolean read FHasNeuralShield write FHasNeuralShield;

    constructor Create(Name: String);
    procedure AddVictory(Reward: Integer);
    procedure AddDefeat;
  end;

implementation

{===============================================================================
  IMPLEMENTASI METHOD RECORD TNeuralNode
===============================================================================}
procedure TNeuralNode.ResetToHealthy(NewID: Integer; X, Y: Single);
begin
  NodeID := NewID;
  VectorX := X;
  VectorY := Y;
  State := nsHealthy;
  BaseFrequency := 8.0 + (Random * 4.0);
  AnomalyFreq := 0.0;
  EncryptionHash := '';
  Stability := 100.0;
end;

{===============================================================================
  IMPLEMENTASI METHOD RECORD TPatientData
===============================================================================}
procedure TPatientData.Initialize(ID, NAlias: String; NodeCount: Integer);
var
  i: Integer;
begin
  PatientID := ID;
  Alias := NAlias;
  NeuralIntegrity := 100.0;
  SystemVitality := 100.0;

  SetLength(Nodes, NodeCount);
  for i := 0 to NodeCount - 1 do
    Nodes[i].ResetToHealthy(i, 0.0, 0.0);
end;

{===============================================================================
  IMPLEMENTASI CLASS TPlayerProfile
===============================================================================}
constructor TPlayerProfile.Create(Name: String);
begin
  FPlayerName := Name;
  FCredits := 0;
  FPatientsSaved := 0;
  FPatientsLost := 0;
  FSuccessRate := 100.0;

  // BARU: Reset inventaris awal
  FHasOverclock := False;
  FAutoPurges := 0;
  FHasNeuralShield := False;
end;

procedure TPlayerProfile.RecalculateSuccessRate;
var
  Total: Integer;
begin
  Total := FPatientsSaved + FPatientsLost;
  if Total > 0 then
    FSuccessRate := (FPatientsSaved / Total) * 100.0
  else
    FSuccessRate := 100.0;
end;

procedure TPlayerProfile.AddVictory(Reward: Integer);
begin
  Inc(FPatientsSaved);
  Inc(FCredits, Reward);
  RecalculateSuccessRate;
end;

procedure TPlayerProfile.AddDefeat;
begin
  Inc(FPatientsLost);
  RecalculateSuccessRate;
end;

end.
