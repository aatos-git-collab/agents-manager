#!/bin/bash
# Full validation: CSS health check + build + browser verification
# This is the pre-delivery gate for pawnshop

PROJECT_DIR="/root/risheng-pawnshop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  Pawnshop CSS Full Validation"
echo "=========================================="
echo ""

cd "$PROJECT_DIR"

# Step 1: CSS Health Check
echo "[1/4] Running CSS health check..."
if ! "$SCRIPT_DIR/check.sh"; then
    echo ""
    echo "CSS health check FAILED. Running auto-fix..."
    "$SCRIPT_DIR/fix.sh"

    echo ""
    echo "Re-running CSS health check after fix..."
    if ! "$SCRIPT_DIR/check.sh"; then
        echo ""
        echo "✗ Auto-fix did not resolve all issues. Manual intervention required."
        exit 1
    fi
fi
echo "✓ CSS health check passed"
echo ""

# Step 2: Build check
echo "[2/4] Running production build..."
if ! npm run build > /tmp/pawnshop-build.log 2>&1; then
    echo ""
    echo "✗ Build FAILED. Check /tmp/pawnshop-build.log for details."
    tail -50 /tmp/pawnshop-build.log
    exit 1
fi
echo "✓ Build passed"
echo ""

# Step 3: Start dev server briefly to verify
echo "[3/4] Starting dev server for browser verification..."
npm run dev > /tmp/pawnshop-dev.log 2>&1 &
DEV_PID=$!

# Wait for server to start
sleep 15

# Check if server is running
if ! kill -0 $DEV_PID 2>/dev/null; then
    echo "✗ Dev server failed to start"
    cat /tmp/pawnshop-dev.log
    exit 1
fi

echo "✓ Dev server started (PID: $DEV_PID)"
echo ""

# Step 4: Browser verification with Playwright
echo "[4/4] Running browser verification..."
python3 << 'PYEOF'
from playwright.sync_api import sync_playwright

try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()

        console_errors = []
        page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)
        page_errors = []
        page.on("pageerror", lambda err: page_errors.append(str(err)))

        try:
            response = page.goto("http://localhost:3000", timeout=30000)
            page.wait_for_timeout(3000)

            print(f"  HTTP Status: {response.status}")
            print(f"  Page Title: {page.title()}")

            if console_errors:
                print(f"  Console Errors: {len(console_errors)}")
                for err in console_errors[:5]:
                    print(f"    - {err}")
            else:
                print(f"  Console Errors: None")

            if page_errors:
                print(f"  Page Errors: {len(page_errors)}")
                for err in page_errors[:5]:
                    print(f"    - {err}")
            else:
                print(f"  Page Errors: None")

            # Final verdict
            if response.status == 200 and not console_errors and not page_errors:
                print("\n✓ BROWSER VERIFICATION PASSED")
            else:
                print("\n✗ BROWSER VERIFICATION FAILED")
                exit(1)

        except Exception as e:
            print(f"✗ Browser test error: {e}")
            exit(1)
        finally:
            browser.close()
except Exception as e:
    print(f"✗ Playwright error: {e}")
    exit(1)
PYEOF

BROWSER_RESULT=$?

# Cleanup: stop dev server
echo ""
echo "Stopping dev server..."
kill $DEV_PID 2>/dev/null || true
wait $DEV_PID 2>/dev/null || true

if [ $BROWSER_RESULT -ne 0 ]; then
    echo ""
    echo "✗ Browser verification FAILED"
    exit 1
fi

echo ""
echo "=========================================="
echo "  ✓ ALL VALIDATIONS PASSED"
echo "=========================================="
echo ""
echo "  - CSS health check: PASS"
echo "  - Production build: PASS"
echo "  - Dev server: PASS"
echo "  - Browser verification: PASS"
echo ""
echo "Ready for deployment!"
