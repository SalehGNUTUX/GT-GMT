#!/bin/bash

# ألوان لل output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# المسارات النظامية
INSTALL_DIR="/usr/local/share/gt-gmt"
BINARY_PATH="/usr/local/bin/gt-gmt"
DESKTOP_FILE="/usr/share/applications/gt-gmt.desktop"
ICONS_DIR="/usr/share/icons/hicolor"
MODULES_DIR="$INSTALL_DIR/modules"

# المسار الحالي للتثبيت
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# دالة للتحقق من صلاحيات sudo
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}🔐 هذه الأداة تتطلب صلاحيات sudo${NC}"
        echo -e "${YELLOW}📝 سيطلب منك كلمة المرور الآن...${NC}"
        if ! sudo -v; then
            echo -e "${RED}❌ فشل التحقق من صلاحيات sudo${NC}"
            exit 1
        fi
    fi
}

function install_main_program() {
    echo -e "${BLUE}📦 تثبيت البرنامج الرئيسي...${NC}"

    # إنشاء مجلد التثبيت
    sudo mkdir -p "$INSTALL_DIR"

    # نسخ جميع الملفات إلى مجلد التثبيت (باستثناء المثبت والمزيل)
    echo -e "${YELLOW}📁 نسخ الملفات إلى $INSTALL_DIR...${NC}"

    # نسخ الملفات الرئيسية
    sudo cp "$SCRIPT_DIR/gt-gmt.sh" "$INSTALL_DIR/" 2>/dev/null && echo -e "${GREEN}  ✅ البرنامج الرئيسي${NC}" || echo -e "${RED}  ❌ البرنامج الرئيسي${NC}"

    # نسخ الوحدات النمطية
    if [[ -d "$SCRIPT_DIR/modules" ]]; then
        sudo cp -r "$SCRIPT_DIR/modules" "$INSTALL_DIR/" 2>/dev/null && echo -e "${GREEN}  ✅ الوحدات النمطية${NC}" || echo -e "${RED}  ❌ الوحدات النمطية${NC}"
    fi

    # نسخ الملفات الأخرى (إن وجدت)
    for file in "$SCRIPT_DIR"/*; do
        if [[ -f "$file" ]] && [[ "$file" != "$SCRIPT_DIR/install.sh" ]] && [[ "$file" != "$SCRIPT_DIR/uninstall.sh" ]]; then
            local filename=$(basename "$file")
            if [[ "$filename" != "gt-gmt.sh" ]]; then
                sudo cp "$file" "$INSTALL_DIR/" 2>/dev/null && echo -e "${GREEN}  ✅ $filename${NC}" || echo -e "${RED}  ❌ $filename${NC}"
            fi
        fi
    done

    # إنشاء البرنامج القابل للتنفيذ
    sudo tee "$BINARY_PATH" > /dev/null << 'EOF'
#!/bin/bash
# البرنامج الرئيسي لـ GT-GMT System Manager

INSTALL_DIR="/usr/local/share/gt-gmt"
MAIN_SCRIPT="$INSTALL_DIR/gt-gmt.sh"

if [[ ! -f "$MAIN_SCRIPT" ]]; then
    echo "❌ البرنامج غير مثبت بشكل صحيح. الرجاء إعادة التثبيت."
    exit 1
fi

# تشغيل البرنامج الرئيسي
cd "$INSTALL_DIR"
exec bash "$MAIN_SCRIPT" "$@"
EOF

    sudo chmod +x "$BINARY_PATH"
    sudo chmod -R 755 "$INSTALL_DIR"

    echo -e "${GREEN}✅ تم تثبيت البرنامج في $INSTALL_DIR${NC}"
}

function install_fallback_icon() {
    echo -e "${BLUE}🎨 تثبيت أيقونة افتراضية...${NC}"

    # إنشاء أيقونة SVG بسيطة
    local icon_path="/usr/share/icons/hicolor/scalable/apps/gt-gmt.svg"
    sudo mkdir -p "$(dirname "$icon_path")"

    sudo tee "$icon_path" > /dev/null << 'EOF'
<svg width="256" height="256" xmlns="http://www.w3.org/2000/svg">
  <rect width="256" height="256" fill="#4CAF50" rx="20"/>
  <text x="128" y="140" font-family="Arial, sans-serif" font-size="48"
        font-weight="bold" fill="white" text-anchor="middle">GMT</text>
  <text x="128" y="180" font-family="Arial, sans-serif" font-size="24"
        fill="white" text-anchor="middle">Boot</text>
</svg>
EOF

    # نسخ إلى الأحجام الأخرى
    local sizes=("16x16" "32x32" "48x48" "64x64" "128x128" "256x256")
    for size in "${sizes[@]}"; do
        local target_dir="/usr/share/icons/hicolor/${size}/apps"
        sudo mkdir -p "$target_dir"
        sudo cp "$icon_path" "$target_dir/gt-gmt.svg"
    done

    # تحديث ذاكرة التخزين
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        sudo gtk-update-icon-cache -f "/usr/share/icons/hicolor"
    fi

    echo -e "${GREEN}✅ تم تثبيت أيقونة افتراضية${NC}"
}

function install_icons() {
    echo -e "${BLUE}🎨 تثبيت الأيقونات...${NC}"

    local source_icons="$SCRIPT_DIR/gt-gmt-icons"

    if [[ ! -d "$source_icons" ]]; then
        echo -e "${YELLOW}⚠️  مجلد الأيقونات غير موجود: $source_icons${NC}"
        echo -e "${YELLOW}📝 سيتم استخدام أيقونة افتراضية...${NC}"
        install_fallback_icon
        return 1
    fi

    local icon_sizes=("16x16" "32x32" "48x48" "64x64" "128x128" "256x256" "scalable")
    local installed_count=0

    for size in "${icon_sizes[@]}"; do
        local source_dir="$source_icons/$size"
        local target_dir="$ICONS_DIR/${size}/apps"

        # إذا كان الهيكل الجديد (بمجلد apps)
        if [[ -d "$source_dir/apps" ]]; then
            source_dir="$source_dir/apps"
        fi

        if [[ -d "$source_dir" ]]; then
            sudo mkdir -p "$target_dir"

            # البحث عن الملفات بدقة أكبر
            for icon_file in "$source_dir"/gt-gmt.{png,svg,xpm} "$source_dir"/gt-gmt; do
                if [[ -f "$icon_file" ]]; then
                    local icon_name=$(basename "$icon_file")
                    sudo cp "$icon_file" "$target_dir/"
                    echo -e "${GREEN}  ✅ تم تثبيت $icon_name ($size)${NC}"
                    ((installed_count++))
                    break  # توقف بعد العثور على أول ملف مطابق
                fi
            done

            # إذا لم نجد ملفاً مطابقاً في هذا الحجم
            if [[ $installed_count -eq 0 ]]; then
                echo -e "${YELLOW}  ⚠️  لم أعثر على gt-gmt.{png,svg} في $size${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠️  مجلد $size غير موجود${NC}"
        fi
    done

    # تحديث ذاكرة التخزين المؤقت للأيقونات
    if command -v gtk-update-icon-cache >/dev/null 2>&1 && [[ $installed_count -gt 0 ]]; then
        echo -e "${BLUE}🔄 تحديث ذاكرة التخزين المؤقت للأيقونات...${NC}"
        sudo gtk-update-icon-cache -f "$ICONS_DIR"
        echo -e "${GREEN}✅ تم تحديث ذاكرة التخزين المؤقت${NC}"
    fi

    if [[ $installed_count -gt 0 ]]; then
        echo -e "${GREEN}🎉 تم تثبيت $installed_count أيقونة${NC}"
    else
        echo -e "${YELLOW}⚠️  لم يتم تثبيت أي أيقونات، استخدام البديل...${NC}"
        install_fallback_icon
    fi
}

function install_policy_file() {
    echo -e "${BLUE}🔐 تثبيت ملف السياسة...${NC}"

    local policy_file="/usr/share/polkit-1/actions/com.github.gt-gmt.policy"

    sudo tee "$policy_file" > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/software/polkit/policyconfig-1.dtd">

<policyconfig>
  <action id="com.github.gt-gmt.run">
    <description>Run GT-GMT System Manager</description>
    <message>Authentication is required to run GT-GMT System Manager</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>auth_admin</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/gt-gmt</annotate>
  </action>
</policyconfig>
EOF

    echo -e "${GREEN}✅ تم تثبيت ملف السياسة${NC}"
}

function install_desktop_file() {
    echo -e "${BLUE}📋 إنشاء ملف التطبيق...${NC}"

    sudo tee "$DESKTOP_FILE" > /dev/null << 'EOF'
[Desktop Entry]
Categories=Utility;System;Settings;
Comment[en_US]=GNUtux GRUB Manager Tool - Comprehensive boot manager
Comment=GNUtux GRUB Manager Tool - Comprehensive boot manager
Comment[ar]=أداة جنو-تكس لإدارة محمل الإقلاع - مدير إقلاع شامل
Exec=pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY /usr/local/bin/gt-gmt
GenericName[en_US]=Boot Manager Tool
GenericName=Boot Manager Tool
GenericName[ar]=أداة إدارة الإقلاع
Icon=gt-gmt
Keywords=boot;grub;systemd-boot;refind;uefi;bios;
MimeType=
Name[en_US]=GT-GMT Boot Manager
Name=GT-GMT Boot Manager
Name[ar]=جي تي-جمت مدير الإقلاع
Path=
StartupNotify=false
Terminal=true
Type=Application
Version=1.0
X-KDE-SubstituteUID=false
X-KDE-Username=
EOF

    echo -e "${GREEN}✅ تم إنشاء ملف التطبيق${NC}"
    sudo chmod +x "$DESKTOP_FILE"

    # تحديث قاعدة بيانات التطبيقات
    echo -e "${BLUE}🔄 تحديث قاعدة بيانات التطبيقات...${NC}"
    sudo update-desktop-database /usr/share/applications/
    echo -e "${GREEN}✅ تم تحديث قاعدة البيانات${NC}"
}

function verify_installation() {
    echo -e "${BLUE}🔍 التحقق من التثبيت...${NC}"

    local errors=0

    # التحقق من الملفات الرئيسية
    if [[ ! -f "$BINARY_PATH" ]]; then
        echo -e "${RED}❌ البرنامج التنفيذي غير موجود${NC}"
        ((errors++))
    fi

    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo -e "${RED}❌ مجلد التثبيت غير موجود${NC}"
        ((errors++))
    fi

    if [[ ! -f "$INSTALL_DIR/gt-gmt.sh" ]]; then
        echo -e "${RED}❌ البرنامج الرئيسي غير موجود${NC}"
        ((errors++))
    fi

    if [[ ! -d "$MODULES_DIR" ]]; then
        echo -e "${RED}❌ مجلد الوحدات غير موجود${NC}"
        ((errors++))
    fi

    # التحقق من ملف desktop
    if [[ ! -f "$DESKTOP_FILE" ]]; then
        echo -e "${RED}❌ ملف التطبيق غير موجود${NC}"
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        echo -e "${GREEN}✅ جميع المكونات مثبتة بشكل صحيح${NC}"
        return 0
    else
        echo -e "${RED}❌ هناك $errors أخطاء في التثبيت${NC}"
        return 1
    fi
}

function main_install() {
    echo -e "${BLUE}🚀 بدء تثبيت GT-GMT System Manager...${NC}"

    # التحقق من أننا لسنا root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}❌ لا تشغل هذا السكريبت كـ root${NC}"
        echo -e "${YELLOW}💡 شغله كمستخدم عادي وسيطلب منك sudo${NC}"
        exit 1
    fi

    echo -e "${YELLOW}📁 المسار الحالي: $SCRIPT_DIR${NC}"
    echo -e "${YELLOW}📁 مجلد التثبيت: $INSTALL_DIR${NC}"

    # التحقق من الملفات المصدر
    if [[ ! -f "$SCRIPT_DIR/gt-gmt.sh" ]]; then
        echo -e "${RED}❌ ملف البرنامج الرئيسي غير موجود${NC}"
        exit 1
    fi

    if [[ ! -d "$SCRIPT_DIR/modules" ]]; then
        echo -e "${RED}❌ مجلد الوحدات غير موجود${NC}"
        exit 1
    fi

    # التحقق من صلاحيات sudo
    check_sudo

    echo -e "${GREEN}🔐 تم التحقق من صلاحيات sudo${NC}"

    # تثبيت المكونات
    install_main_program
    install_icons
    install_policy_file
    install_desktop_file

    # التحقق من التثبيت
    if verify_installation; then
        echo -e "\n${GREEN}🎉 تم التثبيت بنجاح!${NC}"
        echo -e "${YELLOW}💡 يمكنك الآن تشغيل البرنامج بـ: gt-gmt${NC}"
        echo -e "${YELLOW}🖥️  أو من خلال قائمة التطبيقات (GT-GMT Boot Manager)${NC}"
        echo -e "\n${BLUE}📋 معلومات التثبيت:${NC}"
        echo -e "📁 البرنامج: $INSTALL_DIR"
        echo -e "🔧 التنفيذي: $BINARY_PATH"
        echo -e "🎨 الأيقونات: $ICONS_DIR"
        echo -e "📄 الواجهة: $DESKTOP_FILE"
    else
        echo -e "${RED}❌ فشل التثبيت${NC}"
        exit 1
    fi
}

# تشغيل التثبيت
main_install
