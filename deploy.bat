@echo off
echo ==========================================
echo   POS Analytics - Deployment Script
echo ==========================================
echo.

:: Configuration - UPDATE THIS after deploying backend to Render
set API_URL=https://reports-flutter.onrender.com

echo [Step 1/4] Cleaning previous builds...
call flutter clean
if errorlevel 1 goto :error

echo.
echo [Step 2/4] Getting dependencies...
call flutter pub get
if errorlevel 1 goto :error

echo.
echo [Step 3/4] Building Flutter Web (Production)...
call flutter build web --release --dart-define=API_URL=%API_URL%
if errorlevel 1 goto :error

echo.
echo [Step 4/4] Build Complete!
echo ==========================================
echo.
echo Your production build is ready at:
echo   build\web\
echo.
echo ==========================================
echo   DEPLOYMENT OPTIONS
echo ==========================================
echo.
echo Option 1: Netlify (Drag and Drop)
echo   1. Go to https://app.netlify.com/drop
echo   2. Drag the 'build\web' folder
echo   3. Done! You'll get a URL like: https://xxx.netlify.app
echo.
echo Option 2: Vercel
echo   1. Go to https://vercel.com
echo   2. Import project and select build\web folder
echo.
goto :end

:error
echo.
echo ==========================================
echo   BUILD FAILED!
echo ==========================================
exit /b 1

:end
echo Press any key to open the build folder...
pause >nul
start "" "build\web"
