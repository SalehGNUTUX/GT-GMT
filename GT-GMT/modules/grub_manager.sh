#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

function detect_boot_system() {
    if [ -d /sys/firmware/efi ]; then
        echo "uefi"
    else
        echo "bios"
    fi
}

function get_boot_disk() {
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
    
    if [[ "$value" =~ [[:space:]] ]]; then
        value="\"$value\""
    fi
    
    local new_line="$key=$value"
    
    if grep -q "^$key=" "$config_file"; then
        sed -i "s|^$key=.*|$new_line|" "$config_file"
    elif grep -q "^#$key=" "$config_file"; then
        sed -i "s|^#$key=.*|$new_line|" "$config_file"
    else
        echo "$new_line" >> "$config_file"
    fi
    
    echo -e "${GREEN}✅ تم تحديث: $key=$value${NC}"
}

function find_theme_file() {
    local search_dir="$1"
    
    if [[ ! -d "$search_dir" ]]; then
        echo -e "${RED}❌ المجلد غير موجود: $search_dir${NC}"
        return 1
    fi
    
    local theme_file=$(find "$search_dir" -name "theme.txt" -type f | head -1)
    
    if [[ -n "$theme_file" ]]; then
        echo "$theme_file"
        return 0
    else
        echo -e "${YELLOW}🔍 جاري البحث عن ملف السمة...${NC}"
        echo -e "${CYAN}📁 هيكل المجلد:${NC}"
        find "$search_dir" -maxdepth 2 -type f -name "*.txt" -o -name "*.png" -o -name "*.jpg" | head -10
        return 1
    fi
}

function install_grub_theme_to_root() {
    local source_theme="$1"
    local theme_name=$(basename "$source_theme")
    local root_theme_dir="/grub-themes"
    
    if [[ ! -d "$source_theme" ]]; then
        echo -e "${RED}❌ مجلد السمة غير موجود: $source_theme${NC}"
        return 1
    fi
    
    local theme_file=$(find_theme_file "$source_theme")
    
    if [[ -z "$theme_file" ]]; then
        echo -e "${RED}❌ لم يتم العثور على theme.txt في المجلد أو مجلداته الفرعية${NC}"
        echo -e "${YELLOW}💡 قد تحتاج السمة إلى تثبيت يدوي${NC}"
        return 1
    fi
    
    local theme_base_dir=$(dirname "$theme_file")
    local final_theme_name=$(basename "$theme_base_dir")
    
    echo -e "${GREEN}✅ تم العثور على السمة في: $theme_base_dir${NC}"
    
    sudo mkdir -p "$root_theme_dir"
    echo -e "${YELLOW}📁 نسخ السمة إلى $root_theme_dir...${NC}"
    sudo cp -r "$theme_base_dir" "$root_theme_dir/"
    
    local theme_path="$root_theme_dir/$final_theme_name/theme.txt"
    if [[ -f "$theme_path" ]]; then
        update_grub_setting "GRUB_THEME" "$theme_path"
        sudo chmod -R 755 "$root_theme_dir"
        sudo chown -R root:root "$root_theme_dir"
        echo -e "${GREEN}✅ تم تثبيت السمة في الجذر بنجاح${NC}"
        echo -e "${YELLOW}📁 المسار: $theme_path${NC}"
        grep -E "title-font|desktop-image|title-text" "$theme_path" 2>/dev/null | head -5
        return 0
    else
        echo -e "${RED}❌ فشل تثبيت السمة${NC}"
        return 1
    fi
}

function fix_theme_to_root() {
    local current_theme=$(grep "GRUB_THEME" /etc/default/grub | cut -d= -f2 | tr -d '"' 2>/dev/null)
    
    if [[ -z "$current_theme" ]]; then
        echo -e "${YELLOW}⚠️  لا توجد سمة محددة${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔧 نقل السمة إلى الجذر...${NC}"
    echo -e "${YELLOW}السمة الحالية: $current_theme${NC}"
    
    if [[ "$current_theme" == /usr/share/grub/themes/* ]]; then
        local theme_name=$(basename "$(dirname "$current_theme")")
        local source_dir=$(dirname "$current_theme")
        local root_theme_dir="/grub-themes"
        local root_theme_path="$root_theme_dir/$theme_name/theme.txt"
        
        sudo mkdir -p "$root_theme_dir"
        echo -e "${YELLOW}📁 نقل السمة إلى الجذر...${NC}"
        sudo cp -r "$source_dir" "$root_theme_dir/"
        sudo chmod -R 755 "$root_theme_dir"
        sudo chown -R root:root "$root_theme_dir"
        update_grub_setting "GRUB_THEME" "$root_theme_path"
        echo -e "${GREEN}✅ تم نقل السمة إلى الجذر${NC}"
        boot_update_config
        return 0
    elif [[ "$current_theme" == /grub-themes/* ]]; then
        echo -e "${GREEN}✅ السمة بالفعل في الجذر${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  السمة في موقع آخر: $current_theme${NC}"
        return 0
    fi
}

function show_boot_entries_list() {
    echo -e "${BLUE}📋 قائمة أنظمة الإقلاع المتاحة:${NC}"
    echo -e "${YELLOW}(الأرقام تبدأ من 0)${NC}"
    echo ""
    
    if [[ ! -f "$GRUB_CFG" ]]; then
        echo -e "${RED}❌ ملف grub.cfg غير موجود${NC}"
        return 1
    fi
    
    local entry_count=0
    local in_menuentry=false
    local current_title=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*menuentry[[:space:]]+\'([^\']+) ]]; then
            in_menuentry=true
            current_title="${BASH_REMATCH[1]}"
            echo -e "  ${GREEN}$entry_count) $current_title${NC}"
            ((entry_count++))
        elif [[ "$line" =~ ^[[:space:]]*\}$ ]] && [[ "$in_menuentry" == true ]]; then
            in_menuentry=false
            current_title=""
        fi
    done < "$GRUB_CFG"
    
    if [[ $entry_count -eq 0 ]]; then
        echo -e "${YELLOW}🔍 جاري البحث عن المدخلات بطريقة بديلة...${NC}"
        entry_count=$(grep -c "menuentry" "$GRUB_CFG" 2>/dev/null || echo "0")
        echo -e "${CYAN}عدد المدخلات المكتشفة: $entry_count${NC}"
        echo -e "${YELLOW}💡 استخدم الأرقام من 0 إلى $((entry_count - 1))${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}ملاحظات:${NC}"
    echo -e "  • ${YELLOW}0${NC} = أول نظام في القائمة"
    echo -e "  • ${YELLOW}saved${NC} = تذكر آخر خيار تم اختياره"
    echo -e "  • ${YELLOW}\"Windows\"${NC} = اسم النظام بين علامتي اقتباس"
    echo ""
}

function boot_check_status() {
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${BLUE}🔍 فحص حالة GRUB - الإصدار: $GRUB_INSTALL${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo ""
    
    local boot_system=$(detect_boot_system)
    
    echo -e "${CYAN}📊 نظام الإقلاع:${NC}"
    if [ "$boot_system" = "uefi" ]; then
        echo -e "  ${GREEN}✅ UEFI${NC}"
        efibootmgr 2>/dev/null && echo -e "  ${GREEN}📋 EFI Boot Manager نشط${NC}" || echo -e "  ${YELLOW}⚠️  EFI Boot Manager غير نشط${NC}"
    else
        echo -e "  ${GREEN}✅ BIOS (Legacy)${NC}"
    fi
    
    echo -e "${CYAN}🔧 حالة GRUB:${NC}"
    if command -v $GRUB_INSTALL >/dev/null 2>&1; then
        local grub_version=$($GRUB_INSTALL --version | head -1)
        echo -e "  ${GREEN}✅ GRUB: مثبت ويعمل${NC}"
        echo -e "  📋 الإصدار: $grub_version"
    else
        echo -e "  ${RED}❌ GRUB: غير مثبت${NC}"
        return 1
    fi
    
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
    
    echo -e "${CYAN}⚙️  الإعدادات الحالية:${NC}"
    local timeout=$(grep "GRUB_TIMEOUT" /etc/default/grub | cut -d= -f2 | head -1)
    local default=$(grep "GRUB_DEFAULT" /etc/default/grub | cut -d= -f2 | head -1)
    local theme=$(grep "GRUB_THEME" /etc/default/grub | cut -d= -f2 | head -1)
    
    echo -e "  ⏱️  وقت الانتظار: ${timeout:-5}"
    echo -e "  💻 النظام الافتراضي: ${default:-0}"
    [ -n "$theme" ] && echo -e "  🎨 الثيم: $theme"
    
    echo -e "${CYAN}🌐 اكتشاف الأنظمة:${NC}"
    if command -v os-prober >/dev/null 2>&1; then
        local other_os=$(os-prober 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✅ os-prober: مثبت${NC}"
        echo -e "  🔍 الأنظمة الأخرى: $other_os مكتشف"
        
        if [ "$other_os" -gt 0 ]; then
            echo -e "\n  ${YELLOW}📋 الأنظمة المكتشفة:${NC}"
            os-prober 2>/dev/null | while read -r line; do
                echo -e "    📌 $line"
            done
        fi
    else
        echo -e "  ${YELLOW}⚠️  os-prober: غير مثبت${NC}"
    fi
    
    local boot_disk=$(get_boot_disk)
    echo -e "${CYAN}💾 قرص الإقلاع:${NC}"
    echo -e "  📀 القرص: /dev/$boot_disk"
    
    echo ""
    echo -e "${GREEN}💡 النظام يعمل بـ $GRUB_INSTALL على نظام $boot_system${NC}"
    echo -e "${BLUE}==============================================${NC}"
}

function boot_update_config() {
    echo -e "${BLUE}🔄 تحديث إعدادات GRUB...${NC}"
    
    local backup_dir="/var/lib/gt-gmt/backups/grub"
    mkdir -p "$backup_dir"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    cp /etc/default/grub "$backup_dir/grub-$timestamp.bak" 2>/dev/null
    cp "$GRUB_CFG" "$backup_dir/grub.cfg-$timestamp.bak" 2>/dev/null
    
    echo -e "${YELLOW}📝 جاري إنشاء ملف grub.cfg جديد...${NC}"
    
    if $GRUB_MKCONFIG -o "$GRUB_CFG"; then
        echo -e "${GREEN}✅ تم تحديث GRUB بنجاح${NC}"
        echo -e "${GREEN}💾 تم إنشاء نسخة احتياطية${NC}"
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
    
    if $GRUB_INSTALL "/dev/$boot_disk"; then
        echo -e "${GREEN}✅ تم تثبيت GRUB على القرص${NC}"
    else
        echo -e "${RED}❌ فشل تثبيت GRUB${NC}"
        return 1
    fi
    
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
    
    local current_theme=$(grep "GRUB_THEME" /etc/default/grub | cut -d= -f2 | tr -d '"' 2>/dev/null)
    if [[ -n "$current_theme" && "$current_theme" == /usr/share/grub/themes/* ]]; then
        echo -e "${YELLOW}⚠️  السمة الحالية في مسار غير مضمون أثناء الإقلاع${NC}"
        read -p "هل تريد نقل السمة إلى الجذر (/grub-themes)؟ (y/n): " fix
        if [[ "$fix" == "y" || "$fix" == "ن" ]]; then
            fix_theme_to_root
        fi
    fi
    
    while true; do
        echo ""
        echo -e "${CYAN}خيارات التخصيص:${NC}"
        echo "1) ⏱️  تغيير وقت الانتظار"
        echo "2) 💻 تغيير النظام الافتراضي"
        echo "3) 💾 تفعيل تذكر آخر خيار"
        echo "4) 🔎 تفعيل/تعطيل اكتشاف الأنظمة"
        echo "5) 🖥️  تعيين دقة الشاشة"
        echo "6) 🎨 تعيين ثيم GRUB (في الجذر)"
        echo "7) 🔧 نقل السمة الحالية إلى الجذر"
        echo "8) 🔍 التحقق من دعم السمات"
        echo "9) 📋 عرض الإعدادات الحالية"
        echo "10) 🔄 إعادة تعيين الإعدادات"
        echo "0) ↩️  رجوع"
        
        read -p "اختر الخيار: " choice
        
        case $choice in
            1)
                read -p "الوقت بالثواني: " timeout
                update_grub_setting "GRUB_TIMEOUT" "$timeout"
                ;;
            2)
                show_boot_entries_list
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
                echo -e "${YELLOW}مسار السمة (سيتم نسخها إلى /grub-themes):${NC}"
                echo "1) /usr/share/grub/themes/Particle-sidebar"
                echo "2) /usr/share/grub/themes/starfield" 
                echo "3) مسار مخصص"
                read -p "اختر: " theme_choice
                
                case $theme_choice in
                    1) install_grub_theme_to_root "/usr/share/grub/themes/Particle-sidebar" ;;
                    2) install_grub_theme_to_root "/usr/share/grub/themes/starfield" ;;
                    3)
                        read -p "أدخل المسار الكامل للسمة: " custom_theme
                        if [[ "$custom_theme" == *.tar.gz ]]; then
                            echo -e "${YELLOW}📦 جاري فك ضغط الملف...${NC}"
                            local temp_dir="/tmp/grub_theme_$$"
                            mkdir -p "$temp_dir"
                            tar -xzf "$custom_theme" -C "$temp_dir"
                            custom_theme="$temp_dir"
                        elif [[ "$custom_theme" == *.zip ]]; then
                            echo -e "${YELLOW}📦 جاري فك ضغط الملف...${NC}"
                            local temp_dir="/tmp/grub_theme_$$"
                            mkdir -p "$temp_dir"
                            unzip "$custom_theme" -d "$temp_dir"
                            custom_theme="$temp_dir"
                        fi
                        echo -e "${YELLOW}🔍 جاري البحث عن السمة...${NC}"
                        install_grub_theme_to_root "$custom_theme"
                        if [[ -d "/tmp/grub_theme_$$" ]]; then
                            rm -rf "/tmp/grub_theme_$$"
                        fi
                        ;;
                    *) echo -e "${RED}❌ خيار غير صالح${NC}" ;;
                esac
                ;;
            7)
                fix_theme_to_root
                ;;
            8)
                echo -e "${BLUE}🔍 التحقق من دعم السمات...${NC}"
                if grep -q "GRUB_GFXMODE" /etc/default/grub; then
                    echo -e "${GREEN}✅ دعم الرسوميات مفعل${NC}"
                else
                    echo -e "${YELLOW}⚠️  دعم الرسوميات غير مفعل${NC}"
                    update_grub_setting "GRUB_GFXMODE" "auto"
                fi
                if [[ -d "/usr/share/grub/themes" ]]; then
                    local themes_count=$(find /usr/share/grub/themes -maxdepth 1 -type d | wc -l)
                    echo -e "${GREEN}✅ السمات المثبتة: $((themes_count - 1))${NC}"
                else
                    echo -e "${YELLOW}⚠️  مجلد السمات غير موجود${NC}"
                fi
                ;;
            9)
                echo -e "${CYAN}📋 الإعدادات الحالية:${NC}"
                grep -E "GRUB_|# GRUB_" /etc/default/grub | grep -v "^#"
                ;;
            10)
                echo -e "${YELLOW}🔄 إعادة تعيين الإعدادات...${NC}"
                cp /etc/default/grub "/etc/default/grub.backup.$(date +%s)"
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

export -f boot_check_status boot_update_config boot_repair boot_install boot_customize boot_detect_os show_boot_entries_list
echo -e "${GREEN}✅ تم تحميل GRUB Manager - يدعم $GRUB_INSTALL${NC}"
