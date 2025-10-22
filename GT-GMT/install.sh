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

function install_icons() {
    echo -e "${BLUE}🎨 تثبيت الأيقونات...${NC}"
    
    local source_icons="$SCRIPT_DIR/gt-gmt-icons"
    
    if [[ ! -d "$source_icons" ]]; then
        echo -e "${YELLOW}⚠️  مجلد الأيقونات غير موجود: $source_icons${NC}"
        return 1
    fi
    
    local icon_sizes=("16x16" "32x32" "48x48" "64x64" "128x128" "256x256" "scalable")
    local installed_count=0
    
    for size in "${icon_sizes[@]}"; do
        local source_dir="$source_icons/$size"
        local target_dir="$ICONS_DIR/${size}/apps"
        
        if [[ -d "$source_dir" ]]; then
            # إنشاء المجلد الهدف
            sudo mkdir -p "$target_dir"
            
            # نسخ جميع الأيقونات في المجلد
            for icon_file in "$source_dir"/*; do
                if [[ -f "$icon_file" ]]; then
                    local icon_name=$(basename "$icon_file")
                    sudo cp "$icon_file" "$target_dir/"
                    echo -e "${GREEN}  ✅ تم تثبيت $icon_name ($size)${NC}"
                    ((installed_count++))
                fi
            done
        else
            echo -e "${YELLOW}  ⚠️  مجلد $size غير موجود${NC}"
        fi
    done
    
    # تحديث ذاكرة التخزين المؤقت للأيقونات
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        echo -e "${BLUE}🔄 تحديث ذاكرة التخزين المؤقت للأيقونات...${NC}"
        sudo gtk-update-icon-cache -f "$ICONS_DIR"
        echo -e "${GREEN}✅ تم تحديث ذاكرة التخزين المؤقت${NC}"
    fi
    
    echo -e "${GREEN}🎉 تم تثبيت $installed_count أيقونة${NC}"
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
    
    sudo tee "$DESKTOP_FILE" > /dev/null << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GT-GMT System Manager
GenericName=System Management Tool
Comment=Advanced system management tool for boot and package management
Exec=pkexec gt-gmt
Icon=gt-gmt
Categories=System;Settings;
Keywords=system;boot;package;manager;
Terminal=true
StartupNotify=true
MimeType=
X-GNOME-UsesNotifications=true
EOF

    echo -e "${GREEN}✅ تم إنشاء ملف التطبيق${NC}"
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
        echo -e "${YELLOW}🖥️  أو من خلال قائمة التطبيقات (GT-GMT System Manager)${NC}"
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
