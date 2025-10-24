#!/usr/bin/env bash
# install_online.sh — نسخة ذكية متوافقة مع جميع تراكيب المستودع
# تعمل كمستخدم عادي وتتكامل مع المثبّت المحلي (install.sh)

set -euo pipefail
IFS=$'\n\t'

REPO="https://github.com/SalehGNUTUX/GT-GMT.git"
INSTALL_SCRIPT_NAME="install.sh"
FALLBACK_SCRIPT_NAME="gt-gmt.sh"

echoinfo(){ printf "ℹ️  %s\n" "$*"; }
echowarn(){ printf "⚠️  %s\n" "$*"; }
echoerr(){ printf "❌ %s\n" "$*" >&2; }

TMPDIR="$(mktemp -d -t gt-gmt-install-XXXXXXXX)" || { echoerr "فشل إنشاء مجلد مؤقت"; exit 1; }
cleanup(){ rc=$?; echoinfo "🧹 تنظيف..."; rm -rf "$TMPDIR"; exit $rc; }
trap cleanup INT TERM EXIT

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

# 📦 تحديد المسار الصحيح داخل المستودع
POSSIBLE_DIRS=(
    "$TMPDIR/repo/GT-GMT"
    "$TMPDIR/repo/GT-GMT/GT-GMT"
)

TARGET_DIR=""
for d in "${POSSIBLE_DIRS[@]}"; do
    if [[ -f "$d/$INSTALL_SCRIPT_NAME" ]]; then
        TARGET_DIR="$d"
        break
    fi
done

if [[ -z "$TARGET_DIR" ]]; then
    echoerr "❌ لم أجد $INSTALL_SCRIPT_NAME داخل المستودع."
    echoinfo "🧭 محتويات المستودع:"
    find "$TMPDIR/repo" -maxdepth 3 -type f | sed 's/^/   - /'
    exit 1
fi

INSTALL_PATH="$TARGET_DIR/$INSTALL_SCRIPT_NAME"
chmod +x "$INSTALL_PATH"

echoinfo "✅ وُجد المثبّت في: $TARGET_DIR"
echoinfo "📁 تشغيل من: $TARGET_DIR"

cd "$TARGET_DIR"

# 🖥️ تشغيل المثبّت في محاكي طرفية (عند غياب واجهة تفاعلية)
spawn_terminal_and_run(){
    local cmd="$*"
    local -a terminals=(
        "gnome-terminal --"
        "konsole -e"
        "xfce4-terminal -e"
        "mate-terminal -e"
        "tilix -e"
        "xterm -e"
        "alacritty -e"
        "kitty -e"
    )
    for t in "${terminals[@]}"; do
        local exe=$(echo "$t" | awk '{print $1}')
        if command -v "$exe" >/dev/null 2>&1; then
            $t bash -c "cd '$TARGET_DIR' && bash '$INSTALL_PATH'; echo; read -p 'اضغط Enter للإغلاق...'"
            return 0
        fi
    done
    return 1
}

# ⚙️ منطق التشغيل الآمن
if [[ -t 1 ]]; then
    echoinfo "🔧 تشغيل المثبّت في الطرفية الحالية..."
    exec bash "$INSTALL_PATH"
else
    if spawn_terminal_and_run; then
        echoinfo "✅ شُغّل المثبّت داخل محاكي طرفية."
        exit 0
    else
        echowarn "⚠️ لم أجد محاكي طرفية مناسب؛ سأشغل المثبّت مباشرة."
        exec bash "$INSTALL_PATH"
    fi
fi
