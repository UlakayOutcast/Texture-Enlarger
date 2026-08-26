@echo off
setlocal enabledelayedexpansion

:: Папки для ввода и вывода
set "INPUT_DIR=Image-In"
set "OUTPUT_DIR=Image-Out"

:: Запрос масштаба
:input_scale
set /p "SCALE=Введите масштаб (2, 3 или 4): "
if "%SCALE%" neq "2" if "%SCALE%" neq "3" if "%SCALE%" neq "4" (
    echo Некорректный ввод. Введите 2, 3 или 4.
    goto input_scale
)
echo Выбран масштаб %SCALE%x.

:: Проверка и создание папки для результата
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: Обработка всех PNG/JPG/GIF в папке og и её подпапках
for /r "%INPUT_DIR%" %%I in (*.png *.jpg *.jpeg *.gif) do (
    :: Получаем относительный путь файла
    set "RELPATH=%%~dpI"
    set "RELPATH=!RELPATH:%CD%\%INPUT_DIR%\=!"

    :: Создаём соответствующую папку в OUTPUT_DIR
    set "DESTDIR=%OUTPUT_DIR%\!RELPATH!"
    if not exist "!DESTDIR!" mkdir "!DESTDIR!"

    :: Обрабатываем файл с сохранением оригинального имени
    ScalerTest_Windows.exe -%SCALE%xbrz "%%I" "!DESTDIR!%%~nxI"
    echo Обработано: %%~nxI
)

echo Все файлы обработаны.
pause
endlocal
