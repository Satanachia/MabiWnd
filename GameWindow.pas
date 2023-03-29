unit GameWindow;

interface

uses SysUtils, StrUtils, Classes, Windows, Winapi.MultiMon, System.IniFiles, Vcl.Dialogs, Variants;

 type
   GameWin = Class
     private

     public
       MabiHWND : hWnd;
       GameWindowName : String;
     published

      constructor Create; // Called when creating an instance (object) from this class
      function CheckWnd: String;
      function ResizeWindow(CurrentHWnd: HWND): Boolean;
      function EnableMxButton(CurrentHWnd: HWND; Enable: Boolean): Boolean;
      function HideMinMaxButtons(CurrentHWnd: HWND): Boolean;
      function MakeFullscreenBorderless(CurrentHWnd: HWND): Boolean;
      function WindowMode(MabiHWND: HWND; const Value: string): Boolean;

   end;

procedure SwitchToThisWindow(hWnd: Thandle; fAltTab: boolean); stdcall; external 'User32.dll';

const
  LOG_FILENAME    = 'MabiWnd.log';
  CONFIG_FILENAME = 'MabiWnd.cfg';
  DEBUG = FALSE;

var
  Locale          : TFormatSettings;
  CfgFile         : TIniFile;
  ThreadHandle    : THandle;
  dwThreadID      : Cardinal = 0;
  Wnd             : hWND;
  Config          : String;

implementation

uses Tools;

Procedure WriteLog(Data : string; Enabled: Boolean);
var
  LogFile : TextFile;
  formattedDateTime : string;
  LOG : String;
begin
  IF ENABLED = TRUE THEN
  Begin
    LOG := ExtractFilePath(Tools.GetModuleName)+LOG_FILENAME;
    AssignFile(LogFile, LOG) ;

    IF FileExists(LOG) <> TRUE THEN
      Rewrite(LogFile)
    ELSE
      Append(LogFile);
      GetLocaleFormatSettings(LOCALE_SYSTEM_DEFAULT, Locale);
      DateTimeToString(formattedDateTime, Locale.ShortDateFormat+' hh:nnampm', now);
      WriteLn(LogFile, '['+formattedDateTime+'] '+DATA);
      CloseFile(LogFile) ;
  end;
end;

// Reads Config value based on Type
{
  Str  := ReadCFG('myconfig.ini', 'Section1', 'Key1', 'DefaultString');
  Int  := ReadCFG('myconfig.ini', 'Section2', 'Key2', 123);
  Bool := ReadCFG('myconfig.ini', 'Section3', 'Key3', True);
}
function ReadCFG(const FileName: string; const Section, Key: string; const DefaultValue: Variant): Variant;
var
  IniFile: TIniFile;
begin
  IniFile := TIniFile.Create(FileName);
  try
    case VarType(DefaultValue) of
      varInteger:
        Result := IniFile.ReadInteger(Section, Key, DefaultValue);
      varBoolean:
        Result := IniFile.ReadBool(Section, Key, DefaultValue);
    else
      Result := IniFile.ReadString(Section, Key, DefaultValue);
    end;
  finally
    IniFile.Free;
  end;
end;

 // Constructor : Create an instance of the class. Takes a string as argument.
 // -----------------------------------------------------------------------------
constructor GameWin.Create;
begin
    //Holder Space
end;

function GameWin.CheckWnd: String;
var
  FromClass: PChar;
begin

  GetMem(FromClass, 100);
  GetClassName(GetForeGroundWindow, PChar(FromClass), 800);
  WriteLog('Wnd Class: '+StrPas(FromClass), DEBUG);

  result := StrPas(FromClass);
  FreeMem(FromClass);

end;

function GameWin.ResizeWindow(CurrentHWnd: HWND): Boolean;
var
  DesktopRect, WindowRect: TRect;
begin
  Result := False;
  // Get the coordinates of the desktop area excluding the taskbar
  if SystemParametersInfo(SPI_GETWORKAREA, 0, @DesktopRect, 0) then
  begin
    // Get the current size and position of the window
    if GetWindowRect(CurrentHWnd, WindowRect) then
    begin
      // Calculate the new size and position of the window
      WindowRect.Right := WindowRect.Left + (DesktopRect.Right - DesktopRect.Left);
      WindowRect.Bottom := WindowRect.Top + (DesktopRect.Bottom - DesktopRect.Top);
      // Set the size and position of the window
      if SetWindowPos(CurrentHWnd, 0, WindowRect.Left, WindowRect.Top,
        WindowRect.Right - WindowRect.Left, WindowRect.Bottom - WindowRect.Top,
        SWP_NOZORDER or SWP_NOACTIVATE) then
        Result := True;
    end;
  end;
end;

function GameWin.EnableMxButton(CurrentHWnd: HWND; Enable: Boolean): Boolean;
const
  WS_MAXIMIZEBOX = $00010000;
var
  WindowStyle: NativeInt;
begin
  Result := False;
  // Get the current window style
  WindowStyle := GetWindowLongPtr(CurrentHWnd, GWL_STYLE);
  if WindowStyle = 0 then
    Exit;
  // Enable or disable the maximize button by adding or removing the WS_MAXIMIZEBOX style flag
  if Enable then
    WindowStyle := WindowStyle or WS_MAXIMIZEBOX
  else
    WindowStyle := WindowStyle and not WS_MAXIMIZEBOX;
  // Set the new window style
  if SetWindowLongPtr(CurrentHWnd, GWL_STYLE, WindowStyle) <> 0 then
    Result := True;
end;

function GameWin.HideMinMaxButtons(CurrentHWnd: HWND): Boolean;
const
  WS_MINIMIZEBOX = $00020000;
  WS_MAXIMIZEBOX = $00010000;
var
  Style: DWORD;
begin
  // Get the current window style
  Style := GetWindowLong(CurrentHWnd, GWL_STYLE);
  if Style = 0 then
  begin
    Result := False;
    Exit;
  end;
  // Remove the minimize and maximize buttons from the style
  Style := Style and not WS_MINIMIZEBOX;
  Style := Style and not WS_MAXIMIZEBOX;
  // Set the new window style
  Result := SetWindowLong(CurrentHWnd, GWL_STYLE, Style) <> 0;
end;

function GameWin.MakeFullscreenBorderless(CurrentHWnd: HWND): Boolean;
const
  WS_POPUP = $80000000;
  WS_VISIBLE = $10000000;
  WS_SYSMENU = $00080000;
  WS_THICKFRAME = $00040000;
  WS_CAPTION = WS_BORDER or WS_DLGFRAME or WS_THICKFRAME;
  SWP_FRAMECHANGED = $0020;
var
  Style, ExStyle: NativeInt;
  Monitor: HMONITOR;
  MonitorInfo: TMonitorInfo;
  Left, Top, Width, Height: Integer;
begin
  // Get the current monitor
  Monitor := MonitorFromWindow(CurrentHWnd, MONITOR_DEFAULTTONEAREST);
  MonitorInfo.cbSize := SizeOf(MonitorInfo);
  GetMonitorInfo(Monitor, @MonitorInfo);
  // Set the new window style
  Style := GetWindowLongPtr(CurrentHWnd, GWL_STYLE);
  ExStyle := GetWindowLongPtr(CurrentHWnd, GWL_EXSTYLE);
  SetWindowLongPtr(CurrentHWnd, GWL_STYLE, WS_POPUP or WS_VISIBLE);
  SetWindowLongPtr(CurrentHWnd, GWL_EXSTYLE, WS_EX_APPWINDOW or WS_EX_WINDOWEDGE);
  // Set the new window position and size
  Left := MonitorInfo.rcMonitor.Left;
  Top := MonitorInfo.rcMonitor.Top;
  Width := MonitorInfo.rcMonitor.Right - MonitorInfo.rcMonitor.Left;
  Height := MonitorInfo.rcMonitor.Bottom - MonitorInfo.rcMonitor.Top;
  SetWindowPos(CurrentHWnd, HWND_TOPMOST, Left, Top, Width, Height, SWP_FRAMECHANGED);
  // Update the window
  UpdateWindow(CurrentHWnd);
  Result := True;
end;

function GameWin.WindowMode(MabiHWND: HWND; const Value: string): Boolean;
begin
  case AnsiIndexText(Value, ['EnableMxBTN', 'AutoMx', 'BorderlessFS']) of
    0: begin
          SwitchToThisWindow(MabiHWND, True);
          EnableMxButton(MabiHWND, True);
          WriteLog('Window Mode set to: EnableMxBTN', TRUE);
          WriteLog('Enabled maximize button', TRUE);
          result := TRUE;
       end;
    1: begin
          SwitchToThisWindow(MabiHWND, True);
          EnableMxButton(MabiHWND, True);
          ShowWindow(MabiHWND, SW_MAXIMIZE);
          WriteLog('Window Mode set to: AutoMx', TRUE);
          WriteLog('Enabled maximize button and Maximized window!', TRUE);
          result := TRUE;
       end;
    2: begin
          SwitchToThisWindow(MabiHWND, True);
          MakeFullscreenBorderless(MabiHWND);
          WriteLog('Window Mode set to: BorderlessFS', TRUE);
          WriteLog('Window maximized to Full Screen Boarderless!', TRUE);
          result := TRUE;
       end;
    else
    begin
      WriteLog('Window Mode invalid, check cfg!', TRUE);
      WriteLog('Ending thread...', TRUE);
      EndThread(0);
      result := FALSE;
    end;
  end;
end;

//==========================================================================================================================

procedure FindWHND;
var
  WinModeEx : Boolean;
  MabiWnd: GameWin;
begin

  WriteLog('Find window thread created...', TRUE);
  WinModeEx := FALSE;

  Try
    MabiWnd := GameWin.Create;
  Except
    on E : Exception do
      WriteLog(E.ClassName+' error raised, with message : '+E.Message, TRUE);
  End;

  try
    Repeat
      if MabiWnd.CheckWnd = 'Mabinogi' then
      begin
        WriteLog('Mabinogi window found, changing window mode...', TRUE);
        WinModeEx := MabiWnd.WindowMode(GetForeGroundWindow,ReadCFGs('MabiWindow','Mode'));
      end;
    until WinModeEx = TRUE;
  Except
    on E : Exception do
      WriteLog(E.ClassName+' error raised, with message : '+E.Message, TRUE);
  End;

    WriteLog('Ending thread...', TRUE);
    EndThread(0);

end;

// ========================================================================================================================
// All code below is excuted when this module is loaded according to compile order
initialization

  Config := ExtractFilePath(Tools.GetModuleName)+CONFIG_FILENAME;

  if ReadCFG(Config,'MabiWindow','Enabled', FALSE) then
  begin
    DeleteFile(PWideChar(ExtractFilePath(Tools.GetModuleName)+LOG_FILENAME));
    ThreadHandle := CreateThread(nil, 0, @FindWHND, nil, 0, dwThreadID);
  end;


// ========================================================================================================================
// All code below is excuted when this module is unloaded according to compile order
finalization

  EndThread(ThreadHandle);

end.

