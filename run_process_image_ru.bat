@echo off
setlocal enabledelayedexpansion
chcp 65001 > nul
:: Пути
set "MAGICK_PATH=%~dp0"
set "INPUT_DIR=%MAGICK_PATH%Image-In"
set "OUTPUT_DIR=%MAGICK_PATH%Image-Out"
set "TEMP_ORIG=%MAGICK_PATH%temp_orig.png"
set "TEMP_RGBA=%MAGICK_PATH%temp_rgba.png"
set "TEMP_ALPHA=%MAGICK_PATH%temp_alpha.png"
set "TEMP_MASK=%MAGICK_PATH%temp_mask.png"
set "TEMP_RGBA_FINAL=%MAGICK_PATH%TEMP_RGBA_FINAL.png"
:: Проверка magick.exe
if not exist "%MAGICK_PATH%magick.exe" (
	echo Ошибка: magick.exe не найден.
	pause
	exit /b 1
)
:: Проверка ScalerTest_Windows.exe
if not exist "%MAGICK_PATH%ScalerTest_Windows.exe" (
	echo Ошибка: ScalerTest_Windows.exe не найден.
	pause
	exit /b 1
)
:: Запрос масштаба
:input_scale
set /p "SCALE=Введите масштаб (2, 3 или 4): "
if "%SCALE%" neq "2" if "%SCALE%" neq "3" if "%SCALE%" neq "4" (
	echo Некорректный ввод. Введите 2, 3 или 4.
	goto input_scale
)
:: Запрос порога прозрачности
:input_threshold
set /p "threshold=Введите порог прозрачности (0-100): "
if "%threshold%"=="" (
    set threshold=25
	echo Порог установлен на 25.
)
if %threshold% lss 0 (
	echo Порог не может быть меньше 0.
	goto input_threshold
)
if %threshold% gtr 100 (
	echo Порог не может быть больше 100.
	goto input_threshold
)
:: Запрос задержки между обработками
:input_delay
set /p "DELAY=Введите задержку между обработками (в секундах, 1-999, или оставьте пустым для отсутствия задержки): "
if "%DELAY%"=="" (
    set DELAY=0
    echo Задержка отсутствует.
)
:: Создание папок
if not exist "%INPUT_DIR%" mkdir "%INPUT_DIR%"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
:: Подсчёт общего количества файлов
set TOTAL_FILES=0
for /r "%INPUT_DIR%" %%F in (*.png, *.jpg, *.jpeg, *.bmp, *.tga, *.gif) do (
	set /a TOTAL_FILES+=1
)
:: Обработка
set FILE_COUNT=0
for /r "%INPUT_DIR%" %%F in (*.png, *.jpg, *.jpeg, *.bmp, *.tga, *.gif) do (
	set /a FILE_COUNT+=1
	set "FULL_PATH=%%F"
	set "RELATIVE_PATH=!FULL_PATH:%INPUT_DIR%\=!"
	:: Рассчитываем процент выполнения
	set /a PERCENT_COMPLETE=!FILE_COUNT! * 100 / !TOTAL_FILES!
	echo Обработка !FILE_COUNT!/!TOTAL_FILES! ^(!PERCENT_COMPLETE!%%^): !RELATIVE_PATH!
	set "OUTPUT_FILE=%%F"
	set "OUTPUT_FILE=!OUTPUT_FILE:%INPUT_DIR%=%OUTPUT_DIR%!"
	for %%D in ("!OUTPUT_FILE!\..") do if not exist "%%~fD" mkdir "%%~fD"
	:: Копируем оригинальное изображение во временный файл
	"%MAGICK_PATH%magick.exe" "%%F" "!TEMP_ORIG!" || (
		echo Ошибка при копировании исходного изображения: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Основная обработка
	"%MAGICK_PATH%magick.exe" "!TEMP_ORIG!" -compose CopyOpacity "!TEMP_RGBA!" || (
		echo Ошибка при создании TEMP_RGBA: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Увеличиваем RGBA-канал целиком через xbrz
	ScalerTest_Windows.exe -%SCALE%xbrz "!TEMP_RGBA!" "!TEMP_RGBA!" || (
		echo Ошибка при увеличении RGBA: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Создаем маску для прозрачности
	"%MAGICK_PATH%magick.exe" "!TEMP_RGBA!" -alpha extract -threshold !threshold!%% "!TEMP_MASK!" || (
		echo Ошибка при создании маски: !RELATIVE_PATH!
		pause
		exit /b 1
	)

	:: Применяем маску прозрачности к увеличенному RGBA
	"%MAGICK_PATH%magick.exe" "!TEMP_RGBA!" "!TEMP_MASK!" -compose CopyOpacity -composite "!TEMP_RGBA!" || (
		echo Ошибка при применении маски: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Извлекаем альфа-канал из оригинального изображения
	"%MAGICK_PATH%magick.exe" "!TEMP_ORIG!" -alpha extract -transparent black "!TEMP_ALPHA!" || (
		echo Ошибка при извлечении альфа-канала: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Увеличиваем альфа-канал через xbrz
	ScalerTest_Windows.exe -%SCALE%xbrz "!TEMP_ALPHA!" "!TEMP_ALPHA!" || (
		echo Ошибка при увеличении альфа-канала: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Создаем маску прозрачности с порогом 25% из TEMP_RGBA
	"%MAGICK_PATH%magick.exe" "!TEMP_RGBA!" -alpha extract -threshold !threshold!%% "!TEMP_MASK!" || (
		echo Ошибка при создании маски прозрачности: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Применяем маску к TEMP_ALPHA
	"%MAGICK_PATH%magick.exe" "!TEMP_ALPHA!" "!TEMP_MASK!" -compose Multiply -composite "!TEMP_ALPHA!" || (
		echo Ошибка при применении маски к альфа-каналу: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Используем исправленный TEMP_ALPHA для финального композитинга
	"%MAGICK_PATH%magick.exe" "!TEMP_RGBA!" "!TEMP_ALPHA!" -alpha off -compose CopyOpacity -composite -alpha on "!TEMP_RGBA_FINAL!" || (
		echo Ошибка при финальном композитинге: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Сохраняем финальный результат
	"%MAGICK_PATH%magick.exe" "!TEMP_RGBA_FINAL!" "!OUTPUT_FILE!" || (
		echo Ошибка при сохранении результата: !RELATIVE_PATH!
		pause
		exit /b 1
	)
	:: Задержка между обработками
	if %DELAY% gtr 0 (
		timeout /t %DELAY% >nul
	)
)
:: Удаляем временные файлы в конце обработки всех файлов
if exist "!TEMP_ORIG!" del "!TEMP_ORIG!" >nul 2>&1
if exist "!TEMP_RGBA!" del "!TEMP_RGBA!" >nul 2>&1
if exist "!TEMP_ALPHA!" del "!TEMP_ALPHA!" >nul 2>&1
if exist "!TEMP_MASK!" del "!TEMP_MASK!" >nul 2>&1
if exist "!TEMP_RGBA_FINAL!" del "!TEMP_RGBA_FINAL!" >nul 2>&1

echo Готово. Обработано !FILE_COUNT! файлов.
pause
