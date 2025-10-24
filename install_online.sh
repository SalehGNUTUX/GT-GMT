#!/usr/bin/env bash
# install_online.sh — ذكي، آمن، يقوم بتنزيل مشروع GT-GMT ثم ينفِّذ install.sh محليًا
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-GMT/main/install_online.sh)
set -euo pipefail
IFS=$'\n\t'

REPO="https://github.com/SalehGNUTUX/GT-GMT.git"
CLONE_SUBPATH="GT-GMT/GT-GMT"   # مسار السكربت داخل المستودع بعد الاستنساخ
INSTALL_SCRIPT="install.sh"

# Helpers
echoinfo(){ printf "ℹ️  %s\n" "$*"; }
echowarn(){ printf "⚠️  %s\n" "$*"; }
echoerr(){ printf "❌ %s\n" "$*" >&2; }

# إنشاء مجلد مؤقت آمن
TMPDIR="$(mktemp -d -t gt-gmt-install-XXXXXXXX)" || { echoerr "فشل إنشاء مجلد مؤقت"; exit 1; }
cleanup(){ rc=$?; echoinfo "تنظيف..."; rm -rf "$TMPDIR"; exit $rc; }
trap cleanup INT TERM EXIT

echoinfo "🔽 تنزيل المستودع إلى المجلد المؤقت..."
# حاول استخدام git clone (أفضل) وإلا استخدم curl+unzip tarball كبديل
if command -v git >/dev/null 2>&1; then
    if git clone --depth 1 "$REPO" "$TMPDIR/repo" 2>/dev/null; then
        echoinfo "✅ تم الاستنساخ."
    else
        echoerr "فشل git clone."
        exit 1
    fi
else
    echowarn "git غير موجود، سأحاول تنزيل الأرشيف (tar.gz) بدلاً منه."
    ARCHIVE_URL="${REPO%%.git}/archive/refs/heads/main.tar.gz"
    if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        curl -fsSL "$ARCHIVE_URL" -o "$TMPDIR/repo.tar.gz" || { echoerr "فشل تنزيل الأرشيف"; exit 1; }
        tar -xzf "$TMPDIR/repo.tar.gz" -C "$TMPDIR" || { echoerr "فشل فك الأرشيف"; exit 1; }
        # تحديد المجلد المستخرج (عادة Repo-main)
        EXTRACTED_DIR="$(find "$TMPDIR" -maxdepth 1 -type d -name '*-main' | head -n1)"
        if [[ -z "$EXTRACTED_DIR" ]]; then
            echoerr "لم أجد محتويات المستودع بعد فك الأرشيف."
            exit 1
        fi
        mv "$EXTRACTED_DIR" "$TMPDIR/repo"
        echoinfo "✅ تم تنزيل الأرشيف وفكّه."
    else
        echoerr "لا يوجد git أو curl/tar على النظام — لا أستطيع تنزيل المستودع."
        exit 1
    fi
fi

# مسار السكربت داخل المجلد الذي تم تنزيله
TARGET_DIR="$TMPDIR/repo/$CLONE_SUBPATH"
INSTALL_PATH="$TARGET_DIR/$INSTALL_SCRIPT"

if [[ ! -d "$TARGET_DIR" ]]; then
    echoerr "المجلد المتوقع للمشروع غير موجود: $TARGET_DIR"
    exit 1
fi

if [[ ! -f "$INSTALL_PATH" ]]; then
    echoerr "❌ لم أجد $INSTALL_SCRIPT في: $TARGET_DIR"
    echoerr "المسارات المتوفرة داخل $TARGET_DIR:"
    ls -la "$TARGET_DIR" || true
    exit 1
fi

# اجعل السكربت قابلًا للتنفيذ
chmod +x "$INSTALL_PATH"

# وظيفة لاكتشاف أفضل أداة لرفع الصلاحيات
choose_elevator(){
    local -a cand=(pkexec kdesudo gksudo sudo)
    for c in "${cand[@]}"; do
        if command -v "$c" >/dev/null 2>&1; then
            echo "$c" && return 0
        fi
    done
    return 1
}

ELEVATOR="$(choose_elevator || true)"

echoinfo "📁 المجلد المؤقت: $TARGET_DIR"
echoinfo "📄 السكربت الذي سيتم تنفيذه: $INSTALL_PATH"

# تنفيذ السكربت بمسار كامل (realpath) وبطريقة تضمن أن الملفات النسبية تعمل
REAL_INSTALL_PATH="$(realpath "$INSTALL_PATH")"
REAL_TARGET_DIR="$(realpath "$TARGET_DIR")"

# نقوم بتشغيل السكربت من داخل مجلده لضمان أن المسارات النسبية صحيحة
cd "$REAL_TARGET_DIR"

# إذا كانت البيئة رسومية ونوجد pkexec نفضل استخدامه مع مسار كامل
if [[ -n "${DISPLAY-}" ]] || [[ -n "${WAYLAND_DISPLAY-}" ]] || [[ "${XDG_SESSION_TYPE-}" =~ (wayland|x11) ]]; then
    if [[ "$ELEVATOR" == "pkexec" ]]; then
        echoinfo "🔐 تشغيل $INSTALL_SCRIPT عبر pkexec (GUI elevation)..."
        exec pkexec env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" "$REAL_INSTALL_PATH" "$@"
    elif [[ "$ELEVATOR" == "kdesudo" || "$ELEVATOR" == "gksudo" ]]; then
        echoinfo "🔐 تشغيل $INSTALL_SCRIPT عبر $ELEVATOR..."
        exec "$ELEVATOR" "$REAL_INSTALL_PATH" "$@"
    fi
fi

# خلاف ذلك أو كفشل الرجوع إلى sudo في الطرفية
if [[ "$ELEVATOR" == "sudo" ]]; then
    echoinfo "🔐 تشغيل $INSTALL_SCRIPT عبر sudo..."
    exec sudo "$REAL_INSTALL_PATH" "$@"
fi

# في حال لم نجد أدوات رفع صلاحيات، حاول التشغيل مباشرة (قد يفشل إذا تطلب root)
echowarn "تعذر العثور على أدوات رفع صلاحيات رسومية؛ سأحاول تشغيل السكربت مباشرة. إذا فشل، شغِّل: sudo $REAL_INSTALL_PATH"
exec "$REAL_INSTALL_PATH" "$@"
