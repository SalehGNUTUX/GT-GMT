#!/bin/bash

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# GT-GMT - مدير إقلاع نظام
# الإصدار: 2.2 (يدعم GRUB2 في Fedora)
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# إعداد الصلاحيات التلقائية
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function auto_set_permissions() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # منح صلاحيات التنفيذ للبرنامج الرئيسي
    if [[ -f "$script_dir/gt-gmt.sh" ]]; then
        chmod +x "$script_dir/gt-gmt.sh"
    fi
    
    # منح صلاحيات التنفيذ للوحدات النمطية
    if [[ -d "$script_dir/modules" ]]; then
        chmod +x "$script_dir/modules"/*.sh 2>/dev/null
    fi
    
    # منح صلاحيات التنفيذ لسكريبتات التثبيت
    for script in "install.sh" "uninstall.sh"; do
        if [[ -f "$script_dir/$script" ]]; then
            chmod +x "$script_dir/$script"
        fi
    done
}

# تنفيذ إعداد الصلاحيات عند البدء
auto_set_permissions
# --- الألوان ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- المسارات ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
BACKUP_DIR="/var/lib/gt-gmt/backups"
CONFIG_DIR="/etc/gt-gmt"

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# دوال الأساسية
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ هذه الأداة تتطلب صلاحيات الجذر${NC}"
        echo -e "${YELLOW}🔄 إعادة التشغيل بصلاحيات الجذر...${NC}"
        exec sudo "$0" "$@"
    fi
}

function init_directories() {
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$BACKUP_DIR/grub"
    mkdir -p "$BACKUP_DIR/systemd-boot"
    mkdir -p "$BACKUP_DIR/refind"
}

function load_module() {
    local manager=$1
    local module_file="$MODULES_DIR/${manager}_manager.sh"
    
    if [[ -f "$module_file" ]]; then
        source "$module_file"
        echo -e "${GREEN}✅ تم تحميل: $manager${NC}"
        return 0
    else
        echo -e "${RED}❌ الوحدة غير موجودة: $manager${NC}"
        return 1
    fi
}

function detect_boot_manager() {
    # Fedora يستخدم GRUB2 - التحقق منه أولاً
    if command -v grub2-install >/dev/null 2>&1 && [ -d /boot/grub2 ]; then
        echo "grub"
    elif command -v grub-install >/dev/null 2>&1 && [ -d /boot/grub ]; then
        echo "grub"
    elif command -v bootctl >/dev/null 2>&1 && [ -d /boot/loader ]; then
        echo "systemd-boot" 
    elif [ -d /boot/efi/EFI/refind ] || command -v refind-install >/dev/null 2>&1; then
        echo "refind"
    else
        echo "unknown"
    fi
}

function create_backup() {
    local manager=$1
    local backup_type=$2
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/$manager/${manager}-${backup_type}-${timestamp}.tar.gz"
    
    echo -e "${BLUE}💾 إنشاء نقطة استعادة...${NC}"
    
    case $manager in
        "grub")
            # دعم كل من GRUB و GRUB2
            if [ -f /boot/grub2/grub.cfg ]; then
                tar -czf "$backup_file" /etc/default/grub /boot/grub2/grub.cfg /boot/grub2/ 2>/dev/null
            else
                tar -czf "$backup_file" /etc/default/grub /boot/grub/grub.cfg /boot/grub/ 2>/dev/null
            fi
            ;;
        "systemd-boot")
            tar -czf "$backup_file" /boot/loader/loader.conf /boot/loader/entries/ 2>/dev/null
            ;;
        "refind")
            tar -czf "$backup_file" /boot/efi/EFI/refind/refind.conf /boot/efi/EFI/refind/themes/ 2>/dev/null
            ;;
    esac
    
    if [[ -f "$backup_file" ]]; then
        echo -e "${GREEN}✅ تم إنشاء النسخة الاحتياطية: $(basename $backup_file)${NC}"
        echo "$backup_file"
    else
        echo -e "${RED}❌ فشل إنشاء النسخة الاحتياطية${NC}"
        return 1
    fi
}

function list_backups() {
    local manager=$1
    local backups=($(ls -1t "$BACKUP_DIR/$manager"/*.tar.gz 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  لا توجد نسخ احتياطية لـ $manager${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📋 النسخ الاحتياطية المتاحة:${NC}"
    for i in "${!backups[@]}"; do
        local size=$(du -h "${backups[$i]}" | cut -f1)
        local date=$(basename "${backups[$i]}" | cut -d'-' -f3-5 | sed 's/.tar.gz//')
        echo "$((i+1))) ${backups[$i]} ($size - $date)"
    done
}

function restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}❌ ملف النسخة الاحتياطية غير موجود${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🔄 استعادة من: $(basename $backup_file)${NC}"
    read -p "هل أنت متأكد؟ (اكتب 'نعم' للتأكيد): " confirm
    
    if [[ "$confirm" != "نعم" ]]; then
        echo -e "${YELLOW}❌ تم الإلغاء${NC}"
        return 1
    fi
    
    if tar -xzf "$backup_file" -C /; then
        echo -e "${GREEN}✅ تم الاستعادة بنجاح${NC}"
        return 0
    else
        echo -e "${RED}❌ فشل الاستعادة${NC}"
        return 1
    fi
}

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# دوال systemd-boot
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function boot_check_status() {
    echo -e "${BLUE}🔍 فحص حالة systemd-boot...${NC}"
    
    if command -v bootctl >/dev/null 2>&1; then
        echo -e "${GREEN}✅ systemd-boot مثبت${NC}"
        bootctl status
    else
        echo -e "${RED}❌ systemd-boot غير مثبت${NC}"
        return 1
    fi
    
    if [ -f /boot/loader/loader.conf ]; then
        echo -e "${GREEN}✅ ملف التهيئة موجود${NC}"
        echo "--- محتوى loader.conf ---"
        cat /boot/loader/loader.conf
    else
        echo -e "${YELLOW}⚠️  ملف loader.conf غير موجود${NC}"
    fi
    
    # عرض المدخلات الحالية
    if [ -d /boot/loader/entries ]; then
        echo -e "\n${CYAN}📋 مدخلات التمهيد الحالية:${NC}"
        ls -la /boot/loader/entries/
    fi
}

function create_boot_entries() {
    local current_kernel=$(uname -r)
    local arch=$(uname -m)
    
    # البحث عن أحدث النواة في /boot
    local latest_vmlinuz=$(ls /boot/vmlinuz-* /boot/vmlinu*z-* 2>/dev/null | sort -V | tail -n1)
    local latest_initrd=$(ls /boot/initramfs-*.img /boot/initrd-* 2>/dev/null | sort -V | tail -n1)
    
    if [ -z "$latest_vmlinuz" ]; then
        echo -e "${YELLOW}⚠️  لم يتم العثور على ملف vmlinuz${NC}"
        return 1
    fi
    
    # استخراج إصدار النواة من اسم الملف
    local kernel_version=$(basename "$latest_vmlinuz" | sed 's/vmlinuz-//')
    
    # إنشاء مدخل التمهيد
    local entry_file="/boot/loader/entries/gt-gmt-${kernel_version}.conf"
    
    # الحصول على UUID الخاص بـ /
    local root_uuid=$(findmnt -n -o UUID /)
    if [ -z "$root_uuid" ]; then
        root_uuid="AUTO"
    fi
    
    sudo tee "$entry_file" > /dev/null << EOF
title GT-GMT - ${kernel_version}
linux /vmlinuz-${kernel_version}
initrd /initramfs-${kernel_version}.img
options root=UUID=${root_uuid} ro quiet splash
EOF

    echo -e "${GREEN}✅ تم إنشاء مدخل: $(basename $entry_file)${NC}"
}

function boot_update_config() {
    echo -e "${BLUE}🔄 تحديث إعدادات systemd-boot...${NC}"
    
    if command -v bootctl >/dev/null 2>&1; then
        # تحديث إعدادات systemd-boot
        if [ -d /boot/efi ]; then
            sudo bootctl install --path=/boot/efi --no-variables
        else
            sudo bootctl install --path=/boot --no-variables
        fi
        
        # إنشاء مدخلات جديدة للنواة الحالية
        create_boot_entries
        
        echo -e "${GREEN}✅ تم تحديث systemd-boot${NC}"
        return 0
    else
        echo -e "${RED}❌ systemd-boot غير مثبت${NC}"
        return 1
    fi
}

function boot_repair() {
    echo -e "${YELLOW}🔧 إصلاح systemd-boot...${NC}"
    
    # إنشاء نسخة احتياطية أولاً
    create_backup "systemd-boot" "repair"
    
    # إعادة تثبيت systemd-boot
    if command -v bootctl >/dev/null 2>&1; then
        if [ -d /boot/efi ]; then
            sudo bootctl install --path=/boot/efi --no-variables
        else
            sudo bootctl install --path=/boot --no-variables
        fi
        
        # إعادة إنشاء المدخلات
        create_boot_entries
        
        echo -e "${GREEN}✅ تم إصلاح systemd-boot${NC}"
        return 0
    else
        echo -e "${RED}❌ لا يمكن إصلاح systemd-boot - غير مثبت${NC}"
        return 1
    fi
}

function boot_install() {
    echo -e "${BLUE}💽 تثبيت systemd-boot...${NC}"
    
    if command -v bootctl >/dev/null 2>&1; then
        if [ -d /boot/efi ]; then
            sudo bootctl install --path=/boot/efi
        else
            sudo bootctl install --path=/boot
        fi
        echo -e "${GREEN}✅ تم تثبيت systemd-boot${NC}"
        return 0
    else
        echo -e "${RED}❌ systemd-boot غير متوفر في النظام${NC}"
        return 1
    fi
}

function boot_customize() {
    echo -e "${CYAN}🎨 تخصيص systemd-boot...${NC}"
    
    local loader_conf="/boot/loader/loader.conf"
    
    if [ ! -f "$loader_conf" ]; then
        echo -e "${YELLOW}⚠️  إنشاء ملف loader.conf جديد${NC}"
        sudo tee "$loader_conf" > /dev/null << EOF
default gt-gmt-*
timeout 5
console-mode keep
editor no
EOF
    fi
    
    echo -e "${YELLOW}📝 خيارات التخصيص:${NC}"
    echo "1) تغيير وقت الانتظار (حالي: $(grep timeout "$loader_conf" | cut -d' ' -f2))"
    echo "2) تغيير الوضع الافتراضي"
    echo "3) إضافة خيارات للنواة"
    echo "4) الرجوع"
    
    read -p "اختر: " choice
    
    case $choice in
        1)
            read -p "أدخل وقت الانتظار بالثواني: " timeout
            sudo sed -i "s/^timeout.*/timeout $timeout/" "$loader_conf"
            echo -e "${GREEN}✅ تم تغيير وقت الانتظار${NC}"
            ;;
        2)
            read -p "أدخل المدخل الافتراضي: " default
            sudo sed -i "s/^default.*/default $default/" "$loader_conf"
            echo -e "${GREEN}✅ تم تغيير المدخل الافتراضي${NC}"
            ;;
        3)
            read -p "أدخل الخيارات الإضافية: " options
            # إضافة الخيارات لجميع المدخلات
            for entry in /boot/loader/entries/*.conf; do
                sudo sed -i "/^options/s/$/ $options/" "$entry"
            done
            echo -e "${GREEN}✅ تم إضافة الخيارات${NC}"
            ;;
        4) return ;;
        *) echo -e "${RED}❌ خيار غير صالح${NC}" ;;
    esac
    
    # تطبيق التغييرات
    boot_update_config
}

function boot_detect_os() {
    echo -e "${BLUE}🌐 اكتشاف الأنظمة المثبتة...${NC}"
    
    # اكتشاف أنظمة Linux
    echo -e "${CYAN}🐧 أنظمة Linux:${NC}"
    if [ -d /boot/loader/entries ]; then
        find /boot/loader/entries -name "*.conf" -exec basename {} \; | while read entry; do
            echo -e "  📄 $entry"
        done
    fi
    
    # اكتشاف أنظمة Windows
    if [ -f /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi ]; then
        echo -e "${CYAN}🪟 نظام Windows:${NC}"
        echo -e "  ✅ Windows موجود"
    fi
    
    # عرض النواة الحالية
    echo -e "${CYAN}📊 النواة الحالية:${NC}"
    echo -e "  🐧 $(uname -r)"
}

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# الواجهة الرئيسية
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function show_main_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║           GT-GMT - مدير الإقلاع          ║"
    echo "║             الإصدار 2.2                 ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "المستخدم: $(whoami)"
    echo -e "مدير الإقلاع: ${GREEN}$CURRENT_BOOT_MANAGER${NC}"
    echo -e "النواة: $(uname -r)"
    echo "----------------------------------------"
    
    echo -e "\nاختر عملية:"
    echo "1) 🔍 فحص حالة الإقلاع"
    echo "2) 🔄 تحديث إعدادات الإقلاع"
    echo "3) 🔧 إصلاح مدير الإقلاع"
    echo "4) 💽 تثبيت مدير إقلاع جديد"
    echo "5) 🎨 تخصيص الإعدادات"
    echo "6) 💾 إنشاء نقطة استعادة"
    echo "7) 📂 استعادة إعدادات سابقة"
    echo "8) 🌐 اكتشاف الأنظمة المثبتة"
    echo "9) 🔄 تغيير مدير الإقلاع"
    echo "0) 🚪 خروج"
    echo -e "\nاختر رقم العملية: "
}

function handle_backup_creation() {
    echo -e "${CYAN}💾 إنشاء نقطة استعادة...${NC}"
    local backup_file=$(create_backup "$CURRENT_BOOT_MANAGER" "manual")
    if [[ -n "$backup_file" ]]; then
        echo -e "${GREEN}✅ جاهز للاستعادة في أي وقت${NC}"
    fi
}

function handle_backup_restore() {
    if list_backups "$CURRENT_BOOT_MANAGER"; then
        read -p "اختر رقم النسخة للاستعادة: " choice
        local backups=($(ls -1t "$BACKUP_DIR/$CURRENT_BOOT_MANAGER"/*.tar.gz 2>/dev/null))
        
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#backups[@]} ]]; then
            echo -e "${RED}❌ اختيار غير صالح${NC}"
            return 1
        fi
        
        local selected_backup="${backups[$((choice-1))]}"
        if restore_backup "$selected_backup"; then
            read -p "هل تريد تطبيق التغييرات الآن؟ (y/n): " apply
            if [[ "$apply" == "y" || "$apply" == "ن" ]]; then
                boot_update_config
            fi
        fi
    fi
}

function handle_manager_change() {
    echo -e "${CYAN}🔄 تغيير مدير الإقلاع...${NC}"
    echo -e "${YELLOW}اختر المدير:${NC}"
    echo "1) GRUB (مستقر)"
    echo "2) systemd-boot (حديث)"
    echo "3) rEFInd (رسومي)"
    echo "4) الرجوع"
    
    read -p "اختر: " choice
    
    case $choice in
        1) 
            if load_module "grub"; then
                export CURRENT_BOOT_MANAGER="grub"
                echo -e "${GREEN}✅ تم التغيير إلى GRUB${NC}"
            fi
            ;;
        2) 
            if load_module "systemd-boot"; then
                export CURRENT_BOOT_MANAGER="systemd-boot"
                echo -e "${GREEN}✅ تم التغيير إلى systemd-boot${NC}"
            fi
            ;;
        3) 
            if load_module "refind"; then
                export CURRENT_BOOT_MANAGER="refind"
                echo -e "${GREEN}✅ تم التغيير إلى rEFInd${NC}"
            fi
            ;;
        4) return ;;
        *) echo -e "${RED}❌ خيار غير صالح${NC}" ;;
    esac
}

function main() {
    # التحقق من الجذر أولاً
    check_root "$@"
    
    # تهيئة المجلدات
    init_directories
    
    # اكتشاف وتحليل مدير الإقلاع
    local detected_manager=$(detect_boot_manager)
    if [[ "$detected_manager" == "unknown" ]]; then
        echo -e "${RED}❌ لم يتم اكتشاف مدير إقلاع${NC}"
        echo -e "${YELLOW}💡 يمكنك تثبيت مدير إقلاع يدوياً${NC}"
        detected_manager="systemd-boot" # افتراضي لنظامك
    fi
    
    # تحميل الوحدة
    if load_module "$detected_manager"; then
        export CURRENT_BOOT_MANAGER="$detected_manager"
    else
        echo -e "${RED}❌ فشل تحميل مدير الإقلاع${NC}"
        echo -e "${YELLOW}💡 جاري تحميل systemd-boot كبديل...${NC}"
        
        # تحميل دوال systemd-boot مباشرة (مضمنة)
        export CURRENT_BOOT_MANAGER="systemd-boot"
        echo -e "${GREEN}✅ تم التحميل المضمن لـ systemd-boot${NC}"
    fi
    
    # الحلقة الرئيسية
    while true; do
        show_main_menu
        read -p "> " choice
        
        case $choice in
            1) boot_check_status ;;
            2) 
                create_backup "$CURRENT_BOOT_MANAGER" "auto"
                boot_update_config 
                ;;
            3) 
                create_backup "$CURRENT_BOOT_MANAGER" "repair"
                boot_repair 
                ;;
            4) boot_install ;;
            5) 
                create_backup "$CURRENT_BOOT_MANAGER" "customize"
                boot_customize 
                ;;
            6) handle_backup_creation ;;
            7) handle_backup_restore ;;
            8) boot_detect_os ;;
            9) handle_manager_change ;;
            0) 
                echo -e "${GREEN}👋 مع السلامة!${NC}"
                exit 0 
                ;;
            *) 
                echo -e "${RED}❌ خيار غير صالح${NC}"
                ;;
        esac
        
        echo -e "\nاضغط Enter للمتابعة..."
        read
    done
}

# بدء التشغيل
main "$@"
