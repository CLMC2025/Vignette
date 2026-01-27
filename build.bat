@echo off

:: Set environment variables temporarily
set DEVECO_SDK_HOME=D:\Program Files\Huawei\DevEco Studio\sdk\default
set PATH=%PATH%;D:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin;D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin

:: Stop any running daemon
"D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --stop-daemon

:: Run build command
echo Running build...
"D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" build

echo Build completed with exit code %ERRORLEVEL%
pause