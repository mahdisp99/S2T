#!/bin/bash

echo "🎨 ساخت آیکون جدید..."
echo ""

# بررسی وجود فایل
if [ ! -f "icon_1024x1024.png" ]; then
    echo "❌ فایل icon_1024x1024.png پیدا نشد!"
    echo ""
    echo "📝 لطفاً یک فایل PNG با نام icon_1024x1024.png"
    echo "   در همین فولدر قرار بده (سایز: 1024×1024)"
    exit 1
fi

# بررسی سایز
SIZE=$(sips -g pixelWidth -g pixelHeight icon_1024x1024.png | grep pixel | awk '{print $2}')
if [ "$SIZE" != "1024" ]; then
    echo "⚠️  سایز فایل 1024×1024 نیست!"
    echo "   سایز فعلی: $SIZE"
    echo ""
    read -p "ادامه بدم؟ (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ساخت پوشه موقت
mkdir -p /tmp/AppIcon.iconset

echo "📐 ایجاد سایزهای مختلف..."
sips -z 16 16     icon_1024x1024.png --out /tmp/AppIcon.iconset/icon_16x16.png > /dev/null 2>&1
sips -z 32 32     icon_1024x1024.png --out /tmp/AppIcon.iconset/icon_16x16@2x.png > /dev/null 2>&1
sips -z 32 32     icon_1024x1024.png --out /tmp/AppIcon.iconset/icon_32x32.png > /dev/null 2>&1
sips -z 64 64     icon_1024x1024.png --out /tmp/AppIcon.iconset/icon_32x32@2x.png > /dev/null 2>&1
sips -z 128 128   icon_1024x1024.png --out /tmp/AppIcon.iconset/icon_128x128.png > /dev/null 2>&1
sips -z 256 256   icon_1024x1024.png --out /tmp/AppIcon.iconset/icon_128x128@2x.png > /dev/null 2>&1
sips -z 256 256   icon_1024x1024.png --out /tmp/AppIcon.iconset/icon_256x256.png > /dev/null 2>&1
sips -z 512 512   icon_1024x1024.png --out /tmp/AppIcon.iconset/icon_256x256@2x.png > /dev/null 2>&1
sips -z 512 512   icon_1024x1024.png --out /tmp/AppIcon.iconset/icon_512x512.png > /dev/null 2>&1
sips -z 1024 1024 icon_1024x1024.png --out /tmp/AppIcon.iconset/icon_512x512@2x.png > /dev/null 2>&1

echo "🔨 تبدیل به .icns..."
iconutil -c icns /tmp/AppIcon.iconset -o AppIcon.icns

if [ $? -eq 0 ]; then
    echo "✅ AppIcon.icns ساخته شد!"
    
    echo "🧹 پاک کردن فایل‌های موقت..."
    rm -rf /tmp/AppIcon.iconset
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ آیکون جدید آماده است!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔄 حالا rebuild کن:"
    echo "   ./build.sh"
    echo ""
else
    echo "❌ خطا در ساخت .icns"
    rm -rf /tmp/AppIcon.iconset
    exit 1
fi

