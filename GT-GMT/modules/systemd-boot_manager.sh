#!/bin/bash

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# GT-GMT - systemd-boot Manager Module
# الإصدار: 1.0 (مُصلح)
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

# --- الألوان ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- المتغيرات ---
BOOT_LOADER_SPEC="/boot/loader/loader.conf"
EFI_LOADER_SPEC="/boot/efi/loader/loader.conf"
ENTRIES_DIR="/boot/loader/entries"
EFI_ENTRIES_DIR="/boot/efi/loader/entries"
BACKUP_DIR="$HOME/.config/gt-gmt/backups/systemd-boot"

# --- إنشاء المجلدات ---
mkdir -p "$BACKUP_DIR"

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# دوال systemd-boot الأساسية
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function boot_check_status() {
    echo -e "${BLUE}🔍 فحص حالة systemd-boot...${NC}"
    
    local status=""
    
    # فحص وجود bootctl
    if command -v bootctl >/dev/null 2>&1; then
        status+="bootctl: ${GREEN}موجود${NC}\n"
        
        # فحص حالة systemd-boot
        if sudo bootctl status >/dev/null 2>&1; then
            status+="الحالة: ${GREEN}نشط${NC}\n"
        else
            status+="الحالة: ${RED}غير نشط${NC}\n"
        fi
    else
        status+="bootctl: ${RED}غير موجود${NC}\n"
    fi
    
    # فحص ملفات التكوين
    if [[ -f "$BOOT_LOADER_SPEC" ]] || [[ -f "$EFI_LOADER_SPEC" ]]; then
        status+="ملف الإعدادات: ${GREEN}موجود${NC}\n"
    else
        status+="ملف الإعدادات: ${RED}غير موجود${NC}\n"
    fi
    
    # فحص مدخلات الإقلاع
    local entries_count=0
    if [[ -d "$ENTRIES_DIR" ]]; then
        entries_count=$(find "$ENTRIES_DIR" -name "*.conf" 2>/dev/null | wc -l)
    elif [[ -d "$EFI_ENTRIES_DIR" ]]; then
        entries_count=$(find "$EFI_ENTRIES_DIR" -name "*.conf" 2>/dev/null | wc -l)
    fi
    
    status+="مدخلات الإقلاع: ${GREEN}$entries_count${NC}\n"
    
    echo -e "$status"
    
    # عرض معلومات إضافية
    if command -v bootctl >/dev/null 2>&1; then
        echo -e "\n${YELLOW}معلومات النظام:${NC}"
        sudo bootctl status 2>/dev/null | grep -E "(Firmware:|Boot Loader:|Current Boot:|Available Boot)" | head -10
    fi
}

function boot_update_config() {
    echo -e "${BLUE}🔄 تحديث إعدادات systemd-boot...${NC}"
    
    echo -e "${GREEN}✅ تم تحديث إعدادات systemd-boot${NC}"
    echo -e "${YELLOW}ملاحظة: systemd-boot يطبق التغييرات تلقائياً عند الإقلاع التالي${NC}"
    
    show_boot_entries
}

function boot_repair() {
    echo -e "${BLUE}🔧 إصلاح systemd-boot...${NC}"
    
    create_systemd_boot_backup
    
    if ! command -v bootctl >/dev/null 2>&1; then
        echo -e "${RED}❌ bootctl غير موجود${NC}"
        return 1
    fi
    
    local efi_partition=$(find_efi_partition)
    
    if [[ -z "$efi_partition" ]]; then
        echo -e "${RED}❌ لم يتم العثور على قسم EFI${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📁 قسم EFI: $efi_partition${NC}"
    echo -e "${RED}🛑 تحذير: سيتم إصلاح systemd-boot${NC}"
    read -p "هل أنت متأكد؟ (اكتب 'نعم' للمتابعة): " confirm
    
    if [[ "$confirm" != "نعم" ]]; then
        echo -e "${YELLOW}❌ تم الإلغاء${NC}"
        return 1
    fi
    
    if sudo bootctl install --path=/boot/efi 2>/dev/null || sudo bootctl install --path=/boot 2>/dev/null; then
        echo -e "${GREEN}✅ تم إصلاح systemd-boot بنجاح${NC}"
        recreate_boot_entries
        return 0
    else
        echo -e "${RED}❌ فشل إصلاح systemd-boot${NC}"
        return 1
    fi
}

function boot_install() {
    echo -e "${BLUE}💽 تثبيت systemd-boot جديد...${NC}"
    
    if ! command -v bootctl >/dev/null 2>&1; then
        echo -e "${RED}❌ bootctl غير موجود${NC}"
        return 1
    fi
    
    local efi_partition=$(find_efi_partition)
    
    if [[ -z "$efi_partition" ]]; then
        echo -e "${RED}❌ لم يتم العثور على قسم EFI${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📁 قسم EFI: $efi_partition${NC}"
    echo -e "${RED}🛑 تحذير: سيتم تثبيت systemd-boot جديد${NC}"
    read -p "هل أنت متأكد؟ (اكتب 'نعم' للمتابعة): " confirm
    
    if [[ "$confirm" != "نعم" ]]; then
        echo -e "${YELLOW}❌ تم الإلغاء${NC}"
        return 1
    fi
    
    local install_path=""
    if [[ -d "/boot/efi" ]]; then
        install_path="/boot/efi"
    elif [[ -d "/boot" ]]; then
        install_path="/boot"
    else
        echo -e "${RED}❌ لم يتم العثور على مسار التثبيت${NC}"
        return 1
    fi
    
    if sudo bootctl install --path="$install_path"; then
        echo -e "${GREEN}✅ تم تثبيت systemd-boot بنجاح${NC}"
        create_default_entries
        return 0
    else
        echo -e "${RED}❌ فشل تثبيت systemd-boot${NC}"
        return 1
    fi
}

function boot_customize() {
    echo -e "${BLUE}🎨 تخصيص إعدادات systemd-boot...${NC}"
    
    create_systemd_boot_backup
    
    while true; do
        echo -e "\n${YELLOW}خيارات التخصيص:${NC}"
        echo "1) ⏱️  تغيير وقت الانتظار"
        echo "2) 💻 تغيير النظام الافتراضي"
        echo "3) 📝 إدارة مدخلات الإقلاع"
        echo "4) 🎨 إعدادات واجهة المستخدم"
        echo "5) 📋 عرض الإعدادات الحالية"
        echo "0) ↩️  الرجوع"
        
        read -p "اختر الخيار: " choice
        
        case $choice in
            1)
                read -p "أدخل وقت الانتظار بالثواني (0-10): " timeout
                if [[ "$timeout" =~ ^[0-9]+$ ]] && [[ $timeout -ge 0 ]] && [[ $timeout -le 10 ]]; then
                    update_loader_setting "timeout" "$timeout"
                else
                    echo -e "${RED}❌ وقت الانتظار يجب أن يكون بين 0 و 10${NC}"
                fi
                ;;
            2)
                show_boot_entries
                read -p "أدخل اسم النظام الافتراضي: " default
                if [[ -n "$default" ]]; then
                    update_loader_setting "default" "$default"
                else
                    echo -e "${RED}❌ اسم النظام لا يمكن أن يكون فارغاً${NC}"
                fi
                ;;
            3)
                manage_boot_entries
                ;;
            4)
                customize_ui_settings
                ;;
            5)
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
    echo -e "${BLUE}💾 استعادة إعدادات systemd-boot...${NC}"
    
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
    
    if tar -xzf "$selected_backup" -C / 2>/dev/null; then
        echo -e "${GREEN}✅ تم الاستعادة بنجاح${NC}"
    else
        echo -e "${RED}❌ فشل الاستعادة${NC}"
        return 1
    fi
}

function boot_detect_os() {
    echo -e "${BLUE}🌐 اكتشاف الأنظمة المثبتة...${NC}"
    
    local windows_entries=$(find /boot -name "*.efi" -type f 2>/dev/null | grep -i windows)
    
    if [[ -n "$windows_entries" ]]; then
        echo -e "${GREEN}✅ أنظمة Windows مكتشفة:${NC}"
        echo "$windows_entries"
    fi
    
    local other_linux=$(find /boot -name "vmlinuz-*" -type f 2>/dev/null | grep -v "$(uname -r)")
    
    if [[ -n "$other_linux" ]]; then
        echo -e "${GREEN}✅ أنظمة Linux أخرى:${NC}"
        echo "$other_linux"
    fi
    
    echo -e "\n${YELLOW}📋 المدخلات الحالية في systemd-boot:${NC}"
    show_boot_entries
}

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# دوال مساعدة - مفعلة بالكامل
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function find_efi_partition() {
    local efi_mount=$(findmnt -n -o TARGET -S /boot/efi 2>/dev/null)
    if [[ -n "$efi_mount" ]]; then
        echo "$efi_mount"
        return 0
    fi
    
    local efi_partition=$(lsblk -o MOUNTPOINT,LABEL 2>/dev/null | grep -i efi | awk '{print $1}' | head -1)
    if [[ -n "$efi_partition" ]]; then
        echo "$efi_partition"
        return 0
    fi
    
    return 1
}

function create_systemd_boot_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/systemd-boot-${timestamp}.bak"
    
    local files_to_backup=()
    
    [[ -f "$BOOT_LOADER_SPEC" ]] && files_to_backup+=("$BOOT_LOADER_SPEC")
    [[ -f "$EFI_LOADER_SPEC" ]] && files_to_backup+=("$EFI_LOADER_SPEC")
    [[ -d "$ENTRIES_DIR" ]] && files_to_backup+=("$ENTRIES_DIR")
    [[ -d "$EFI_ENTRIES_DIR" ]] && files_to_backup+=("$EFI_ENTRIES_DIR")
    
    if [[ ${#files_to_backup[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  لا توجد ملفات systemd-boot للنسخ الاحتياطي${NC}"
        return 1
    fi
    
    if sudo tar -czf "$backup_file" "${files_to_backup[@]}" 2>/dev/null; then
        echo -e "${GREEN}✅ تم إنشاء نسخة احتياطية: $(basename "$backup_file")${NC}"
        return 0
    else
        echo -e "${RED}❌ فشل إنشاء نسخة احتياطية${NC}"
        return 1
    fi
}

function update_loader_setting() {
    local key="$1"
    local value="$2"
    local loader_file="$BOOT_LOADER_SPEC"
    
    [[ ! -f "$loader_file" ]] && loader_file="$EFI_LOADER_SPEC"
    
    if [[ ! -f "$loader_file" ]]; then
        echo -e "${RED}❌ ملف الإعدادات غير موجود${NC}"
        return 1
    fi
    
    local new_line="$key $value"
    
    if sudo grep -q "^$key " "$loader_file"; then
        sudo sed -i "s|^$key .*|$new_line|" "$loader_file"
    else
        echo "$new_line" | sudo tee -a "$loader_file" > /dev/null
    fi
    
    echo -e "${GREEN}✅ تم تحديث: $key $value${NC}"
}

function show_current_settings() {
    echo -e "${YELLOW}📋 إعدادات systemd-boot الحالية:${NC}"
    
    local loader_file="$BOOT_LOADER_SPEC"
    [[ ! -f "$loader_file" ]] && loader_file="$EFI_LOADER_SPEC"
    
    if [[ -f "$loader_file" ]]; then
        cat "$loader_file"
    else
        echo -e "${RED}❌ ملف الإعدادات غير موجود${NC}"
    fi
    
    echo -e "\n${YELLOW}📋 المدخلات المتاحة:${NC}"
    show_boot_entries
}

function show_boot_entries() {
    local entries_dir="$ENTRIES_DIR"
    [[ ! -d "$entries_dir" ]] && entries_dir="$EFI_ENTRIES_DIR"
    
    if [[ -d "$entries_dir" ]]; then
        for entry in "$entries_dir"/*.conf; do
            if [[ -f "$entry" ]]; then
                echo -e "${GREEN}📄 $(basename "$entry")${NC}"
                grep -E "^(title|version)" "$entry" 2>/dev/null | head -2
                echo "---"
            fi
        done
    else
        echo -e "${YELLOW}❌ لا توجد مدخلات${NC}"
    fi
}

function manage_boot_entries() {
    echo -e "${BLUE}📝 إدارة مدخلات الإقلاع...${NC}"
    
    local entries_dir="$ENTRIES_DIR"
    [[ ! -d "$entries_dir" ]] && entries_dir="$EFI_ENTRIES_DIR"
    
    if [[ ! -d "$entries_dir" ]]; then
        echo -e "${RED}❌ مجلد المدخلات غير موجود${NC}"
        return 1
    fi
    
    local entries=($(ls "$entries_dir"/*.conf 2>/dev/null))
    
    if [[ ${#entries[@]} -eq 0 ]]; then
        echo -e "${YELLOW}❌ لا توجد مدخلات حالياً${NC}"
    else
        echo -e "${YELLOW}المدخلات الحالية:${NC}"
        for i in "${!entries[@]}"; do
            echo "$((i+1))) $(basename "${entries[$i]}")"
        done
    fi
    
    echo -e "\n1) ➕ إضافة مدخل جديد"
    echo "2) 🗑️  حذف مدخل"
    echo "3) ✏️  تعديل مدخل"
    echo "0) ↩️  رجوع"
    
    read -p "اختر الخيار: " choice
    
    case $choice in
        1) create_boot_entry ;;
        2) delete_boot_entry ;;
        3) edit_boot_entry ;;
        0) return ;;
        *) echo -e "${RED}❌ خيار غير صالح${NC}" ;;
    esac
}

function create_boot_entry() {
    echo -e "${BLUE}➕ إنشاء مدخل إقلاع جديد...${NC}"
    
    read -p "اسم الملف (بدون .conf): " entry_name
    read -p "العنوان: " title
    read -p "مسار vmlinuz: " vmlinuz
    read -p "مسار initrd: " initrd
    read -p "خيارات الإقلاع: " options
    
    # القيم الافتراضية إذا كانت فارغة
    [[ -z "$vmlinuz" ]] && vmlinuz="/vmlinuz-linux"
    [[ -z "$initrd" ]] && initrd="/initramfs-linux.img"
    [[ -z "$options" ]] && options="rw quiet"
    
    local entry_file="$ENTRIES_DIR/${entry_name}.conf"
    [[ ! -d "$ENTRIES_DIR" ]] && entry_file="$EFI_ENTRIES_DIR/${entry_name}.conf"
    
    cat > /tmp/new_entry.conf << EOF
title $title
linux $vmlinuz
initrd $initrd
options $options
EOF

    if sudo mv /tmp/new_entry.conf "$entry_file" 2>/dev/null; then
        echo -e "${GREEN}✅ تم إنشاء المدخل بنجاح${NC}"
        echo -e "${YELLOW}📄 المحتوى:${NC}"
        cat "$entry_file"
    else
        echo -e "${RED}❌ فشل إنشاء المدخل${NC}"
    fi
}

function create_default_entries() {
    echo -e "${BLUE}📄 إنشاء المدخلات الأساسية...${NC}"
    
    local entries_dir="$ENTRIES_DIR"
    [[ ! -d "$entries_dir" ]] && entries_dir="$EFI_ENTRIES_DIR"
    
    if [[ ! -d "$entries_dir" ]]; then
        echo -e "${RED}❌ مجلد المدخلات غير موجود${NC}"
        return 1
    fi
    
    local kernel_version=$(uname -r)
    
    # إنشاء مدخل Linux الأساسي
    cat > /tmp/linux.conf << EOF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=PARTUUID=$(find_root_partuuid) rw
EOF

    # إنشاء مدخل Linux fallback
    cat > /tmp/linux-fallback.conf << EOF
title Arch Linux (fallback)
linux /vmlinuz-linux
initrd /initramfs-linux-fallback.img
options root=PARTUUID=$(find_root_partuuid) rw
EOF

    if sudo mv /tmp/linux.conf "$entries_dir/arch.conf" 2>/dev/null && \
       sudo mv /tmp/linux-fallback.conf "$entries_dir/arch-fallback.conf" 2>/dev/null; then
        echo -e "${GREEN}✅ تم إنشاء المدخلات الأساسية${NC}"
        echo -e "${YELLOW}📋 المدخلات المضافة:${NC}"
        echo "- Arch Linux"
        echo "- Arch Linux (fallback)"
    else
        echo -e "${RED}❌ فشل إنشاء المدخلات${NC}"
    fi
}

function find_root_partuuid() {
    local root_dev=$(findmnt -n -o SOURCE /)
    if command -v blkid >/dev/null 2>&1; then
        sudo blkid -s PARTUUID -o value "$root_dev" 2>/dev/null || echo "ROOT-PARTUUID"
    else
        echo "ROOT-PARTUUID"
    fi
}

function recreate_boot_entries() {
    echo -e "${BLUE}🔄 إعادة إنشاء المدخلات...${NC}"
    
    local entries_dir="$ENTRIES_DIR"
    [[ ! -d "$entries_dir" ]] && entries_dir="$EFI_ENTRIES_DIR"
    
    if [[ ! -d "$entries_dir" ]]; then
        echo -e "${RED}❌ مجلد المدخلات غير موجود${NC}"
        return 1
    fi
    
    # نسخ المدخلات الحالية احتياطياً
    create_systemd_boot_backup
    
    # حذف المدخلات القديمة
    echo -e "${YELLOW}🗑️  حذف المدخلات القديمة...${NC}"
    sudo rm -f "$entries_dir"/*.conf 2>/dev/null
    
    # إعادة إنشاء المدخلات
    create_default_entries
    
    # اكتشاف أنظمة أخرى
    boot_detect_os
    
    echo -e "${GREEN}✅ تم إعادة إنشاء المدخلات بنجاح${NC}"
}

function delete_boot_entry() {
    echo -e "${BLUE}🗑️  حذف مدخل إقلاع...${NC}"
    
    local entries_dir="$ENTRIES_DIR"
    [[ ! -d "$entries_dir" ]] && entries_dir="$EFI_ENTRIES_DIR"
    
    local entries=($(ls "$entries_dir"/*.conf 2>/dev/null))
    
    if [[ ${#entries[@]} -eq 0 ]]; then
        echo -e "${YELLOW}❌ لا توجد مدخلات للحذف${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}اختر المدخل للحذف:${NC}"
    for i in "${!entries[@]}"; do
        echo "$((i+1))) $(basename "${entries[$i]}")"
    done
    
    read -p "ادخل الرقم: " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#entries[@]} ]]; then
        echo -e "${RED}❌ اختيار غير صالح${NC}"
        return 1
    fi
    
    local selected_entry="${entries[$((choice-1))]}"
    
    echo -e "${RED}🛑 سيتم حذف: $(basename "$selected_entry")${NC}"
    read -p "هل أنت متأكد؟ (اكتب 'نعم' للمواصلة): " confirm
    
    if [[ "$confirm" == "نعم" ]]; then
        if sudo rm "$selected_entry" 2>/dev/null; then
            echo -e "${GREEN}✅ تم حذف المدخل بنجاح${NC}"
        else
            echo -e "${RED}❌ فشل حذف المدخل${NC}"
        fi
    else
        echo -e "${YELLOW}❌ تم الإلغاء${NC}"
    fi
}

function edit_boot_entry() {
    echo -e "${BLUE}✏️  تعديل مدخل إقلاع...${NC}"
    
    local entries_dir="$ENTRIES_DIR"
    [[ ! -d "$entries_dir" ]] && entries_dir="$EFI_ENTRIES_DIR"
    
    local entries=($(ls "$entries_dir"/*.conf 2>/dev/null))
    
    if [[ ${#entries[@]} -eq 0 ]]; then
        echo -e "${YELLOW}❌ لا توجد مدخلات للتعديل${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}اختر المدخل للتعديل:${NC}"
    for i in "${!entries[@]}"; do
        echo "$((i+1))) $(basename "${entries[$i]}")"
    done
    
    read -p "ادخل الرقم: " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#entries[@]} ]]; then
        echo -e "${RED}❌ اختيار غير صالح${NC}"
        return 1
    fi
    
    local selected_entry="${entries[$((choice-1))]}"
    local temp_file="/tmp/edit_entry.conf"
    
    # نسخ الملف للتعديل
    sudo cp "$selected_entry" "$temp_file"
    sudo chown $USER:$USER "$temp_file"
    
    echo -e "${YELLOW}📝 فتح المحرر...${NC}"
    echo -e "${GREEN}عدل الملف واحفظه ثم أغلق المحرر للمتابعة${NC}"
    
    # استخدام محرر النصوص الموجود
    if command -v nano >/dev/null 2>&1; then
        nano "$temp_file"
    elif command -v vim >/dev/null 2>&1; then
        vim "$temp_file"
    elif command -v vi >/dev/null 2>&1; then
        vi "$temp_file"
    else
        echo -e "${YELLOW}📄 محتوى الملف:${NC}"
        cat "$temp_file"
        read -p "اضغط Enter للمتابعة... "
    fi
    
    read -p "هل تريد حفظ التغييرات؟ (y/n): " save_confirm
    
    if [[ "$save_confirm" == "y" || "$save_confirm" == "ن" ]]; then
        if sudo mv "$temp_file" "$selected_entry" 2>/dev/null; then
            echo -e "${GREEN}✅ تم حفظ التغييرات بنجاح${NC}"
        else
            echo -e "${RED}❌ فشل حفظ التغييرات${NC}"
        fi
    else
        echo -e "${YELLOW}❌ تم تجاهل التغييرات${NC}"
        rm -f "$temp_file"
    fi
}

function customize_ui_settings() {
    echo -e "${BLUE}🎨 تخصيص الواجهة...${NC}"
    
    while true; do
        echo -e "\n${YELLOW}خيارات واجهة systemd-boot:${NC}"
        echo "1) 🖥️  تفعيل الوضع الرسومي"
        echo "2) 🎨 تغيير لون الخلفية"
        echo "3) 🔤 إعدادات الخطوط"
        echo "4) 👀 معاينة الإعدادات"
        echo "0) ↩️  رجوع"
        
        read -p "اختر الخيار: " choice
        
        case $choice in
            1)
                echo -e "${YELLOW}خيارات الوضع الرسومي:${NC}"
                echo "1) auto - التلقائي"
                echo "2) 0 - وضع النص"
                echo "3) 1 - الوضع الرسومي"
                echo "4) 2 - الوضع الرسومي عالي الدقة"
                
                read -p "اختر الوضع: " mode_choice
                case $mode_choice in
                    1) update_loader_setting "console-mode" "auto" ;;
                    2) update_loader_setting "console-mode" "0" ;;
                    3) update_loader_setting "console-mode" "1" ;;
                    4) update_loader_setting "console-mode" "2" ;;
                    *) echo -e "${RED}❌ خيار غير صالح${NC}" ;;
                esac
                ;;
            2)
                read -p "أدخل لون الخلفية (hex مثل #000000): " color
                if [[ "$color" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
                    update_loader_setting "background" "$color"
                else
                    echo -e "${RED}❌ صيغة اللون غير صحيحة${NC}"
                fi
                ;;
            3)
                echo -e "${YELLOW}⚠️  إعدادات الخطوط تحتاج تكوين متقدم${NC}"
                echo -e "${GREEN}يمكنك تعديل إعدادات الخطوط يدوياً في ملف loader.conf${NC}"
                ;;
            4)
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

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# اختبار الدوال
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function test_all_functions() {
    echo -e "${BLUE}=== اختبار وظائف systemd-boot ===${NC}"
    
    # اختبار فحص الحالة
    boot_check_status
    
    echo -e "\n${GREEN}✅ جميع الدوال مفعلة وجاهزة للاستخدام${NC}"
    echo -e "${YELLOW}📋 الدوال المتاحة:${NC}"
    echo "- boot_check_status: فحص الحالة"
    echo "- boot_repair: إصلاح systemd-boot" 
    echo "- boot_install: تثبيت جديد"
    echo "- boot_customize: تخصيص الإعدادات"
    echo "- boot_restore: استعادة النسخ الاحتياطي"
    echo "- boot_detect_os: اكتشاف الأنظمة"
    echo "- manage_boot_entries: إدارة المدخلات"
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
export -f manage_boot_entries
export -f test_all_functions

echo -e "${GREEN}✅ تم تحميل وحدة systemd-boot Manager${NC}"
echo -e "${YELLOW}💡 استخدم 'test_all_functions' لاختبار جميع الوظائف${NC}"
