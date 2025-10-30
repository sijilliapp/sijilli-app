#!/bin/bash

# Vercel Build Script for Flutter Web
echo "🚀 بدء بناء تطبيق سجلي للويب..."

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter غير مثبت"
    exit 1
fi

echo "✅ Flutter مثبت"
flutter --version

# Clean previous builds
echo "🧹 تنظيف البناء السابق..."
flutter clean

# Get dependencies
echo "📦 جلب التبعيات..."
flutter pub get

# Build for web
echo "🌐 بناء التطبيق للويب..."
flutter build web --release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ تم بناء التطبيق بنجاح!"
    echo "📁 ملفات البناء في: build/web"
    ls -la build/web/
else
    echo "❌ فشل في بناء التطبيق"
    exit 1
fi

echo "🎉 انتهى البناء بنجاح!"
