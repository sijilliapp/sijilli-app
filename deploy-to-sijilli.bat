@echo off
chcp 65001 >nul
echo.
echo 🚀 بدء عملية نشر تطبيق سجلي...
echo.

REM 1. بناء التطبيق
echo 📦 بناء التطبيق للويب...
call flutter build web --release

if %errorlevel% neq 0 (
    echo ❌ فشل في بناء التطبيق
    pause
    exit /b 1
)

echo ✅ تم بناء التطبيق بنجاح
echo.

REM 2. إنشاء أرشيف
echo 📁 إنشاء أرشيف التحديث...
powershell -Command "Compress-Archive -Path 'build\web\*' -DestinationPath 'sijilli-web-latest.zip' -Force"

if %errorlevel% neq 0 (
    echo ❌ فشل في إنشاء الأرشيف
    pause
    exit /b 1
)

echo ✅ تم إنشاء الأرشيف: sijilli-web-latest.zip
echo.

REM 3. رفع إلى GitHub
echo 📤 رفع التحديثات إلى GitHub...
git add .
git commit -m "تحديث تطبيق سجلي - %date% %time%"
git push

echo ✅ تم رفع التحديثات إلى GitHub
echo.

REM 4. تعليمات النشر اليدوي
echo.
echo 🌐 لتحديث موقع sijilli.com:
echo 1. تحميل ملف: sijilli-web-latest.zip
echo 2. دخول cPanel لموقع sijilli.com  
echo 3. رفع الملف إلى public_html
echo 4. فك ضغط الملف
echo 5. اختبار الموقع
echo.
echo 📱 أو استخدام FTP/SFTP:
echo scp sijilli-web-latest.zip user@sijilli.com:/path/to/web/
echo.
echo 🎉 انتهت عملية التحديث!
echo.
pause
