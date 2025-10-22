#!/bin/bash

# ألوان لل output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# المسارات النظامية
INSTALL_DIR="/usr/local/share/gt-gmt"
BINARY_PATH="/usr/local/bin/gt-gmt"
DESKTOP_FILE="/usr/share/applications/gt-gmt.desktop"
ICONS_DIR="/usr/share/icons/hicolor"
POLICY_FILE="/usr/share/polkit-1/actions/com.github.gt-gmt.policy"

# المسار الأصلي (لحمايته)
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

function uninstall_icons() {
    echo -e "${BLUE}🗑️  إزالة الأيقونات...${NC}"
    
    local icon_sizes=("16x16" "32x32" "48x48" "64x64" "128x128" "256x256" "scalable")
    local removed_count=0
    
    for size in "${icon_sizes[@]}"; do
        local icon_dir="$ICONS_DIR/${size}/apps"
        local icon_files=("gt-gmt.png" "gt-gmt.svg" "gt-gmt-icon.png")
        
        for icon_file in "${icon_files[@]}"; do
            local full_path="$icon_dir/$icon_file"
            if [[ -f "$full_path" ]]; then
                sudo rm -f "$full_path"
                echo -e "${GREEN}  ✅ تم إزالة $icon_file ($size)${NC}"
                ((removed_count++))
            fi
        done
    done
    
    # تحديث ذاكرة التخزين المؤقت
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        sudo gtk-update-icon-cache -f "$ICONS_DIR"
    fi
    
    echo -e "${GREEN}🎉 تم إزالة $removed_count أيقونة${NC}"
}

function uninstall_binary() {
    echo -e "${BLUE}🗑️  إزالة البرنامج التنفيذي...${NC}"
    
    if [[ -f "$BINARY_PATH" ]]; then
        sudo rm -f "$BINARY_PATH"
        echo -e "${GREEN}✅ تم إزالة البرنامج التنفيذي${NC}"
    else
        echo -e "${YELLOW}⚠️  البرنامج التنفيذي غير موجود${NC}"
    fi
}

function uninstall_desktop_file() {
    echo -e "${BLUE}🗑️  إزالة ملف التطبيق...${NC}"
    
    if [[ -f "$DESKTOP_FILE" ]]; then
        sudo rm -f "$DESKTOP_FILE"
        echo -e "${GREEN}✅ تم إزالة ملف التطبيق${NC}"
    else
        echo -e "${YELLOW}⚠️  ملف التطبيق غير موجود${NC}"
    fi
}

function uninstall_policy_file() {
    echo -e "${BLUE}🗑️  إزالة ملف السياسة...${NC}"
    
    if [[ -f "$POLICY_FILE" ]]; then
        sudo rm -f "$POLICY_FILE"
        echo -e "${GREEN}✅ تم إزالة ملف السياسة${NC}"
    else
        echo -e "${YELLOW}⚠️  ملف السياسة غير موجود${NC}"
    fi
}

function uninstall_main_program() {
    echo -e "${BLUE}🗑️  إزالة البرنامج الرئيسي...${NC}"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        sudo rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}✅ تم إزالة مجلد البرنامج${NC}"
    else
        echo -e "${YELLOW}⚠️  مجلد البرنامج غير موجود${NC}"
    fi
}

function verify_uninstallation() {
    echo -e "${BLUE}🔍 التحقق من الإزالة...${NC}"
    
    local remaining=0
    
    if [[ -f "$BINARY_PATH" ]]; then
        echo -e "${RED}❌ البرنامج التنفيذي لا يزال موجوداً${NC}"
        ((remaining++))
    fi
    
    if [[ -d "$INSTALL_DIR" ]]; then
        echo -e "${RED}❌ مجلد البرنامج لا يزال موجوداً${NC}"
        ((remaining++))
    fi
    
    if [[ -f "$DESKTOP_FILE" ]]; then
        echo -e "${RED}❌ ملف التطبيق لا يزال موجوداً${NC}"
        ((remaining++))
    fi
    
    if [[ -f "$POLICY_FILE" ]]; then
        echo -e "${RED}❌ ملف السياسة لا يزال موجوداً${NC}"
        ((remaining++))
    fi
    
    if [[ $remaining -eq 0 ]]; then
        echo -e "${GREEN}✅ تمت الإزالة الكاملة${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  بقي $remaining عنصر${NC}"
        return 1
    fi
}

function main_uninstall() {
    echo -e "${RED}🚨 بدء إزالة GT-GMT System Manager...${NC}"
    
    # التحقق من أننا لسنا root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}❌ لا تشغل هذا السكريبت كـ root${NC}"
        echo -e "${YELLOW}💡 شغله كمستخدم عادي وسيطلب منك sudo${NC}"
        exit 1
    fi
    
    # التحقق من أننا لسنا في مجلد التثبيت الأصلي
    if [[ "$SOURCE_DIR" == "$INSTALL_DIR" ]]; then
        echo -e "${RED}❌ خطير: لا تشغل الإزالة من مجلد التثبيت النظامي${NC}"
        echo -e "${YELLOW}💡 استخدم النسخة الأصلية من مجلد المصدر${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}📁 مجلد المصدر المحمي: $SOURCE_DIR${NC}"
    echo -e "${YELLOW}📁 مجلد النظام المستهدف: $INSTALL_DIR${NC}"
    
    read -p "هل أنت متأكد من الإزالة؟ (اكتب 'نعم' للمتابعة): " confirm
    
    if [[ "$confirm" != "نعم" ]]; then
        echo -e "${YELLOW}❌ تم الإلغاء${NC}"
        exit 0
    fi
    
    # التحقق من صلاحيات sudo
    check_sudo
    
    echo -e "${GREEN}🔐 تم التحقق من صلاحيات sudo${NC}"
    
    # إزالة المكونات
    uninstall_binary
    uninstall_icons
    uninstall_desktop_file
    uninstall_policy_file
    uninstall_main_program
    
    # التحقق من الإزالة
    verify_uninstallation
    
    echo -e "\n${GREEN}🎉 تم الإزالة بنجاح!${NC}"
    echo -e "${YELLOW}📝 ملاحظة: مجلد المصدر الأصلي محفوظ وآمن: $SOURCE_DIR${NC}"
}

# تشغيل الإزالة
main_uninstall
