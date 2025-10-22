#!/bin/bash

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# GT-GMT - rEFInd Boot Manager Module
# الإصدار: 1.0
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

# --- الألوان ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- المتغيرات ---
REFIND_CONFIG="/boot/efi/EFI/refind/refind.conf"
REFIND_EFI_DIR="/boot/efi/EFI/refind"
REFIND_THEMES_DIR="/boot/efi/EFI/refind/themes"
BACKUP_DIR="$HOME/.config/gt-gmt/backups/refind"

# --- إنشاء المجلدات ---
mkdir -p "$BACKUP_DIR"

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# دوال rEFInd الأساسية
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function boot_check_status() {
    echo -e "${BLUE}🔍 فحص حالة rEFInd...${NC}"
    
    local status=""
    
    # فحص وجود rEFInd
    if [[ -d "$REFIND_EFI_DIR" ]]; then
        status+="rEFInd: ${GREEN}مثبت${NC}\n"
    else
        status+="rEFInd: ${RED}غير مثبت${NC}\n"
    fi
    
    # فحص ملف التكوين
    if [[ -f "$REFIND_CONFIG" ]]; then
        status+="ملف الإعدادات: ${GREEN}موجود${NC}\n"
        
        # فحص الثيمات
        if [[ -d "$REFIND_THEMES_DIR" ]]; then
            local themes_count=$(find "$REFIND_THEMES_DIR" -maxdepth 1 -type d | wc -l)
            status+="عدد الثيمات: ${GREEN}$((themes_count - 1))${NC}\n"
        else
            status+="الثيمات: ${YELLOW}غير مثبتة${NC}\n"
        fi
    else
        status+="ملف الإعدادات: ${RED}غير موجود${NC}\n"
    fi
    
    # فحص السكريبتات
    if command -v refind-install >/dev/null 2>&1; then
        status+="أدوات rEFInd: ${GREEN}موجودة${NC}\n"
    else
        status+="أدوات rEFInd: ${YELLOW}غير موجودة${NC}\n"
    fi
    
    echo -e "$status"
    
    # عرض معلومات إضافية
    if [[ -f "$REFIND_CONFIG" ]]; then
        echo -e "\n${YELLOW}🎨 الثيم الحالي:${NC}"
        grep -i "theme\|icons_dir" "$REFIND_CONFIG" | head -5
    fi
}

function boot_update_config() {
    echo -e "${BLUE}🔄 تحديث إعدادات rEFInd...${NC}"
    
    if [[ ! -f "$REFIND_CONFIG" ]]; then
        echo -e "${RED}❌ ملف إعدادات rEFInd غير موجود${NC}"
        return 1
    fi
    
    # rEFInd لا يحتاج تحديث يدوي - التغييرات تطبق تلقائياً
    echo -e "${GREEN}✅ تم تحديث إعدادات rEFInd${NC}"
    echo -e "${YELLOW}ملاحظة: rEFInd يطبق التغييرات تلقائياً عند الإقلاع التالي${NC}"
    
    # عرض التغييرات
    show_refind_summary
}

function boot_repair() {
    echo -e "${BLUE}🔧 إصلاح rEFInd...${NC}"
    
    # إنشاء نسخة احتياطية أولاً
    create_refind_backup
    
    if ! command -v refind-install >/dev/null 2>&1; then
        echo -e "${RED}❌ refind-install غير موجود${NC}"
        echo -e "${YELLOW}💡 جرب تثبيت rEFInd أولاً: sudo apt install refind${NC}"
        return 1
    fi
    
    # تحذير أمني
    echo -e "${RED}🛑 تحذير: سيتم إصلاح تثبيت rEFInd${NC}"
    read -p "هل أنت متأكد؟ (اكتب 'نعم' للمتابعة): " confirm
    
    if [[ "$confirm" != "نعم" ]]; then
        echo -e "${YELLOW}❌ تم الإلغاء${NC}"
        return 1
    fi
    
    # إصلاح rEFInd
    if sudo refind-install --yes 2>/dev/null; then
        echo -e "${GREEN}✅ تم إصلاح rEFInd بنجاح${NC}"
        
        # استعادة الإعدادات إذا كانت موجودة
        restore_refind_settings
        return 0
    else
        echo -e "${RED}❌ فشل إصلاح rEFInd${NC}"
        return 1
    fi
}

function boot_install() {
    echo -e "${BLUE}💽 تثبيت rEFInd جديد...${NC}"
    
    # تحقق إذا كان rEFInd مثبتاً بالفعل
    if [[ -d "$REFIND_EFI_DIR" ]]; then
        echo -e "${YELLOW}⚠️  rEFInd مثبت بالفعل${NC}"
        read -p "هل تريد إعادة التثبيت؟ (y/n): " reinstall
        if [[ "$reinstall" != "y" && "$reinstall" != "ن" ]]; then
            return 1
        fi
    fi
    
    # تحذير أمني
    echo -e "${RED}🛑 تحذير: سيتم تثبيت rEFInd كمدير إقلاع رئيسي${NC}"
    read -p "هل أنت متأكد؟ (اكتب 'نعم' للمتابعة): " confirm
    
    if [[ "$confirm" != "نعم" ]]; then
        echo -e "${YELLOW}❌ تم الإلغاء${NC}"
        return 1
    fi
    
    # التثبيت باستخدام refind-install
    if command -v refind-install >/dev/null 2>&1; then
        if sudo refind-install --yes; then
            echo -e "${GREEN}✅ تم تثبيت rEFInd بنجاح${NC}"
            
            # تثبيت ثيم افتراضي
            install_default_theme
            return 0
        else
            echo -e "${RED}❌ فشل تثبيت rEFInd${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ refind-install غير موجود${NC}"
        echo -e "${YELLOW}💡 قم بتثبيت rEFInd أولاً من مستودعات توزيعتك${NC}"
        return 1
    fi
}

function boot_customize() {
    echo -e "${BLUE}🎨 تخصيص إعدادات rEFInd...${NC}"
    
    if [[ ! -f "$REFIND_CONFIG" ]]; then
        echo -e "${RED}❌ ملف إعدادات rEFInd غير موجود${NC}"
        return 1
    fi
    
    # إنشاء نسخة احتياطية
    create_refind_backup
    
    while true; do
        echo -e "\n${YELLOW}خيارات تخصيص rEFInd:${NC}"
        echo "1) ⏱️  تغيير وقت الانتظار"
        echo "2) 🖼️  إدارة الثيمات"
        echo "3) 📏 تغيير دقة الشاشة"
        echo "4) 🎯 إعدادات الاكتشاف التلقائي"
        echo "5) 🔧 خيارات متقدمة"
        echo "6) 📋 عرض الإعدادات الحالية"
        echo "0) ↩️  الرجوع"
        
        read -p "اختر الخيار: " choice
        
        case $choice in
            1)
                read -p "أدخل وقت الانتظار بالثواني: " timeout
                update_refind_setting "timeout" "$timeout"
                ;;
            2)
                manage_themes
                ;;
            3)
                customize_resolution
                ;;
            4)
                customize_scanning
                ;;
            5)
                advanced_settings
                ;;
            6)
                show_current_settings
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}❌ خيار غير صالح${NC}"
                ;;
        esac
    done
}

function boot_restore() {
    echo -e "${BLUE}💾 استعادة إعدادات rEFInd...${NC}"
    
    local backups=($(ls -1t "$BACKUP_DIR"/*.bak 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${YELLOW}❌ لا توجد نسخ احتياطية${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}النسخ الاحتياطية المتاحة:${NC}"
    for i in "${!backups[@]}"; do
        echo "$((i+1))) $(basename "${backups[$i]}")"
    done
    
    read -p "اختر رقم النسخة: " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#backups[@]} ]]; then
        echo -e "${RED}❌ اختيار غير صالح${NC}"
        return 1
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    
    echo -e "${YELLOW}سيتم استعادة: $(basename "$selected_backup")${NC}"
    read -p "هل أنت متأكد؟ (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "ن" ]]; then
        echo -e "${YELLOW}❌ تم الإلغاء${NC}"
        return 1
    fi
    
    if sudo cp "$selected_backup" "$REFIND_CONFIG"; then
        echo -e "${GREEN}✅ تم الاستعادة بنجاح${NC}"
    else
        echo -e "${RED}❌ فشل الاستعادة${NC}"
        return 1
    fi
}

function boot_detect_os() {
    echo -e "${BLUE}🌐 اكتشاف الأنظمة المثبتة...${NC}"
    
    if [[ ! -f "$REFIND_CONFIG" ]]; then
        echo -e "${RED}❌ ملف إعدادات rEFInd غير موجود${NC}"
        return 1
    fi
    
    # عرض إعدادات الاكتشاف الحالية
    echo -e "${YELLOW}🔍 إعدادات الاكتشاف الحالية:${NC}"
    grep -E "scan_|extra_|include_" "$REFIND_CONFIG" | grep -v "^#" | head -10
    
    # اكتشاف الأنظمة المتاحة
    echo -e "\n${YELLOW}💻 الأنظمة المكتشفة:${NC}"
    
    # أنظمة Linux
    local linux_kernels=$(find /boot -name "vmlinuz-*" -type f 2>/dev/null | head -5)
    if [[ -n "$linux_kernels" ]]; then
        echo -e "${GREEN}🐧 أنظمة Linux:${NC}"
        echo "$linux_kernels"
    fi
    
    # أنظمة Windows
    local windows_efi=$(find /boot -name "*.efi" -type f 2>/dev/null | grep -i windows | head -3)
    if [[ -n "$windows_efi" ]]; then
        echo -e "${GREEN}🪟 أنظمة Windows:${NC}"
        echo "$windows_efi"
    fi
    
    # أنظمة أخرى
    local other_efi=$(find /boot/efi/EFI -name "*.efi" -type f 2>/dev/null | grep -v -i "refind\|boot" | head -5)
    if [[ -n "$other_efi" ]]; then
        echo -e "${GREEN}🔧 أنظمة أخرى:${NC}"
        echo "$other_efi"
    fi
}

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# دوال مساعدة
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function create_refind_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/refind-${timestamp}.bak"
    
    if [[ -f "$REFIND_CONFIG" ]]; then
        if sudo cp "$REFIND_CONFIG" "$backup_file" 2>/dev/null; then
            echo -e "${GREEN}✅ تم إنشاء نسخة احتياطية: $(basename "$backup_file")${NC}"
            return 0
        else
            echo -e "${RED}❌ فشل إنشاء نسخة احتياطية${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  لا توجد ملفات rEFInd للنسخ الاحتياطي${NC}"
        return 1
    fi
}

function update_refind_setting() {
    local key="$1"
    local value="$2"
    
    if [[ ! -f "$REFIND_CONFIG" ]]; then
        echo -e "${RED}❌ ملف الإعدادات غير موجود${NC}"
        return 1
    fi
    
    # التعامل مع القيم الخاصة
    case "$key" in
        "timeout")
            value="$value"
            ;;
        "resolution")
            value="$value"
            ;;
        "theme")
            value="\"$value\""
            ;;
    esac
    
    local new_line="$key $value"
    
    # إذا كان الإعداد موجوداً
    if sudo grep -q "^$key " "$REFIND_CONFIG"; then
        sudo sed -i "s|^$key .*|$new_line|" "$REFIND_CONFIG"
    # إذا كان الإعداد معلقاً
    elif sudo grep -q "^#$key " "$REFIND_CONFIG"; then
        sudo sed -i "s|^#$key .*|$new_line|" "$REFIND_CONFIG"
    # إذا لم يكن موجوداً
    else
        echo "$new_line" | sudo tee -a "$REFIND_CONFIG" > /dev/null
    fi
    
    echo -e "${GREEN}✅ تم تحديث: $key $value${NC}"
}

function show_current_settings() {
    echo -e "${YELLOW}📋 إعدادات rEFInd الحالية:${NC}"
    
    if [[ ! -f "$REFIND_CONFIG" ]]; then
        echo -e "${RED}❌ ملف الإعدادات غير موجود${NC}"
        return 1
    fi
    
    # عرض الإعدادات المهمة
    echo -e "${BLUE}⚙️  الإعدادات الأساسية:${NC}"
    grep -E "^(timeout|resolution|hideui|showtools)" "$REFIND_CONFIG" | head -10
    
    echo -e "\n${BLUE}🎨 إعدادات الواجهة:${NC}"
    grep -E "^(theme|icons_dir|banner)" "$REFIND_CONFIG" | head -10
    
    echo -e "\n${BLUE}🔍 إعدادات الاكتشاف:${NC}"
    grep -E "^(scan_|extra_|include_)" "$REFIND_CONFIG" | head -10
}

function manage_themes() {
    echo -e "${BLUE}🎨 إدارة ثيمات rEFInd...${NC}"
    
    # التحقق من وجود مجلد الثيمات
    if [[ ! -d "$REFIND_THEMES_DIR" ]]; then
        sudo mkdir -p "$REFIND_THEMES_DIR"
    fi
    
    echo -e "${YELLOW}الثيمات المثبتة:${NC}"
    local themes=($(find "$REFIND_THEMES_DIR" -maxdepth 1 -type d -exec basename {} \; | grep -v "^themes$"))
    
    if [[ ${#themes[@]} -eq 0 ]]; then
        echo -e "${YELLOW}❌ لا توجد ثيمات مثبتة${NC}"
    else
        for theme in "${themes[@]}"; do
            if [[ "$theme" != "themes" && -n "$theme" ]]; then
                echo "🎨 $theme"
            fi
        done
    fi
    
    echo -e "\n1) تغيير الثيم الحالي"
    echo "2) تثبيت ثيم جديد"
    echo "3) إزالة ثيم"
    echo "0) رجوع"
    
    read -p "اختر الخيار: " choice
    
    case $choice in
        1)
            change_theme
            ;;
        2)
            install_theme
            ;;
        3)
            remove_theme
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}❌ خيار غير صالح${NC}"
            ;;
    esac
}

function change_theme() {
    local themes=($(find "$REFIND_THEMES_DIR" -maxdepth 1 -type d -exec basename {} \; | grep -v "^themes$"))
    
    if [[ ${#themes[@]} -eq 0 ]]; then
        echo -e "${YELLOW}❌ لا توجد ثيمات متاحة${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}اختر ثيم:${NC}"
    for i in "${!themes[@]}"; do
        echo "$((i+1))) ${themes[$i]}"
    done
    
    read -p "رقم الثيم: " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#themes[@]} ]]; then
        echo -e "${RED}❌ اختيار غير صالح${NC}"
        return 1
    fi
    
    local selected_theme="${themes[$((choice-1))]}"
    update_refind_setting "theme" "rEFInd-themes/$selected_theme"
    echo -e "${GREEN}✅ تم تغيير الثيم إلى: $selected_theme${NC}"
}

function install_default_theme() {
    echo -e "${BLUE}🎨 تثبيت ثيم افتراضي...${NC}"
    echo -e "${YELLOW}⚠️  هذه الخاصية تحتاج تطوير إضافي${NC}"
}

function restore_refind_settings() {
    echo -e "${BLUE}🔄 استعادة إعدادات rEFInd...${NC}"
    echo -e "${YELLOW}⚠️  هذه الخاصية تحتاج تطوير إضافي${NC}"
}

function show_refind_summary() {
    echo -e "${YELLOW}📊 ملخص rEFInd:${NC}"
    
    if [[ -f "$REFIND_CONFIG" ]]; then
        local timeout=$(grep "^timeout " "$REFIND_CONFIG" | awk '{print $2}')
        local resolution=$(grep "^resolution " "$REFIND_CONFIG" | awk '{print $2}')
        local theme=$(grep "^theme " "$REFIND_CONFIG" | awk '{print $2}')
        
        echo "⏱️  وقت الانتظار: ${timeout:-غير محدد}"
        echo "🖥️  الدقة: ${resolution:-تلقائية}"
        echo "🎨 الثيم: ${theme:-افتراضي}"
    fi
}

function customize_resolution() {
    echo -e "${BLUE}📏 تخصيص دقة الشاشة...${NC}"
    
    echo -e "${YELLOW}الدقات الشائعة:${NC}"
    echo "1) 1024x768"
    echo "2) 1280x1024" 
    echo "3) 1366x768"
    echo "4) 1920x1080"
    echo "5) تلقائية"
    echo "6) إدخال يدوي"
    
    read -p "اختر الدقة: " choice
    
    case $choice in
        1) update_refind_setting "resolution" "1024x768" ;;
        2) update_refind_setting "resolution" "1280x1024" ;;
        3) update_refind_setting "resolution" "1366x768" ;;
        4) update_refind_setting "resolution" "1920x1080" ;;
        5) update_refind_setting "resolution" "max" ;;
        6)
            read -p "أدخل الدقة (مثال: 1600x900): " custom_res
            update_refind_setting "resolution" "$custom_res"
            ;;
        *)
            echo -e "${RED}❌ خيار غير صالح${NC}"
            ;;
    esac
}

function customize_scanning() {
    echo -e "${BLUE}🔍 تخصيص إعدادات الاكتشاف...${NC}"
    
    echo -e "${YELLOW}خيارات الاكتشاف:${NC}"
    echo "1) تفعيل الاكتشاف التلقائي"
    echo "2) تعطيل الاكتشاف التلقائي"
    echo "3) إضافة مسارات مخصصة"
    echo "4) إخفاء أنظمة محددة"
    
    read -p "اختر الخيار: " choice
    
    case $choice in
        1)
            update_refind_setting "scan_all_linux_kernels" "true"
            update_refind_setting "scan_driver_dirs" "true"
            ;;
        2)
            update_refind_setting "scan_all_linux_kernels" "false"
            update_refind_setting "scan_driver_dirs" "false"
            ;;
        3)
            read -p "أدخل المسار الإضافي: " extra_path
            update_refind_setting "extra_kernel_version_strings" "$extra_path"
            ;;
        4)
            read -p "أدخل الأنظمة المخفية (مفصولة بمسافات): " hidden_systems
            update_refind_setting "hideui" "$hidden_systems"
            ;;
        *)
            echo -e "${RED}❌ خيار غير صالح${NC}"
            ;;
    esac
}

function advanced_settings() {
    echo -e "${BLUE}🔧 الإعدادات المتقدمة...${NC}"
    
    echo -e "${YELLOW}خيارات متقدمة:${NC}"
    echo "1) تفعيل وضع اللمس"
    echo "2) تغيير حجم الأيقونات"
    echo "3) إعدادات الرسومات المتقدمة"
    
    read -p "اختر الخيار: " choice
    
    case $choice in
        1)
            update_refind_setting "enable_touch" "true"
            ;;
        2)
            read -p "حجم الأيقونات (مثال: 96): " icon_size
            update_refind_setting "icons_dir" "icons_${icon_size}"
            ;;
        3)
            echo -e "${YELLOW}⚠️  الإعدادات المتقدمة تحتاج تكوين يدوي${NC}"
            ;;
        *)
            echo -e "${RED}❌ خيار غير صالح${NC}"
            ;;
    esac
}

function install_theme() {
    echo -e "${BLUE}📥 تثبيت ثيم جديد...${NC}"
    echo -e "${YELLOW}⚠️  هذه الخاصية تحتاج تطوير إضافي${NC}"
    echo -e "${YELLOW}💡 يمكنك تثبيت الثيمات يدوياً من: https://github.com/rEFInd/rEFInd-themes${NC}"
}

function remove_theme() {
    echo -e "${BLUE}🗑️  إزالة ثيم...${NC}"
    echo -e "${YELLOW}⚠️  هذه الخاصية تحتاج تطوير إضافي${NC}"
}

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# تصدير الدوال
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

export -f boot_check_status
export -f boot_update_config
export -f boot_repair
export -f boot_install
export -f boot_customize
export -f boot_restore
export -f boot_detect_os

echo -e "${GREEN}✅ تم تحميل وحدة rEFInd Manager${NC}"
