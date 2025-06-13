#!/bin/bash

# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
# GT-GMT - GNUtux GRUB Manager Tool (CLI Version)
# النسخة: 0.1
# اللغة: bash
# الرخصة: GPLv2
# ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

# مسارات الإعدادات
CONFIG_DIR="$HOME/.gtgmt"
CONFIG_FILE="$CONFIG_DIR/config.conf"
DEFAULT_LANG="ar"

# تهيئة الإعدادات إن لم توجد
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "LANG=$DEFAULT_LANG" > "$CONFIG_FILE"
fi

# تحميل اللغة
source "$CONFIG_FILE"

# دوال عرض الرسائل
function msg_ar() {
  case $1 in
    welcome) echo "🔧 أداة إدارة محمل الإقلاع GRUB - GT-GMT CLI";;
    menu_main) echo -e "\nاختر عملية:
1) فحص GRUB
2) إصلاح GRUB
3) تثبيت GRUB
4) تخصيص GRUB
5) تغيير اللغة
0) خروج";;
    checking) echo "🔍 يتم فحص GRUB...";;
    repairing) echo "🔧 يتم إصلاح GRUB...";;
    installing) echo "💽 يتم تثبيت GRUB...";;
    customizing) echo "🎨 تخصيص GRUB...";;
    goodbye) echo "👋 إلى اللقاء!";;
    lang_set) echo "🌐 تم تغيير اللغة إلى العربية.";;
  esac
}

function msg_en() {
  case $1 in
    welcome) echo "🔧 GT-GMT CLI - GRUB Manager Tool";;
    menu_main) echo -e "\nChoose an option:
1) Check GRUB
2) Repair GRUB
3) Install GRUB
4) Customize GRUB
5) Change Language
0) Exit";;
    checking) echo "🔍 Checking GRUB...";;
    repairing) echo "🔧 Repairing GRUB...";;
    installing) echo "💽 Installing GRUB...";;
    customizing) echo "🎨 Customizing GRUB...";;
    goodbye) echo "👋 Goodbye!";;
    lang_set) echo "🌐 Language set to English.";;
  esac
}

# عرض رسالة حسب اللغة
function msg() {
  if [ "$LANG" = "ar" ]; then msg_ar "$1"; else msg_en "$1"; fi
}

# تغيير اللغة
function change_lang() {
  if [ "$LANG" = "ar" ]; then
    LANG="en"
  else
    LANG="ar"
  fi
  echo "LANG=$LANG" > "$CONFIG_FILE"
  msg lang_set
}

# دوال رئيسية
function check_grub() {
  msg checking
  [ -f /boot/grub/grub.cfg ] && echo "✅ grub.cfg موجود" || echo "❌ grub.cfg غير موجود"
  sudo grub-mkconfig -o /boot/grub/grub.cfg
}

function repair_grub() {
  msg repairing
  sudo grub-install --recheck /dev/sda && sudo update-grub
}

function install_grub() {
  msg installing
  sudo grub-install /dev/sda && sudo update-grub
}

function customize_grub() {
  msg customizing
  echo -e "\n1) تغيير وقت الانتظار (مدة الانتظار في GRUB)
2) تغيير نظام الإقلاع الافتراضي (الخيار الافتراضي في GRUB)
3) تفعيل تذكر آخر خيار (حفظ الخيار الأخير للإقلاع)
4) تفعيل/تعطيل وضع الاسترداد (Recovery Mode)
5) تعيين دقة العرض (دقة شاشة GRUB)
6) تعيين الخط (خط واجهة GRUB)
7) تعيين الثيم (تصميم واجهة GRUB)
0) رجوع"
  read -p "> " opt
  case $opt in
    1) read -p "⏱️ أدخل وقت الانتظار بالثواني: " tmo
       sudo sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$tmo/" /etc/default/grub;;
    2) read -p "💻 أدخل رقم النظام الافتراضي (0 لخيارات النواة): " def
       sudo sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=$def/" /etc/default/grub;;
    3) sudo sed -i '/^GRUB_DEFAULT=/a GRUB_SAVEDEFAULT=true' /etc/default/grub;;
    4) read -p "❓ إخفاء وضع الاسترداد؟ (y/n): " ans
       if [ "$ans" = "y" ]; then
         sudo sed -i '/^GRUB_DISABLE_RECOVERY/d' /etc/default/grub
         echo "GRUB_DISABLE_RECOVERY=true" | sudo tee -a /etc/default/grub
       fi;;
    5) read -p "🖥️ أدخل دقة العرض (مثال: 1024x768): " res
       sudo sed -i "/^GRUB_GFXMODE/d" /etc/default/grub
       echo "GRUB_GFXMODE=$res" | sudo tee -a /etc/default/grub;;
    6) read -p "🔤 أدخل مسار الخط بصيغة .pf2: " font
       sudo sed -i "/^GRUB_FONT/d" /etc/default/grub
       echo "GRUB_FONT=$font" | sudo tee -a /etc/default/grub;;
    7) read -p "🎨 أدخل مسار الثيم: " theme
       sudo sed -i "/^GRUB_THEME/d" /etc/default/grub
       echo "GRUB_THEME=$theme" | sudo tee -a /etc/default/grub;;
  esac
  sudo update-grub
}

# واجهة المستخدم
clear
msg welcome
while true; do
  msg menu_main
  read -p "> " choice
  case $choice in
    1) check_grub;;
    2) repair_grub;;
    3) install_grub;;
    4) customize_grub;;
    5) change_lang;;
    0) msg goodbye; exit;;
    *) echo "❗ خيار غير صالح";;
  esac
done
