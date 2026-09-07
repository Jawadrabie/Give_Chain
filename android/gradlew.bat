@echo off
setlocal
set GRADLE_VERSION=8.11.1
set CACHE_ROOT=%USERPROFILE%\.gradle\wrapper\dists\givechain-gradle-%GRADLE_VERSION%
set GRADLE_HOME=%CACHE_ROOT%\gradle-%GRADLE_VERSION%
set ZIP_FILE=%CACHE_ROOT%\gradle-%GRADLE_VERSION%-bin.zip
set URL=https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip

if exist "%GRADLE_HOME%\bin\gradle.bat" goto run
if not exist "%CACHE_ROOT%" mkdir "%CACHE_ROOT%"
if not exist "%ZIP_FILE%" (
  echo Downloading Gradle %GRADLE_VERSION%...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing '%URL%' -OutFile '%ZIP_FILE%'"
  if errorlevel 1 exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%CACHE_ROOT%' -Force"
if errorlevel 1 exit /b 1

:run
pushd "%~dp0"
call "%GRADLE_HOME%\bin\gradle.bat" %*
set EXIT_CODE=%ERRORLEVEL%
popd
exit /b %EXIT_CODE%
