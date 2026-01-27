@echo off

:: 设置正确的环境变量
set DEVECO_SDK_HOME=C:/Users/Developer/HarmonyOS/SDK
set PATH=%PATH%;C:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin;C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin

:: 停止任何运行的守护进程
echo Stopping hvigor daemon...
"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --stop-daemon

:: 运行构建命令
echo Running build...
"C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" build

echo Build completed with exit code %ERRORLEVEL%
pause