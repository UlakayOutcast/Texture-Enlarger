@echo off
setlocal enabledelayedexpansion
chcp 65001 > nul
:: Paths
set "MAGICK_PATH=%~dp0"
set "INPUT_DIR=%MAGICK_PATH%Image-In"
set "OUTPUT_DIR=%MAGICK_PATH%Image-Out"
set "TEMP_ORIG=%MAGICK_PATH%temp_orig.png"
set "TEMP_RGBA=%MAGICK_PATH%temp_rgba.png"
set "TEMP_ALPHA=%MAGICK_PATH%temp_alpha.png"
set "TEMP_MASK=%MAGICK_PATH%temp_mask.png"
set "TEMP_RGBA_FINAL=%MAGICK_PATH%TEMP_RGBA_FINAL.png"
:: Check magick.exe
if not exist "%MAGICK_PATH%magick.exe" (
	echo Error: magick.exe not found.
	pause
	exit /b 1
)
:: Check ScalerTest_Windows.exe
if not exist "%MAGICK_PATH%ScalerTest_Windows.exe" (
	echo Error: ScalerTest_Windows.exe not found.
	pause
	exit /b 1
)
:: Prompt for scale
:input_scale
set /p "SCALE=Enter scale (2, 3, or 4): "
if "%SCALE%" neq "2" if "%SCALE%" neq "3" if "%SCALE%" neq "4" (
	echo Invalid input. Enter 2, 3, or 4.
	goto input_scale
)
:: Prompt for transparency threshold
:input_threshold
set /p "threshold=Enter transparency threshold (0-100): "
if "%threshold%"=="" (
    set threshold=25
	echo The threshold is set at 25.
)
if %threshold% lss 0 (
	echo Threshold cannot be less than 0.
	goto input_threshold
)
if %threshold% gtr 100 (
	echo Threshold cannot be greater than 100.
	goto input_threshold
)
:: Request for delay between processing
:input_delay
set /p "DELAY=Enter the delay between treatments (in seconds, 1-999, or leave it blank for no delay): "
if "%DELAY%"=="" (
    set DELAY=0
    echo There is no delay.
)
:: Create directories
if not exist "%INPUT_DIR%" mkdir "%INPUT_DIR%"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
:: Count total files
set TOTAL_FILES=0
for /r "%INPUT_DIR%" %%F in (*.png, *.jpg, *.jpeg, *.bmp, *.tga, *.gif) do (
	set /a TOTAL_FILES+=1
)
:: Processing
set FILE_COUNT=0
for /r "%INPUT_DIR%" %%F in (*.png, *.jpg, *.jpeg, *.bmp, *.tga, *.gif) do (
	set /a FILE_COUNT+=1
	set "FULL_PATH=%%F"
	set "RELATIVE_PATH=!FULL_PATH:%INPUT_DIR%\=!"
	:: Calculate completion percentage
	set /a PERCENT_COMPLETE=!FILE_COUNT! * 100 / !TOTAL_FILES!
	echo Processing !FILE_COUNT!/!TOTAL_FILES! ^(!PERCENT_COMPLETE!%%^): !RELATIVE_PATH!
	set "OUTPUT_FILE=%%F"
	set "OUTPUT_FILE=!OUTPUT_FILE:%INPUT_DIR%=%OUTPUT_DIR%!"
	for %%D in ("!OUTPUT_FILE!\..") do if not exist "%%~fD" mkdir "%%~fD"
	:: Copy original image to temporary file
	"%MAGICK_PATH%magick.exe" "%%F" "!TEMP_ORIG!" || (
		echo Error copying source image: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Main processing
	"%MAGICK_PATH%magick.exe" "!TEMP_ORIG!" -compose CopyOpacity "!TEMP_RGBA!" || (
		echo Error creating TEMP_RGBA: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Scale RGBA channel via xbrz
	ScalerTest_Windows.exe -%SCALE%xbrz "!TEMP_RGBA!" "!TEMP_RGBA!" || (
		echo Error scaling RGBA: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Create transparency mask
	"%MAGICK_PATH%magick.exe" "!TEMP_RGBA!" -alpha extract -threshold !threshold!%% "!TEMP_MASK!" || (
		echo Error creating mask: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Apply transparency mask to scaled RGBA
	"%MAGICK_PATH%magick.exe" "!TEMP_RGBA!" "!TEMP_MASK!" -compose CopyOpacity -composite "!TEMP_RGBA!" || (
		echo Error applying mask: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Extract alpha channel from original image
	"%MAGICK_PATH%magick.exe" "!TEMP_ORIG!" -alpha extract -transparent black "!TEMP_ALPHA!" || (
		echo Error extracting alpha channel: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Scale alpha channel via xbrz
	ScalerTest_Windows.exe -%SCALE%xbrz "!TEMP_ALPHA!" "!TEMP_ALPHA!" || (
		echo Error scaling alpha channel: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Create transparency mask with !threshold!% threshold from TEMP_RGBA
	"%MAGICK_PATH%magick.exe" "!TEMP_RGBA!" -alpha extract -threshold !threshold!%% "!TEMP_MASK!" || (
		echo Error creating transparency mask: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Apply mask to TEMP_ALPHA
	"%MAGICK_PATH%magick.exe" "!TEMP_ALPHA!" "!TEMP_MASK!" -compose Multiply -composite "!TEMP_ALPHA!" || (
		echo Error applying mask to alpha channel: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Use corrected TEMP_ALPHA for final compositing
	"%MAGICK_PATH%magick.exe" "!TEMP_RGBA!" "!TEMP_ALPHA!" -alpha off -compose CopyOpacity -composite -alpha on "!TEMP_RGBA_FINAL!" || (
		echo Error in final compositing: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Save final result
	"%MAGICK_PATH%magick.exe" "!TEMP_RGBA_FINAL!" "!OUTPUT_FILE!" || (
		echo Error saving result: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Delay between processing
	if %DELAY% gtr 0 (
		timeout /t %DELAY% >nul
	)
)
:: Delete temporary files after processing
if exist "!TEMP_ORIG!" del "!TEMP_ORIG!" >nul 2>&1
if exist "!TEMP_RGBA!" del "!TEMP_RGBA!" >nul 2>&1
if exist "!TEMP_ALPHA!" del "!TEMP_ALPHA!" >nul 2>&1
if exist "!TEMP_MASK!" del "!TEMP_MASK!" >nul 2>&1
if exist "!TEMP_RGBA_FINAL!" del "!TEMP_RGBA_FINAL!" >nul 2>&1
echo Done. Processed !FILE_COUNT! files.
pause
