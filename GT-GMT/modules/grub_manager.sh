#!/bin/bash

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# GRUB Manager - نسخة كاملة مع آليات BIOS و UEFI
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

# --- الألوان ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# تحديد إصدار GRUB
if command -v grub2-install >/dev/null 2>&1; then
    GRUB_INSTALL="grub2-install"
    GRUB_MKCONFIG="grub2-mkconfig"
    GRUB_CFG="/boot/grub2/grub.cfg"
    GRUB_DIR="/boot/grub2"
else
    GRUB_INSTALL="grub-install"
    GRUB_MKCONFIG="grub-mkconfig"
    GRUB_CFG="/boot/grub/grub.cfg"
    GRUB_DIR="/boot/grub"
fi

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# دوال مساعدة
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function detect_boot_system() {
    if [ -d /sys/firmware/efi ]; then
        echo "uefi"
    else
        echo "bios"
    fi
}

function get_boot_disk() {
    # اكتشاف قرص الإقلاع الرئيسي
    local root_disk=$(lsblk -ndo NAME,MOUNTPOINT | grep " /$" | head -1 | cut -d' ' -f1)
    local boot_disk=$(lsblk -ndo NAME,MOUNTPOINT | grep " /boot$" | head -1 | cut -d' ' -f1)
    
    if [ -n "$boot_disk" ]; then
        echo "$boot_disk"
    elif [ -n "$root_disk" ]; then
        echo "$root_disk"
    else
        lsblk -ndo NAME | grep -E "^(sda|vda|nvme0)" | head -1
    fi
}

function update_grub_setting() {
    local key="$1"
    local value="$2"
    local config_file="/etc/default/grub"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ ملف الإعدادات غير موجود${NC}"
        return 1
    fi
    
    # إذا كانت القيمة تحتوي على مسافات، نضعها بين quotes
    if [[ "$value" =~ [[:space:]] ]]; then
        value="\"$value\""
    fi
    
    local new_line="$key=$value"
    
    # إذا كان الإعداد موجوداً
    if grep -q "^$key=" "$config_file"; then
        sed -i "s|^$key=.*|$new_line|" "$config_file"
    # إذا كان الإعداد معلقاً
    elif grep -q "^#$key=" "$config_file"; then
        sed -i "s|^#$key=.*|$new_line|" "$config_file"
    # إذا لم يكن موجوداً
    else
        echo "$new_line" >> "$config_file"
    fi
    
    echo -e "${GREEN}✅ تم تحديث: $key=$value${NC}"
}

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# دوال GRUB الرئيسية
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

function boot_check_status() {
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${BLUE}🔍 فحص حالة GRUB - الإصدار: $GRUB_INSTALL${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo ""
    
    local boot_system=$(detect_boot_system)
    
    # فحص نظام الإقلاع
    echo -e "${CYAN}📊 نظام الإقلاع:${NC}"
    if [ "$boot_system" = "uefi" ]; then
        echo -e "  ${GREEN}✅ UEFI${NC}"
        efibootmgr 2>/dev/null && echo -e "  ${GREEN}📋 EFI Boot Manager نشط${NC}" || echo -e "  ${YELLOW}⚠️  EFI Boot Manager غير نشط${NC}"
    else
        echo -e "  ${GREEN}✅ BIOS (Legacy)${NC}"
    fi
    
    # فحص GRUB
    echo -e "${CYAN}🔧 حالة GRUB:${NC}"
    if command -v $GRUB_INSTALL >/dev/null 2>&1; then
        local grub_version=$($GRUB_INSTALL --version | head -1)
        echo -e "  ${GREEN}✅ GRUB: مثبت ويعمل${NC}"
        echo -e "  📋 الإصدار: $grub_version"
    else
        echo -e "  ${RED}❌ GRUB: غير مثبت${NC}"
        return 1
    fi
    
    # فحص ملفات GRUB
    echo -e "${CYAN}📄 ملفات التكوين:${NC}"
    if [ -f "$GRUB_CFG" ]; then
        local cfg_size=$(du -h "$GRUB_CFG" | cut -f1)
        local entries=$(grep -c "menuentry" "$GRUB_CFG" 2>/dev/null || echo "0")
        local last_modified=$(stat -c %y "$GRUB_CFG" 2>/dev/null | cut -d' ' -f1)
        echo -e "  ${GREEN}✅ grub.cfg: موجود ($cfg_size)${NC}"
        echo -e "  💾 المدخلات: $entries نظام"
        echo -e "  📅 آخر تعديل: $last_modified"
    else
        echo -e "  ${RED}❌ grub.cfg: غير موجود${NC}"
    fi
    
    if [ -f "/etc/default/grub" ]; then
        echo -e "  ${GREEN}✅ الإعدادات: /etc/default/grub${NC}"
    else
        echo -e "  ${RED}❌ الإعدادات: غير موجودة${NC}"
    fi
    
    # فحص الإعدادات الحالية
    echo -e "${CYAN}⚙️  الإعدادات الحالية:${NC}"
    local timeout=$(grep "GRUB_TIMEOUT" /etc/default/grub | cut -d= -f2 | head -1)
    local default=$(grep "GRUB_DEFAULT" /etc/default/grub | cut -d= -f2 | head -1)
    local theme=$(grep "GRUB_THEME" /etc/default/grub | cut -d= -f2 | head -1)
    
    echo -e "  ⏱️  وقت الانتظار: ${timeout:-5}"
    echo -e "  💻 النظام الافتراضي: ${default:-0}"
    [ -n "$theme" ] && echo -e "  🎨 الثيم: $theme"
    
    # فحص اكتشاف الأنظمة
    echo -e "${CYAN}🌐 اكتشاف الأنظمة:${NC}"
    if command -v os-prober >/dev/null 2>&1; then
        local other_os=$(os-prober 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✅ os-prober: مثبت${NC}"
        echo -e "  🔍 الأنظمة الأخرى: $other_os مكتشف"
        
        # عرض الأنظمة المكتشفة
        if [ "$other_os" -gt 0 ]; then
            echo -e "\n  ${YELLOW}📋 الأنظمة المكتشفة:${NC}"
            os-prober 2>/dev/null | while read -r line; do
                echo -e "    📌 $line"
            done
        fi
    else
        echo -e "  ${YELLOW}⚠️  os-prober: غير مثبت${NC}"
    fi
    
    # فحص القرص
    local boot_disk=$(get_boot_disk)
    echo -e "${CYAN}💾 قرص الإقلاع:${NC}"
    echo -e "  📀 القرص: /dev/$boot_disk"
    
    echo ""
    echo -e "${GREEN}💡 النظام يعمل بـ $GRUB_INSTALL على نظام $boot_system${NC}"
    echo -e "${BLUE}==============================================${NC}"
}

function boot_update_config() {
    echo -e "${BLUE}🔄 تحديث إعدادات GRUB...${NC}"
    
    # إنشاء نسخة احتياطية
    local backup_dir="/var/lib/gt-gmt/backups/grub"
    mkdir -p "$backup_dir"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    cp /etc/default/grub "$backup_dir/grub-$timestamp.bak" 2>/dev/null
    cp "$GRUB_CFG" "$backup_dir/grub.cfg-$timestamp.bak" 2>/dev/null
    
    echo -e "${YELLOW}📝 جاري إنشاء ملف grub.cfg جديد...${NC}"
    
    if $GRUB_MKCONFIG -o "$GRUB_CFG"; then
        echo -e "${GREEN}✅ تم تحديث GRUB بنجاح${NC}"
        echo -e "${GREEN}💾 تم إنشاء نسخة احتياطية${NC}"
        
        # عرض التغييرات
        local new_entries=$(grep -c "menuentry" "$GRUB_CFG" 2>/dev/null || echo "0")
        echo -e "${CYAN}📊 عدد المدخلات الجديدة: $new_entries نظام${NC}"
    else
        echo -e "${RED}❌ فشل تحديث GRUB${NC}"
        return 1
    fi
}

function boot_repair() {
    echo -e "${BLUE}🔧 إصلاح GRUB...${NC}"
    
    local boot_disk=$(get_boot_disk)
    local boot_system=$(detect_boot_system)
    
    if [ -z "$boot_disk" ]; then
        echo -e "${RED}❌ لم يتم العثور على قرص التثبيت${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📊 معلومات الإصلاح:${NC}"
    echo -e "  💾 القرص: /dev/$boot_disk"
    echo -e "  🖥️  النظام: $boot_system"
    
    echo -e "${RED}🛑 تحذير: سيتم إعادة تثبيت GRUB على /dev/$boot_disk${NC}"
    read -p "هل أنت متأكد؟ (اكتب 'نعم' للتأكيد): " confirm
    
    if [ "$confirm" != "نعم" ]; then
        echo -e "${YELLOW}❌ تم الإلغاء${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🔧 جاري إصلاح GRUB...${NC}"
    
    # تثبيت GRUB على القرص
    if $GRUB_INSTALL "/dev/$boot_disk"; then
        echo -e "${GREEN}✅ تم تثبيت GRUB على القرص${NC}"
    else
        echo -e "${RED}❌ فشل تثبيت GRUB${NC}"
        return 1
    fi
    
    # تحديث التكوين
    if $GRUB_MKCONFIG -o "$GRUB_CFG"; then
        echo -e "${GREEN}✅ تم تحديث تكوين GRUB${NC}"
        echo -e "${GREEN}🎉 تم إصلاح GRUB بنجاح${NC}"
    else
        echo -e "${RED}❌ فشل تحديث التكوين${NC}"
        return 1
    fi
}

function boot_install() {
    echo -e "${BLUE}💽 تثبيت GRUB جديد...${NC}"
    echo -e "${YELLOW}⚠️  GRUB مثبت بالفعل ($GRUB_INSTALL)${NC}"
    echo -e "${GREEN}💡 استخدم خيار 'إصلاح' إذا كنت تواجه مشاكل${NC}"
}

function boot_customize() {
    echo -e "${BLUE}🎨 تخصيص إعدادات GRUB...${NC}"
    
    while true; do
        echo ""
        echo -e "${CYAN}خيارات التخصيص:${NC}"
        echo "1) ⏱️  تغيير وقت الانتظار"
        echo "2) 💻 تغيير النظام الافتراضي"
        echo "3) 💾 تفعيل تذكر آخر خيار"
        echo "4) 🔎 تفعيل/تعطيل اكتشاف الأنظمة"
        echo "5) 🖥️  تعيين دقة الشاشة"
        echo "6) 🎨 تعيين ثيم GRUB"
        echo "7) 📋 عرض الإعدادات الحالية"
        echo "8) 🔄 إعادة تعيين الإعدادات"
        echo "0) ↩️  رجوع"
        
        read -p "اختر الخيار: " choice
        
        case $choice in
            1)
                read -p "الوقت بالثواني: " timeout
                update_grub_setting "GRUB_TIMEOUT" "$timeout"
                ;;
            2)
                read -p "رقم النظام الافتراضي: " default
                update_grub_setting "GRUB_DEFAULT" "$default"
                ;;
            3)
                update_grub_setting "GRUB_DEFAULT" "saved"
                update_grub_setting "GRUB_SAVEDEFAULT" "true"
                echo -e "${GREEN}✅ تم تفعيل تذكر آخر خيار${NC}"
                ;;
            4)
                read -p "تفعيل اكتشاف الأنظمة؟ (true/false): " enable
                if [ "$enable" = "true" ]; then
                    update_grub_setting "GRUB_DISABLE_OS_PROBER" "false"
                else
                    update_grub_setting "GRUB_DISABLE_OS_PROBER" "true"
                fi
                ;;
            5)
                read -p "دقة الشاشة (مثال: 1024x768): " resolution
                update_grub_setting "GRUB_GFXMODE" "$resolution"
                ;;
            6)
                read -p "مسار الثيم: " theme
                update_grub_setting "GRUB_THEME" "$theme"
                ;;
            7)
                echo -e "${CYAN}📋 الإعدادات الحالية:${NC}"
                grep -E "GRUB_|# GRUB_" /etc/default/grub | grep -v "^#"
                ;;
            8)
                echo -e "${YELLOW}🔄 إعادة تعيين الإعدادات...${NC}"
                cp /etc/default/grub "/etc/default/grub.backup.$(date +%s)"
                # إعدادات افتراضية
                echo "GRUB_TIMEOUT=5" > /etc/default/grub
                echo "GRUB_DEFAULT=0" >> /etc/default/grub
                echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
                echo -e "${GREEN}✅ تم إعادة التعيين${NC}"
                ;;
            0) break ;;
            *) echo -e "${RED}❌ خيار غير صالح${NC}" ;;
        esac
        
        echo ""
        read -p "هل تريد تطبيق التغييرات الآن؟ (y/n): " apply
        if [ "$apply" = "y" ] || [ "$apply" = "ن" ]; then
            boot_update_config
        fi
    done
}

function boot_detect_os() {
    echo -e "${BLUE}🌐 اكتشاف الأنظمة المثبتة...${NC}"
    
    if command -v os-prober >/dev/null 2>&1; then
        echo -e "${YELLOW}🔍 جاري الاكتشاف...${NC}"
        local detected_systems=$(os-prober 2>/dev/null)
        
        if [ -n "$detected_systems" ]; then
            echo -e "${GREEN}✅ الأنظمة المكتشفة:${NC}"
            echo "$detected_systems" | while read -r system; do
                echo -e "  📌 $system"
            done
            
            local count=$(echo "$detected_systems" | wc -l)
            echo -e "${CYAN}📊 الإجمالي: $count نظام${NC}"
        else
            echo -e "${YELLOW}⚠️  لم يتم اكتشاف أنظمة أخرى${NC}"
        fi
    else
        echo -e "${RED}❌ os-prober غير مثبت${NC}"
        echo -e "${YELLOW}💡 قم بتثبيته: sudo dnf install os-prober${NC}"
    fi
}

export -f boot_check_status boot_update_config boot_repair boot_install boot_customize boot_detect_os
echo -e "${GREEN}✅ تم تحميل GRUB Manager - يدعم $GRUB_INSTALL${NC}"
