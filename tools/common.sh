# Shared by print.sh, ref-print.sh and make-plain.sh (sourced, not run).

# find_chrome: sets CHROME_BIN to Chrome, Chromium or Playwright's headless_shell; exits if none.
find_chrome() {
    CHROME_BIN=""
    if command -v google-chrome &> /dev/null; then
        CHROME_BIN="google-chrome"
    elif command -v chromium &> /dev/null; then
        CHROME_BIN="chromium"
    else
        CHROME_BIN=$(find "$HOME/.cache/ms-playwright" -name "headless_shell" -type f 2>/dev/null | head -n 1)
    fi
    if [ -z "$CHROME_BIN" ]; then
        echo "Error: No Chrome or headless_shell binary found."
        exit 1
    fi
}

# after_print <name> <region> [variant] [location] [code]: what every print ends with.
# Reads <name>.pdf back as text (check-extract.sh), then writes the plain versions,
# <name>.docx and <name>-plain.pdf (make-plain.sh), which are checked the same way.
# Returns non-zero when a check or a step failed; the files that were made are kept.
after_print() {
    local NAME=$1 ARGS=(--region "$2") STATUS=0
    [ -n "$3" ] && ARGS+=(--variant "$3")
    [ -n "$4" ] && ARGS+=(--location "$4")
    [ -n "$5" ] && ARGS+=(--code "$5")
    ./check-extract.sh "$NAME.pdf" "${ARGS[@]}" || STATUS=1
    ./make-plain.sh "$NAME" "${ARGS[@]}" || STATUS=1
    return $STATUS
}
