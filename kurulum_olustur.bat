@echo off
chcp 65001 >nul
setlocal
REM ============================================================
REM  SaLda - kurulum exesi olusturucu
REM  1) Godot export sablonlarini kontrol eder (yoksa indirir)
REM  2) Oyunu build\oyun\SaLda.exe olarak disa aktarir
REM  3) Inno Setup ile build\SaLda_Kurulum_x.exe uretir
REM ============================================================
cd /d "%~dp0"

set "GODOT_VER=4.7.2"
set "GODOT=%LOCALAPPDATA%\Programs\Godot\Godot_v%GODOT_VER%-stable_win64_console.exe"
set "TPL_DIR=%APPDATA%\Godot\export_templates\%GODOT_VER%.stable"
set "TPL_URL=https://github.com/godotengine/godot/releases/download/%GODOT_VER%-stable/Godot_v%GODOT_VER%-stable_export_templates.tpz"

if not exist "%GODOT%" (
  echo [HATA] Godot bulunamadi: %GODOT%
  goto :hata
)

REM --- Inno Setup derleyicisi ---
set "ISCC="
for %%P in ("%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" "%ProgramFiles%\Inno Setup 6\ISCC.exe") do (
  if exist %%P set "ISCC=%%~P"
)
if not defined ISCC (
  echo [1/4] Inno Setup kuruluyor...
  winget install --id JRSoftware.InnoSetup -e --silent --accept-package-agreements --accept-source-agreements
  if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
  if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
)
if not defined ISCC (
  echo [HATA] Inno Setup bulunamadi. https://jrsoftware.org/isdl.php adresinden kurun.
  goto :hata
)

REM --- Export sablonlari ---
if exist "%TPL_DIR%\windows_release_x86_64.exe" (
  echo [1/4] Export sablonlari hazir.
) else (
  echo [1/4] Godot %GODOT_VER% export sablonlari indiriliyor ^(yaklasik 1 GB, bir kez^)...
  set "TMPD=%TEMP%\godot_tpl_%RANDOM%"
  call :indir || goto :hata
)

REM --- Disa aktarma ---
echo [2/4] Kaynaklar iceri aktariliyor...
"%GODOT%" --headless --path . --import >nul 2>&1

echo [3/4] Oyun disa aktariliyor...
if not exist "build\oyun" mkdir "build\oyun"
if exist "build\oyun\SaLda.exe" del /q "build\oyun\SaLda.exe"
"%GODOT%" --headless --path . --export-release "Windows Desktop" "build\oyun\SaLda.exe"
if not exist "build\oyun\SaLda.exe" (
  echo [HATA] Disa aktarma basarisiz.
  goto :hata
)

REM --- Kurulum ---
echo [4/4] Kurulum exesi olusturuluyor...
"%ISCC%" /Q kurulum.iss
if errorlevel 1 (
  echo [HATA] Inno Setup derlemesi basarisiz.
  goto :hata
)

echo.
echo ============================================================
echo  TAMAM: build klasorunde SaLda_Kurulum_*.exe hazir.
echo ============================================================
explorer "%~dp0build"
pause
exit /b 0

:indir
mkdir "%TMPD%" 2>nul
curl -L --fail -o "%TMPD%\templates.tpz" "%TPL_URL%" || exit /b 1
tar -xf "%TMPD%\templates.tpz" -C "%TMPD%" || exit /b 1
if not exist "%TPL_DIR%" mkdir "%TPL_DIR%"
xcopy /e /y /q "%TMPD%\templates\*" "%TPL_DIR%\" >nul || exit /b 1
rmdir /s /q "%TMPD%"
exit /b 0

:hata
echo.
echo Islem tamamlanamadi.
pause
exit /b 1
