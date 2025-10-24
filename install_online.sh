#!/usr/bin/env bash
# install_online.sh — ذكي: يكتشف مكان install.sh أو gt-gmt.sh داخل المستودع ثم ينفذ المثبّت محليًا
set -euo pipefail
IFS=$'\n\t'

REPO="https://github.com/SalehGNUTUX/GT-GMT.git"
INSTALL_SCRIPT_NAME="install.sh"
FALLBACK_SCRIPT_NAME="gt-gmt.sh"

echoinfo(){ printf "ℹ️  %s\n" "$*"; }
echowarn(){ printf "⚠️  %s\n" "$*"; }
echoerr(){ printf "❌ %s\n" "$*" >&2; }

TMPDIR="$(mktemp -d -t gt-gmt-install-XXXXXXXX)" || { echoerr "فشل إنشاء مجلد مؤقت"; exit 1; }
cleanup(){ rc=$?; echoinfo "تنظيف..."; rm -rf "$TMPDIR"; exit $rc; }
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

# حاول إيجاد install.sh أولاً، ثم gt-gmt.sh كاحتياطي
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

if [[ -n "${DISPLAY-}" ]] || [[ -n "${WAYLAND_DISPLAY-}" ]] || [[ "${XDG_SESSION_TYPE-}" =~ (wayland|x11) ]]; then
    if [[ "$ELEVATOR" == "pkexec" ]]; then
        echoinfo "🔐 تشغيل عبر pkexec (GUI)..."
        exec pkexec env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" "$REAL_INSTALL_PATH" "$@"
    elif [[ "$ELEVATOR" == "kdesudo" || "$ELEVATOR" == "gksudo" ]]; then
        echoinfo "🔐 تشغيل عبر $ELEVATOR..."
        exec "$ELEVATOR" "$REAL_INSTALL_PATH" "$@"
    fi
fi

if [[ "$ELEVATOR" == "sudo" ]]; then
    echoinfo "🔐 تشغيل عبر sudo..."
    exec sudo "$REAL_INSTALL_PATH" "$@"
fi

echowarn "تعذر العثور على أدوات رفع صلاحيات رسومية؛ سأحاول تشغيل السكربت مباشرة. إذا فشل، شغِّل: sudo $REAL_INSTALL_PATH"
exec "$REAL_INSTALL_PATH" "$@"
