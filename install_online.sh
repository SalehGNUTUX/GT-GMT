#!/bin/bash
# 🌐 GT-GMT Online Installer — by GNUtux
# يثبت البرنامج من GitHub مباشرة مع احترام بنية المثبت المحلي

set -euo pipefail
IFS=$'\n\t'

# ألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://github.com/SalehGNUTUX/GT-GMT.git"
TMP_DIR="$(mktemp -d -t gt-gmt-install-XXXXXXX)"

echo -e "${BLUE}ℹ️  🔽 تنزيل المستودع إلى المجلد المؤقت...${NC}"
git clone --depth=1 "$REPO_URL" "$TMP_DIR/repo" >/dev/null 2>&1 && \
  echo -e "${GREEN}ℹ️  ✅ تم الاستنساخ.${NC}" || { echo -e "${RED}❌ فشل في تنزيل المستودع${NC}"; exit 1; }

# البحث عن install.sh في أي مستوى داخل المشروع
INSTALL_PATH="$(find "$TMP_DIR/repo" -type f -name install.sh | head -n 1 || true)"

if [[ -z "$INSTALL_PATH" ]]; then
    echo -e "${RED}❌ لم يتم العثور على ملف install.sh${NC}"
    echo -e "${YELLOW}📝 تأكد أن المستودع يحتوي على المثبت المحلي داخل مجلد الأداة.${NC}"
    rm -rf "$TMP_DIR"
    exit 1
fi

# تحديد المجلد الحاوي للمثبت المحلي
INSTALL_DIR="$(dirname "$INSTALL_PATH")"
echo -e "${BLUE}ℹ️  ✅ وُجد install.sh في: $INSTALL_DIR${NC}"

cd "$INSTALL_DIR"
echo -e "${BLUE}ℹ️  📁 تشغيل من: $INSTALL_DIR${NC}"

# تشغيل المثبت المحلي (بدون صلاحيات root)
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}❌ لا تشغل هذا المثبت كـ root${NC}"
    echo -e "${YELLOW}💡 شغله كمستخدم عادي وسيتولى sudo/pkexec الصلاحيات.${NC}"
    exit 1
fi

# يفضل استخدام pkexec إن توفر
if command -v pkexec >/dev/null 2>&1; then
    echo -e "${BLUE}ℹ️  🔐 تشغيل عبر pkexec (GUI)...${NC}"
    pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY bash "$INSTALL_PATH"
else
    echo -e "${BLUE}ℹ️  🔐 تشغيل عبر sudo...${NC}"
    bash "$INSTALL_PATH"
fi

# تنظيف الملفات المؤقتة
echo -e "${YELLOW}ℹ️  تنظيف الملفات المؤقتة...${NC}"
rm -rf "$TMP_DIR"

echo -e "${GREEN}🎉 تم التثبيت بنجاح عبر المثبت عن بُعد!${NC}"
