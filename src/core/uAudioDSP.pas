unit uAudioDSP;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, bass; // Membutuhkan library BASS (bass.dll / libbass.so)

type
  {=============================================================================
    CLASS: TAudioDSPManager
    Menangani inisialisasi BASS, pemutaran stream, dan Fast Fourier Transform (FFT)
  =============================================================================}
  TAudioDSPManager = class
  private
    FInitialized: Boolean;
    FMasterStream: HSTREAM;          // Handle stream audio utama (suara pasien/mesin)
    FFFTData: array[0..1023] of Single; // Buffer pra-alokasi untuk FFT2048 (1024 bins)

    function InitBASS: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    // Manajemen Playback
    function LoadTargetSignal(const FilePath: String): Boolean;
    procedure Play;
    procedure Stop;

    // Digital Signal Processing (DSP)
    // Mengambil data spektrum FFT secara real-time. Result berupa pointer ke array internal
    // untuk efisiensi maksimal (tidak ada copy memori).
    function GetSpectrumData: PSingle;

    // Modulasi Sinyal: Digunakan saat mekanik Dekonvolusi / Isolasi Frekuensi
    procedure SetSignalFrequency(TargetFreq: Single);
    procedure SetVolume(VolumeLevel: Single); // 0.0 - 1.0

    property IsInitialized: Boolean read FInitialized;
  end;

implementation

{===============================================================================
  Inisialisasi Manager dan Engine BASS Audio
===============================================================================}
constructor TAudioDSPManager.Create;
begin
  FInitialized := InitBASS;
  FMasterStream := 0;
  // Nol-kan buffer FFT di awal
  FillChar(FFFTData, SizeOf(FFFTData), 0);
end;

destructor TAudioDSPManager.Destroy;
begin
  if FMasterStream <> 0 then
    BASS_StreamFree(FMasterStream);

  if FInitialized then
    BASS_Free; // Bebaskan resource hardware audio

  inherited Destroy;
end;

{===============================================================================
  Koneksi Hardware menggunakan BASS_Init
  Menggunakan -1 untuk Default Audio Device, 44100Hz Sample Rate.
===============================================================================}
function TAudioDSPManager.InitBASS: Boolean;
begin
  // PERBAIKAN: Mengganti argumen ke-4 (Window Handle) dari nil menjadi 0
  // BASS_Init(Device, SampleRate, Flags, Window, CLSID)
  Result := BASS_Init(-1, 44100, 0, 0, nil);
  if not Result then
    WriteLn('DSP ERROR: BASS Engine gagal diinisialisasi. Error Code: ', BASS_ErrorGetCode);
end;

{===============================================================================
  Memuat File Audio (Sinyal/EEG mentah yang akan dianalisis)
===============================================================================}
function TAudioDSPManager.LoadTargetSignal(const FilePath: String): Boolean;
begin
  Result := False;
  if not FInitialized then Exit;

  // Bebaskan stream sebelumnya jika ada pasien baru
  if FMasterStream <> 0 then
    BASS_StreamFree(FMasterStream);

  // PERBAIKAN: Menambahkan flag BASS_SAMPLE_LOOP agar audio berulang otomatis
  FMasterStream := BASS_StreamCreateFile(False, PChar(FilePath), 0, 0,
    BASS_SAMPLE_FLOAT or BASS_STREAM_PRESCAN or BASS_SAMPLE_LOOP);

  Result := (FMasterStream <> 0);
end;

{===============================================================================
  Kontrol Playback Standar
===============================================================================}
procedure TAudioDSPManager.Play;
begin
  if FMasterStream <> 0 then
    BASS_ChannelPlay(FMasterStream, False);
end;

procedure TAudioDSPManager.Stop;
begin
  if FMasterStream <> 0 then
    BASS_ChannelStop(FMasterStream);
end;

{===============================================================================
  Kalkulasi FFT (Fast Fourier Transform) Real-Time
  PENTING: Mengembalikan Pointer (PSingle) ke array internal untuk kecepatan
  render 60 FPS pada UI (TAChart / BGRABitmap).
===============================================================================}
function TAudioDSPManager.GetSpectrumData: PSingle;
begin
  // BASS_DATA_FFT2048 menghasilkan 1024 bins data float (ukuran 4096 bytes)
  if FMasterStream <> 0 then
    BASS_ChannelGetData(FMasterStream, @FFFTData, BASS_DATA_FFT2048);

  Result := @FFFTData[0];
end;

{===============================================================================
  Modulasi Hardware/Sinyal
  Mengubah frekuensi pemutaran. Dalam konteks game, digunakan ketika pemain
  menggeser slider frekuensi di Control Board untuk mencari anomali virus.
===============================================================================}
procedure TAudioDSPManager.SetSignalFrequency(TargetFreq: Single);
begin
  if FMasterStream <> 0 then
    BASS_ChannelSetAttribute(FMasterStream, BASS_ATTRIB_FREQ, TargetFreq);
end;

procedure TAudioDSPManager.SetVolume(VolumeLevel: Single);
begin
  if FMasterStream <> 0 then
  begin
    // Clamp nilai dari 0.0 (Bisu) hingga 1.0 (Maksimal)
    VolumeLevel := Max(0.0, Min(1.0, VolumeLevel));
    BASS_ChannelSetAttribute(FMasterStream, BASS_ATTRIB_VOL, VolumeLevel);
  end;
end;

end.
