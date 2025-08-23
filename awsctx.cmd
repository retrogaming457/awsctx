:: Script: awsctx.cmd
:: Purpose: AWS/S3 context switcher for Windows
:: Author: Hamed Davodi
:: Date: 2025-08-21

@echo off
setlocal EnableDelayedExpansion

REM Detect shell (cmd or powershell)
call :GETPARENT CALLER
endlocal & (
    set "CALLER=%CALLER%"
)

if /I "%CALLER%"=="powershell" (
    set "IS_POWERSHELL=1"
) else if /I "%CALLER%"=="pwsh" (
    set "IS_POWERSHELL=1"
) else (
    set "IS_POWERSHELL=0"
)

goto :AFTER_SHELL_DETECTION

:GETPARENT
setlocal
set "PSCMD=$ppid=$pid;while($i++ -lt 3 -and ($ppid=(Get-CimInstance Win32_Process -Filter ('ProcessID='+$ppid)).ParentProcessId)) {}; (Get-Process -Id $ppid -ErrorAction SilentlyContinue).Name"
for /f "tokens=*" %%i in ('powershell -noprofile -command "%PSCMD%"') do set "PARENT=%%i"
endlocal & set "%~1=%PARENT%"
goto :EOF






:AFTER_SHELL_DETECTION
setlocal EnableDelayedExpansion

REM Define escape character as variable
for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"

REM Define color and style variables 
set "BOLD=%ESC%[1m"
set "RESET=%ESC%[0m"
set "GREEN=%ESC%[32m"
set "RED=%ESC%[31m"
set "YELLOW=%ESC%[33m"
set "CYAN=%ESC%[36m"
set "GRAY=%ESC%[90m"
set "WHITE=%ESC%[37m"
set "BRIGHT_BLUE=%ESC%[94m"
set "BRIGHT_WHITE=%ESC%[97m"

set "ARROW=-^>"
set "ICON_OK=%GREEN%%BOLD%[OK]%RESET%"
set "ICON_GO=%RED%%BOLD%[GO]%RESET%"


REM Set path variables of necessary files
set "BIN_DIR=C:\Library\awsctx"
set "AWS_DIR=%USERPROFILE%\.aws"
set "CONF_FILE=%AWS_DIR%\config"
set "CRED_FILE=%AWS_DIR%\credentials"
set "CERT_FILE=%AWS_DIR%\zs-storage-ca.pem"
set "S3CMD_INI=%USERPROFILE%\AppData\Roaming\s3cmd.ini"

REM Prompt user to choose a profile using fzf (fuzzy-finder)
for /f "delims=" %%A in ('findstr /R "^\[.*\]$" "%CRED_FILE%" ^| fzf') do (
    REM Strip brackets of profile name 
	set "line=%%A"
    set "line=!line:~1!"
    set "line=!line:~0,-1!"
    set "PROFILE=!line!"
)

REM Validate profile selection
if not defined PROFILE (
 	echo %CYAN%[awsctx]%RESET% %GRAY%No profile selected.%RESET%
    exit /b 1
)

REM Extract endpoint_url and region using aws cli
set "EP=%TEMP%\endpoint.tmp"
set "RG=%TEMP%\region.tmp"

aws configure get endpoint_url --profile %PROFILE% > "%EP%" 2>nul
aws configure get region --profile %PROFILE% > "%RG%" 2>nul

set /p "ENDPOINT_URL="<"%EP%" || set "ENDPOINT_URL="
set /p "REGION="<"%RG%" || set "REGION="

REM Validate endpoint_url and region, if true, go to extract_credentials
if defined ENDPOINT_URL if defined REGION (
    goto :extract_credentials
)

REM Fallback: manually parse config file if it has a service-specific format and values of
REM endpoint_url & region are nested under `s3 =` which is not visible to `aws configure get`
set "CONFIG_SECTION=[services %PROFILE%]"
set "REGION="
set "FOUND_SECTION=0"
set "IN_S3_BLOCK=0"

for /f "usebackq tokens=* delims=" %%L in ("%CONF_FILE%") do (
    set "LINE=%%L"
    set "TRIMMED_LINE=%%L"
    set "TRIMMED_LINE=!TRIMMED_LINE: =!"

    REM Detect the target section header exactly
    if "!LINE!"=="%CONFIG_SECTION%" if !FOUND_SECTION! == 0 (
        set "FOUND_SECTION=1"
        set "IN_S3_BLOCK=0"
    )

    REM If inside target section, look for s3 =
    if !FOUND_SECTION! == 1 if !IN_S3_BLOCK! == 0 (
        echo !TRIMMED_LINE! | findstr /C:"s3=" >nul
        if !errorlevel! == 0 (
            set "IN_S3_BLOCK=1"
        )
    )

    REM If inside s3 block, extract endpoint_url or region
    if !FOUND_SECTION! == 1 if !IN_S3_BLOCK! == 1 (
        REM Check for endpoint_url line
        echo !TRIMMED_LINE! | findstr /C:"endpoint_url=" >nul
        if !errorlevel! == 0 (
            for /f "tokens=2 delims==" %%E in ("!TRIMMED_LINE!") do (
                set "ENDPOINT_URL=%%~E"
            )
        )

        REM Check for region line
        echo !TRIMMED_LINE! | findstr /C:"region=" >nul
        if !errorlevel! == 0 (
            for /f "tokens=2 delims==" %%R in ("!TRIMMED_LINE!") do (
                set "REGION=%%~R"
            )
        )

        REM If both found, exit loop early
        if defined ENDPOINT_URL if defined REGION (
            goto :validate_values
        )
    )
	
)

:validate_values
if not defined ENDPOINT_URL (
    echo %CYAN%[awsctx]%RESET% %GRAY%ERROR: endpoint_url not found.%RESET%
    exit /b 2
)

if not defined REGION (
    echo %CYAN%[awsctx]%RESET% %GRAY%ERROR: region not found.%RESET%
    exit /b 5
)




:extract_credentials

set "AK=%TEMP%\access.tmp"
set "SK=%TEMP%\secret.tmp"

REM Extract credentials using aws cli
aws configure get aws_access_key_id --profile %PROFILE% > "%AK%" 2>nul
aws configure get aws_secret_access_key --profile %PROFILE% > "%SK%" 2>nul

set /p "ACCESS_KEY="<"%AK%" || set "ACCESS_KEY="
set /p "SECRET_KEY="<"%SK%" || set "SECRET_KEY="

del "%EP%" "%RG%" "%AK%" "%SK%" >nul 2>&1

REM Validate aws_access_key_id 
if not defined ACCESS_KEY (
    echo %CYAN%[awsctx]%RESET% %GRAY%ERROR: aws_access_key_id not found.%RESET%
    exit /b 3
)

REM Validate aws_secret_access_key
if not defined SECRET_KEY (
    echo %CYAN%[awsctx]%RESET% %GRAY%ERROR: aws_secret_access_key not found.%RESET%
    exit /b 4
)


REM Strip protocol for HOST_BASE, add underline to HOST_BUCKET
set "HOST_BASE=%ENDPOINT_URL:https://=%"
set "HOST_BASE=%HOST_BASE:http://=%"
set "HOST_BUCKET=%HOST_BASE%_"


REM Build s3cmd.ini for s3cmd & s4cmd
(
    echo [default]
    echo host_base = %HOST_BASE%
    echo host_bucket = %HOST_BUCKET%
    echo access_key = %ACCESS_KEY%
    echo secret_key = %SECRET_KEY%
    echo use_https = True
    echo check_ssl_certificate = True
    echo preserve = False
    echo progress_meter = False
	
REM CERT_CASE: append certificate conditionally (subject to change depending on your envirnoment)
	if "%PROFILE%"=="dbaas-production" (
        echo ca_certs_file = %CERT_FILE%
	) 
	
) > "%S3CMD_INI%"


REM Build powershell init script for aws & s5cmd
if "%IS_POWERSHELL%" == "1" (
   call :build_ps_init
)

REM Print summary and prompt user to source init script if running on powershell (copy source command to clipboard)
	if "%IS_POWERSHELL%" == "1" (
		
		echo %CYAN%[awsctx]%RESET% %BOLD% aws  / s5cmd%RESET% %ARROW% %GREEN%%BOLD%%PROFILE%%RESET% %GRAY%profile%RESET% %ICON_OK% 
        echo %CYAN%[awsctx]%RESET% %BOLD%s4cmd / s3cmd%RESET% %ARROW% %GREEN%%BOLD%%PROFILE%%RESET% %GRAY%profile%RESET% %ICON_OK% %GRAY%Updated%RESET% %ARROW% %YELLOW%%S3CMD_INI%%RESET% %ICON_OK%
		echo %CYAN%[awsctx]%RESET% %GRAY%Export variables by running:%RESET%
		echo . "%PS_INIT%" | clip
		echo.
		echo    %BRIGHT_BLUE%~%RESET%$%BRIGHT_WHITE% .%RESET%%YELLOW%%BOLD% "%PS_INIT%" %RESET%     %GRAY%[Copied to Clipboard]%RESET%
		echo.
		
	) else (

        echo %CYAN%[awsctx]%RESET% %BOLD% aws  / s5cmd%RESET% %ARROW% %GREEN%%BOLD%%PROFILE%%RESET% %GRAY%profile%RESET% %ICON_OK% 
        echo %CYAN%[awsctx]%RESET% %BOLD%s4cmd / s3cmd%RESET% %ARROW% %GREEN%%BOLD%%PROFILE%%RESET% %GRAY%profile%RESET% %ICON_OK% %GRAY%Updated%RESET% %ARROW% %YELLOW%%S3CMD_INI%%RESET% %ICON_OK%
	      
	)

	
REM endlocal and export variables if running on command-prompt 
endlocal & (

	set "IS_POWERSHELL=%IS_POWERSHELL%"
	if "%IS_POWERSHELL%" == "0" (
	
		echo ^+---------------------------^+
		echo ^|     Exported Variables    ^|
		echo ^+---------------------------^+
		set "AWS_PROFILE=%PROFILE%"
		set "AWS_REGION=%REGION%"
		set "AWS_ENDPOINT_URL=%ENDPOINT_URL%"
		set "S3_ENDPOINT_URL=%ENDPOINT_URL%"
      
REM HOME variable is only used by s4cmd. Comment-out if you're not using s4cmd.      
        set "HOME=%USERPROFILE%"

		echo %WHITE%%BOLD%AWS_PROFILE=%RESET%%GREEN%%BOLD%%PROFILE%%RESET%
		echo %WHITE%%BOLD%AWS_REGION=%RESET%%GREEN%%BOLD%%REGION%%RESET%
		
REM CERT_CASE: append certificate conditionally (subject to change depending on your envirnoment)
		if "%PROFILE%"=="dbaas-production" (
		  set AWS_CA_BUNDLE=%CERT_FILE%
		  echo %WHITE%%BOLD%AWS_CA_BUNDLE=%RESET%%GREEN%%BOLD%%CERT_FILE%%RESET%
		) else (
          set "AWS_CA_BUNDLE="
        )

		
		echo %WHITE%%BOLD%AWS_ENDPOINT_URL=%RESET%%GREEN%%BOLD%%ENDPOINT_URL%%RESET%
		echo %WHITE%%BOLD%S3_ENDPOINT_URL=%RESET%%GREEN%%BOLD%%ENDPOINT_URL%%RESET%

	
	)
    set "IS_POWERSHELL="
    
)

goto :eof





:build_ps_init

set "PS_INIT=%BIN_DIR%\ps-init.ps1"
set "INJECT_PS=%PS_INIT%"

> "%INJECT_PS%" ( 
REM Clear or write header 
)

>> "%INJECT_PS%" echo Write-Host "+---------------------------+"
>> "%INJECT_PS%" echo Write-Host "|     Exported Variables    |"
>> "%INJECT_PS%" echo Write-Host "+---------------------------+"
>> "%INJECT_PS%" echo [System.Environment]::SetEnvironmentVariable('AWS_PROFILE', '!PROFILE!', [System.EnvironmentVariableTarget]::Process)
>> "%INJECT_PS%" echo [System.Environment]::SetEnvironmentVariable('AWS_REGION', '!REGION!', [System.EnvironmentVariableTarget]::Process)
>> "%INJECT_PS%" echo [System.Environment]::SetEnvironmentVariable('AWS_ENDPOINT_URL', '!ENDPOINT_URL!', [System.EnvironmentVariableTarget]::Process)
>> "%INJECT_PS%" echo [System.Environment]::SetEnvironmentVariable('S3_ENDPOINT_URL', '!ENDPOINT_URL!', [System.EnvironmentVariableTarget]::Process)

REM HOME variable is only used by s4cmd. Comment-out if you're not using s4cmd    
>> "%INJECT_PS%" echo [System.Environment]::SetEnvironmentVariable('HOME', '!USERPROFILE!', [System.EnvironmentVariableTarget]::Process)

>> "%INJECT_PS%" echo Write-Host -ForegroundColor White "AWS_PROFILE=" -NoNewline; Write-Host -ForegroundColor Green "$env:AWS_PROFILE"
>> "%INJECT_PS%" echo Write-Host -ForegroundColor White "AWS_REGION=" -NoNewline; Write-Host -ForegroundColor Green "$env:AWS_REGION"

REM CERT_CASE: append certificate conditionally (subject to change depending on your envirnoment)
>> "%INJECT_PS%" echo if ($env:AWS_PROFILE -ieq 'dbaas-production') {
>> "%INJECT_PS%" echo     [System.Environment]::SetEnvironmentVariable('AWS_CA_BUNDLE', '!CERT_FILE!', [System.EnvironmentVariableTarget]::Process)
>> "%INJECT_PS%" echo     Write-Host -ForegroundColor White "AWS_CA_BUNDLE=" -NoNewline; Write-Host -ForegroundColor Green "$env:AWS_CA_BUNDLE"
>> "%INJECT_PS%" echo } else {
>> "%INJECT_PS%" echo     [System.Environment]::SetEnvironmentVariable('AWS_CA_BUNDLE', '', [System.EnvironmentVariableTarget]::Process)
>> "%INJECT_PS%" echo }

>> "%INJECT_PS%" echo Write-Host -ForegroundColor White "AWS_ENDPOINT_URL=" -NoNewline; Write-Host -ForegroundColor Green "$env:AWS_ENDPOINT_URL"
>> "%INJECT_PS%" echo Write-Host -ForegroundColor White "S3_ENDPOINT_URL=" -NoNewline; Write-Host -ForegroundColor Green "$env:S3_ENDPOINT_URL"

goto :eof



REM exit /b 0   :: Success
exit /b 1   :: No profile selected
exit /b 2   :: endpoint_url not found
exit /b 3   :: aws_access_key_id not found
exit /b 4   :: aws_secret_access_key not found
exit /b 5   :: region not found