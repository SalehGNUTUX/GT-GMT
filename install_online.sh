#!/usr/bin/env bash
# install_online.sh — ذكي ومُصلح: يشتغل كمستخدم عادي، ثم يصلح الأيقونات والأذونات إن لزم
set -euo pipefail
IFS=$'\n\t'

REPO="https://github.com/SalehGNUTUX/GT-GMT.git"
INSTALL_SCRIPT_NAME="install.sh"
FALLBACK_SCRIPT_NAME="gt-gmt.sh"

# مخرجات ملونة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echoinfo(){ printf "${BLUE}ℹ️  %s${NC}\n" "$*"; }
echowarn(){ printf "${YELLOW}⚠️  %s${NC}\n" "$*"; }
echoerr(){ printf "${RED}❌ %s${NC}\n" "$*" >&2; }

TMPDIR="$(mktemp -d -t gt-gmt-install-XXXXXXXX)" || { echoerr "فشل إنشاء مجلد مؤقت"; exit 1; }
cleanup(){ rc=$?; echoinfo "تنظيف..."; rm -rf "$TMPDIR"; exit $rc; }
trap cleanup INT TERM EXIT

# مسارات الهدف المتوافقة مع المثبت المحلي
TARGET_INSTALL_DIR="/usr/local/share/gt-gmt"
TARGET_BINARY="/usr/local/bin/gt-gmt"
TARGET_ICONS_DIR="/usr/share/icons/hicolor"
TARGET_DESKTOP="/usr/share/applications/gt-gmt.desktop"

echoinfo "🔽 تنزيل المستودع إلى المجلد المؤقت..."
if command -v git >/dev/null 2>&1; then
    git clone --depth 1 "$REPO" "$TMPDIR/repo" >/dev/null 2>&1 || { echoerr "فشل git clone."; exit 1; }
    echoinfo "✅ تم الاستنساخ."
else
    echowarn "git غير متوفر، سأحاول تنزيل الأرشيف..."
    ARCHIVE_URL="${REPO%%.git}/archive/refs/heads/main.tar.gz"
    if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        curl -fsSL "$ARCHIVE_URL" -o "$TMPDIR/repo.tar.gz" || { echoerr "فشل تنزيل الأرشيف"; exit 1; }
        tar -xzf "$TMPDIR/repo.tar.gz" -C "$TMPDIR" || { echoerr "فشل فك الأرشيف"; exit 1; }
        EXTRACTED_DIR="$(find "$TMPDIR" -maxdepth 1 -type d -name '*-main' | head -n1)"
        if [[ -z "$EXTRACTED_DIR" ]]; then echoerr "لم أجد محتويات المستودع بعد فك الأرشيف."; exit 1; fi
        mv "$EXTRACTED_DIR" "$TMPDIR/repo"
        echoinfo "✅ تم تنزيل الأرشيف وفكّه."
    else
        echoerr "لا يوجد git أو curl/tar على النظام — لا أستطيع تنزيل المستودع."
        exit 1
    fi
fi

# العثور على المثبّت داخل الشجرة
FOUND_INSTALL_PATH="$(find "$TMPDIR/repo" -type f -name "$INSTALL_SCRIPT_NAME" -print -quit || true)"
FOUND_FALLBACK_PATH="$(find "$TMPDIR/repo" -type f -name "$FALLBACK_SCRIPT_NAME" -print -quit || true)"

if [[ -n "$FOUND_INSTALL_PATH" ]]; then
    TARGET_DIR="$(dirname "$FOUND_INSTALL_PATH")"
    INSTALL_PATH="$FOUND_INSTALL_PATH"
    echoinfo "✅ وُجد $INSTALL_SCRIPT_NAME في: $TARGET_DIR"
elif [[ -n "$FOUND_FALLBACK_PATH" ]]; then
    TARGET_DIR="$(dirname "$FOUND_FALLBACK_PATH")"
    INSTALL_PATH="$FOUND_FALLBACK_PATH"
    echoinfo "⚠️ لم أجد $INSTALL_SCRIPT_NAME، لكن وُجد $FALLBACK_SCRIPT_NAME في: $TARGET_DIR"
else
    echoerr "❌ لم أجد $INSTALL_SCRIPT_NAME أو $FALLBACK_SCRIPT_NAME داخل المستودع."
    echoerr "محتويات الجذر داخل المجلد الذي نُسخ: "
    ls -la "$TMPDIR/repo" || true
    exit 1
fi

chmod +x "$INSTALL_PATH"
REAL_INSTALL_PATH="$(realpath "$INSTALL_PATH")"
REAL_TARGET_DIR="$(realpath "$TARGET_DIR")"

echoinfo "📁 تشغيل من: $REAL_TARGET_DIR"
cd "$REAL_TARGET_DIR"

# فتح الطرفية إن لم تكن تفاعلية
spawn_terminal_and_run(){
    local -a terminals=( "gnome-terminal --" "konsole -e" "xfce4-terminal -e" "mate-terminal -e" "tilix -e" "xterm -e" "alacritty -e" "kitty -e" )
    local t exe
    for t in "${terminals[@]}"; do
        exe=$(echo "$t" | awk '{print $1}')
        if command -v "$exe" >/dev/null 2>&1; then
            # تعامُل عام مع جميع المحاكيات: نفّذ bash -c 'cd ...; bash install.sh "$@"; read'
            $t bash -c "cd '$REAL_TARGET_DIR' && bash '$REAL_INSTALL_PATH' \"$@\"; echo; read -p 'اضغط Enter للاغلاق...'"
            return 0
        fi
    done
    return 1
}

# تشغيل المثبّت المحلي (كمستخدم عادي أو داخل طرفية)
if [[ -t 1 ]]; then
    echoinfo "🔧 تشغيل المثبّت كمستخدم عادي (في نفس الطرفية)..."
    bash "$REAL_INSTALL_PATH" "$@"
else
    if spawn_terminal_and_run "$@"; then
        echoinfo "✅ شغّلت المثبّت داخل محاكي طرفية."
    else
        echowarn "لا يوجد محاكي طرفية متاح؛ سأشغّل المثبّت مباشرة كمحاولة أخيرة (قد يطلب sudo في الطرفية)."
        bash "$REAL_INSTALL_PATH" "$@"
    fi
fi

# --- بعد انتهاء install.sh: إجراءات تصحيحية لضمان توافق النتيجة مع المثبت المحلي ---

echoinfo "🔍 فحص حالة التثبيت وإصلاح المشكلات الشائعة..."

# 1) تأكد من وجود اللّبنات الأساسية
installed_ok=true
if [[ ! -d "$TARGET_INSTALL_DIR" ]]; then
    echowarn "مجلد التثبيت $TARGET_INSTALL_DIR غير موجود. قد فشل تثبيت الملفات الأساسية."
    installed_ok=false
fi

if [[ ! -f "$TARGET_BINARY" ]]; then
    echowarn "الملف التنفيذي $TARGET_BINARY غير موجود."
    installed_ok=false
fi

# 2) إن لم تُثبّت الأيقونات — نفّذ نسخًا احتياطيًا من مجلد الأيقونات الموجود في المستودع إن وُجد
icons_source_dir="$REAL_TARGET_DIR/gt-gmt-icons"
found_icon=false
# تحقق إذا كانت أيقونات موجودة في نظام
if find "$TARGET_ICONS_DIR" -type f -name "gt-gmt.*" | grep -q . >/dev/null 2>&1; then
    echoinfo "✅ تم العثور على أيقونات مثبتة في النظام."
    found_icon=true
fi

if [[ "$found_icon" = false ]]; then
    if [[ -d "$icons_source_dir" ]]; then
        echoinfo "🔧 لم أجد أيقونات مثبتة، سأقوم بنسخ الأيقونات من المستودع إلى $TARGET_ICONS_DIR (يتطلب sudo)..."
        # ننسخ كل هيكل الأيقونات إذا أمكن
        sudo mkdir -p "$TARGET_ICONS_DIR"
        # انسخ كل شيء ضمن gt-gmt-icons إلى /usr/share/icons/hicolor/ مع الاحتفاظ بالمسارات
        # افتراض: هيكل gt-gmt-icons/{16x16,32x32,...,scalable}
        for sub in "$icons_source_dir"/*; do
            if [[ -d "$sub" ]]; then
                base=$(basename "$sub")
                # إذا كان مجلد scalable، انسخ كامل المجلد إلى scalable/apps
                if [[ "$base" == "scalable" ]]; then
                    sudo mkdir -p "$TARGET_ICONS_DIR/scalable/apps"
                    sudo cp -r "$sub"/* "$TARGET_ICONS_DIR/scalable/apps/" 2>/dev/null || true
                else
                    sudo mkdir -p "$TARGET_ICONS_DIR/${base}/apps"
                    # انسخ الملفات المتاحة بصيغ png/svg/xpm
                    sudo cp -r "$sub"/* "$TARGET_ICONS_DIR/${base}/apps/" 2>/dev/null || true
                fi
            fi
        done

        # في حال لم يكن هناك مجلد منظم، حاول نسخ أي ملف gt-gmt.* داخل المجلد مباشرة
        if ! find "$TARGET_ICONS_DIR" -type f -name "gt-gmt.*" | grep -q . >/dev/null 2>&1; then
            echowarn "لم أتمكن من العثور على أيقونات بعد النسخ. أتحقق من وجود ملفات أيقونة في المستودع..."
            if find "$icons_source_dir" -type f -name "gt-gmt.*" | grep -q . >/dev/null 2>&1; then
                # انسخ جميع الملفات المطابقة إلى أحجام افتراضية
                for f in $(find "$icons_source_dir" -type f -name "gt-gmt.*"); do
                    for size in 16x16 32x32 48x48 64x64 128x128 256x256; do
                        sudo mkdir -p "$TARGET_ICONS_DIR/${size}/apps"
                        sudo cp "$f" "$TARGET_ICONS_DIR/${size}/apps/$(basename "$f")" 2>/dev/null || true
                    done
                done
            fi
        fi

        # تحديث كاش الأيقونات
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            echoinfo "🔄 تحديث كاش الأيقونات..."
            sudo gtk-update-icon-cache -f "$TARGET_ICONS_DIR" >/dev/null 2>&1 || true
        fi

        # تحقق مجدداً
        if find "$TARGET_ICONS_DIR" -type f -name "gt-gmt.*" | grep -q . >/dev/null 2>&1; then
            echoinfo "✅ الأيقونات مُثبتة الآن."
            found_icon=true
        else
            echowarn "فشل تثبيت الأيقونات تلقائيًا."
        fi
    else
        echowarn "لا يوجد مجلد gt-gmt-icons في المستودع، تخطّي خطوة الأيقونات."
    fi
fi

# 3) تأكد من أذونات الملف التنفيذي ونمط التشغيل (يجب أن يعمل بدون الحاجة لـ sudo)
if [[ -f "$TARGET_BINARY" ]]; then
    echoinfo "🔧 تصحيح أذونات الملف التنفيذي $TARGET_BINARY (سيُصبح قابلًا للتشغيل من أي مستخدم)..."
    # تأكد من وجود الملف ونظّم الأذونات
    sudo chown root:root "$TARGET_BINARY" >/dev/null 2>&1 || true
    sudo chmod 755 "$TARGET_BINARY" >/dev/null 2>&1 || true
    # تأكد أن مجلد التثبيت قابِل للقراءة من الجميع
    if [[ -d "$TARGET_INSTALL_DIR" ]]; then
        sudo chmod -R 755 "$TARGET_INSTALL_DIR" >/dev/null 2>&1 || true
    fi
fi

# 4) تأكد من ملف desktop إن لم يكن مُثبتًا قم بنسخه من المستودع إن وُجد
if [[ ! -f "$TARGET_DESKTOP" ]]; then
    if [[ -f "$REAL_TARGET_DIR/gt-gmt.desktop" ]]; then
        echoinfo "📋 نسخ ملف .desktop إلى $TARGET_DESKTOP (يتطلب sudo)..."
        sudo mkdir -p "$(dirname "$TARGET_DESKTOP")"
        sudo cp "$REAL_TARGET_DIR/gt-gmt.desktop" "$TARGET_DESKTOP" 2>/dev/null || true
        sudo chmod 644 "$TARGET_DESKTOP" >/dev/null 2>&1 || true
        if command -v update-desktop-database >/dev/null 2>&1; then
            echoinfo "🔄 تحديث قاعدة بيانات التطبيقات..."
            sudo update-desktop-database /usr/share/applications/ >/dev/null 2>&1 || true
        fi
    fi
fi

# نهاية الفحص العام
if [[ "$installed_ok" = true ]]; then
    echoinfo "${GREEN}🎉 يبدو أن التثبيت اكتمل بنجاح.${NC}"
else
    echowarn "التثبيت قد اكتمل لكن وُجدت مشاكل؛ حاول تشغيل 'gt-gmt' من الطرفية الآن. إن احتجت، أرسل لي المخرجات لأصلحها."
fi

echoinfo "📋 نصيحة: لتشغيل الأداة من الطرفية بدون sudo: simplement اكتب 'gt-gmt' — إذا ظهرت رسالة خطأ ألصقها هنا."
