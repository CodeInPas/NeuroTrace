unit uSQLiteManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, sqlite3conn, Dialogs, uGameModels;

type
  {=============================================================================
    CLASS: TDatabaseManager
    Menangani koneksi SQLite, transaksi, dan inisialisasi skema tabel.
  =============================================================================}
  TDatabaseManager = class
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FDBPath: String;

    procedure InitializeSchema;
  public
    constructor Create(const ADBPath: String);
    destructor Destroy; override;

    function ExecuteSQL(const ASQL: String): Boolean;
    function FetchData(const ASQL: String): TSQLQuery;
  end;

implementation

{===============================================================================
  Inisialisasi Manager dan Koneksi
===============================================================================}
constructor TDatabaseManager.Create(const ADBPath: String);
var
  DBDir: String;
begin
  DBDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'data';

  if not DirectoryExists(DBDir) then
  begin
    if not ForceDirectories(DBDir) then
      ShowMessage('CRITICAL: Gagal membuat folder database di ' + DBDir);
  end;

  FDBPath := IncludeTrailingPathDelimiter(DBDir) + ExtractFileName(ADBPath);

  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);

  FConnection.DatabaseName := FDBPath;
  FConnection.Transaction := FTransaction;
  FTransaction.DataBase := FConnection;

  try
    FConnection.Connected := True;
    InitializeSchema;
  except
    on E: Exception do
    begin
      ShowMessage('CRITICAL ERROR DB: Gagal menginisialisasi SQLite.' + sLineBreak +
                  'Path: ' + FDBPath + sLineBreak +
                  'Pesan: ' + E.Message);
    end;
  end;
end;

{===============================================================================
  Pembersihan Memori (Destructor)
===============================================================================}
destructor TDatabaseManager.Destroy;
begin
  if Assigned(FConnection) then
  begin
    if FConnection.Connected then
      FConnection.Connected := False;
    FConnection.Free;
  end;

  if Assigned(FTransaction) then
    FTransaction.Free;

  inherited Destroy;
end;

{===============================================================================
  Inisialisasi Skema Database (Tabel & Relasi)
===============================================================================}
procedure TDatabaseManager.InitializeSchema;
begin
  // PERBAIKAN: Penambahan kolom Black Market pada tb_player_profile
  ExecuteSQL(
    'CREATE TABLE IF NOT EXISTS tb_player_profile (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    'player_name TEXT NOT NULL, ' +
    'credits INTEGER DEFAULT 0, ' +
    'patients_saved INTEGER DEFAULT 0, ' +
    'patients_lost INTEGER DEFAULT 0, ' +
    'has_overclock INTEGER DEFAULT 0, ' +
    'auto_purges INTEGER DEFAULT 0, ' +
    'has_shield INTEGER DEFAULT 0)'
  );

  ExecuteSQL(
    'CREATE TABLE IF NOT EXISTS tb_virus_encyclopedia (' +
    'virus_id INTEGER PRIMARY KEY, ' +
    'code_name TEXT NOT NULL, ' +
    'v_class INTEGER NOT NULL, ' +
    'target_freq REAL NOT NULL, ' +
    'mutation_rate REAL NOT NULL)'
  );

  ExecuteSQL(
    'CREATE TABLE IF NOT EXISTS tb_patient_records (' +
    'record_id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    'patient_code TEXT NOT NULL, ' +
    'alias TEXT, ' +
    'survival_status INTEGER DEFAULT 0, ' +
    'operation_date DATETIME DEFAULT CURRENT_TIMESTAMP)'
  );
end;

{===============================================================================
  Utilitas Eksekusi SQL Cepat (INSERT, UPDATE, DELETE)
===============================================================================}
function TDatabaseManager.ExecuteSQL(const ASQL: String): Boolean;
begin
  Result := False;
  try
    if not FTransaction.Active then
      FTransaction.StartTransaction;

    FConnection.ExecuteDirect(ASQL);
    FTransaction.Commit;
    Result := True;
  except
    on E: Exception do
    begin
      if FTransaction.Active then
        FTransaction.Rollback;
      ShowMessage('DB Execute Error: ' + E.Message + sLineBreak + 'SQL: ' + ASQL);
    end;
  end;
end;

{===============================================================================
  Utilitas Pengambilan Data (SELECT)
===============================================================================}
function TDatabaseManager.FetchData(const ASQL: String): TSQLQuery;
var
  Query: TSQLQuery;
begin
  Query := TSQLQuery.Create(nil);
  Query.DataBase := FConnection;
  Query.Transaction := FTransaction;
  Query.SQL.Text := ASQL;

  try
    Query.Open;
    Result := Query;
  except
    on E: Exception do
    begin
      Query.Free;
      Result := nil;
      ShowMessage('DB Fetch Error: ' + E.Message + sLineBreak + 'SQL: ' + ASQL);
    end;
  end;
end;

end.
