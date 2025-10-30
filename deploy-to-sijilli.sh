#!/bin/bash

# سكريبت نشر تطبيق سجلي إلى sijilli.com
# Sijilli Deployment Script

echo "🚀 بدء عملية نشر تطبيق سجلي..."

# 1. بناء التطبيق
echo "📦 بناء التطبيق للويب..."
flutter build web --release

if [ $? -ne 0 ]; then
    echo "❌ فشل في بناء التطبيق"
    exit 1
fi

echo "✅ تم بناء التطبيق بنجاح"

# 2. إنشاء أرشيف
echo "📁 إنشاء أرشيف التحديث..."
cd build/web
zip -r ../../sijilli-web-latest.zip .
cd ../..

echo "✅ تم إنشاء الأرشيف: sijilli-web-latest.zip"

# 3. رفع إلى GitHub
echo "📤 رفع التحديثات إلى GitHub..."
git add .
git commit -m "تحديث تطبيق سجلي - $(date '+%Y-%m-%d %H:%M:%S')"
git push

echo "✅ تم رفع التحديثات إلى GitHub"

# 4. تعليمات النشر اليدوي
echo ""
echo "🌐 لتحديث موقع sijilli.com:"
echo "1. تحميل ملف: sijilli-web-latest.zip"
echo "2. دخول cPanel لموقع sijilli.com"
echo "3. رفع الملف إلى public_html"
echo "4. فك ضغط الملف"
echo "5. اختبار الموقع"
echo ""
echo "📱 أو استخدام FTP:"
echo "scp sijilli-web-latest.zip user@sijilli.com:/path/to/web/"
echo ""
echo "🎉 انتهت عملية التحديث!"
