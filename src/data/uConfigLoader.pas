unit uConfigLoader;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, fpjson, jsonparser;

type
  {=============================================================================
    RECORD: TEngineSettings
    Menyimpan parameter konfigurasi state mesin, render, dan audio.
  =============================================================================}
  TEngineSettings = record
    ScreenWidth: Integer;
    ScreenHeight: Integer;
    Fullscreen: Boolean;
    TargetFPS: Integer;
    MasterVolume: Integer;         // 0 - 100
    BufferBASS: Integer;           // Buffer size untuk FFT (ms)
    UIGlassOpacity: Single;        // 0.0 - 1.0 (Intensitas efek glassmorphism)
    UIThemeColor: String;          // Kode Hex warna utama (misal: '#00FF00' untuk Phosphor Green)
  end;

  {=============================================================================
    CLASS: TConfigManager
    Menangani I/O file JSON. Didesain untuk diinstansiasi satu kali (Singleton/Global).
  =============================================================================}
  TConfigManager = class
  private
    FSettings: TEngineSettings;
    FConfigPath: String;
    procedure ApplyDefaults;
  public
    constructor Create(const AConfigPath: String);
    procedure LoadConfig;
    procedure SaveConfig;

    // Properti read-only untuk diakses oleh Engine dan UI
    property Settings: TEngineSettings read FSettings;
  end;

implementation

{===============================================================================
  Inisialisasi Manager dan Penentuan Path File JSON
===============================================================================}
constructor TConfigManager.Create(const AConfigPath: String);
begin
  FConfigPath := AConfigPath;
  ApplyDefaults; // Set nilai dasar terlebih dahulu sebelum mencoba membaca file
end;

{===============================================================================
  Konfigurasi Default (Failsafe / Fallback)
===============================================================================}
procedure TConfigManager.ApplyDefaults;
begin
  FSettings.ScreenWidth := 1920;
  FSettings.ScreenHeight := 1080;
  FSettings.Fullscreen := True;
  FSettings.TargetFPS := 60;
  FSettings.MasterVolume := 80;
  FSettings.BufferBASS := 1024;
  FSettings.UIGlassOpacity := 0.65;
  FSettings.UIThemeColor := '#00FF00'; // Phosphor Green khas Medical-Cyber
end;

{===============================================================================
  Membaca Konfigurasi dari File JSON
===============================================================================}
procedure TConfigManager.LoadConfig;
var
  JSONString: String;
  JSONData: TJSONData;
  JSONObject: TJSONObject;
  FileStream: TFileStream;
begin
  // Jika file tidak ada, abaikan dan gunakan defaults (nanti akan tersimpan otomatis jika dipanggil SaveConfig)
  if not FileExists(FConfigPath) then Exit;

  FileStream := TFileStream.Create(FConfigPath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(JSONString, FileStream.Size);
    if FileStream.Size > 0 then
      FileStream.ReadBuffer(JSONString[1], FileStream.Size);
  finally
    FileStream.Free;
  end;

  try
    JSONData := GetJSON(JSONString); // Parser bawaan fpjson
    try
      if JSONData.JSONType = jtObject then
      begin
        JSONObject := TJSONObject(JSONData);
        // Method .Get(Key, DefaultValue) sangat aman untuk mencegah error jika Key tidak ditemukan
        FSettings.ScreenWidth := JSONObject.Get('ScreenWidth', FSettings.ScreenWidth);
        FSettings.ScreenHeight := JSONObject.Get('ScreenHeight', FSettings.ScreenHeight);
        FSettings.Fullscreen := JSONObject.Get('Fullscreen', FSettings.Fullscreen);
        FSettings.TargetFPS := JSONObject.Get('TargetFPS', FSettings.TargetFPS);
        FSettings.MasterVolume := JSONObject.Get('MasterVolume', FSettings.MasterVolume);
        FSettings.BufferBASS := JSONObject.Get('BufferBASS', FSettings.BufferBASS);
        FSettings.UIGlassOpacity := JSONObject.Get('UIGlassOpacity', FSettings.UIGlassOpacity);
        FSettings.UIThemeColor := JSONObject.Get('UIThemeColor', FSettings.UIThemeColor);
      end;
    finally
      JSONData.Free;
    end;
  except
    on E: Exception do
      // Fallback diam-diam jika file JSON rusak/corrupt. Di fase rilis log bisa ditambahkan.
      ApplyDefaults;
  end;
end;

{===============================================================================
  Menyimpan Konfigurasi ke File JSON
===============================================================================}
procedure TConfigManager.SaveConfig;
var
  JSONObject: TJSONObject;
  StringStream: TStringStream;
begin
  JSONObject := TJSONObject.Create;
  try
    JSONObject.Add('ScreenWidth', FSettings.ScreenWidth);
    JSONObject.Add('ScreenHeight', FSettings.ScreenHeight);
    JSONObject.Add('Fullscreen', FSettings.Fullscreen);
    JSONObject.Add('TargetFPS', FSettings.TargetFPS);
    JSONObject.Add('MasterVolume', FSettings.MasterVolume);
    JSONObject.Add('BufferBASS', FSettings.BufferBASS);
    JSONObject.Add('UIGlassOpacity', FSettings.UIGlassOpacity);
    JSONObject.Add('UIThemeColor', FSettings.UIThemeColor);

    // FormatJSON menghasilkan string JSON yang terformat rapi (Pretty Print)
    StringStream := TStringStream.Create(JSONObject.FormatJSON());
    try
      StringStream.SaveToFile(FConfigPath);
    finally
      StringStream.Free;
    end;
  finally
    JSONObject.Free;
  end;
end;

end.

