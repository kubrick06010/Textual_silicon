#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-run}"
APP_NAME="Textual"
BUNDLE_ID="com.codeux.apps.textual"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Sources/App/Textual App.xcodeproj"
APP_BUNDLE="$ROOT_DIR/Build Results/Debug/Textual.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/Textual"
LOG_DIR="$ROOT_DIR/.tmp/Script-Logs"
BUILD_LOG="$LOG_DIR/build_and_run.log"
DERIVED_DATA_DIR="$ROOT_DIR/.tmp/DerivedData/TextualApp"
MODULE_CACHE_DIR="$ROOT_DIR/.tmp/ModuleCache"

case "$MODE" in
	run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
		;;
	*)
		echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
		exit 2
		;;
esac

if ! git -C "$ROOT_DIR" submodule status --recursive | awk '$1 ~ /^-/ { missing = 1 } END { exit missing }'; then
	echo "Submodules are missing. Run: git submodule update --init --recursive" >&2
	exit 1
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

mkdir -p "$LOG_DIR" "$DERIVED_DATA_DIR" "$MODULE_CACHE_DIR"

# XCTest embeds its hosted bundle in the Debug app. Never carry that
# development-only payload into a normal runnable build.
rm -rf \
	"$APP_BUNDLE/Contents/PlugIns/TextualCoreTests.xctest" \
	"$APP_BUNDLE/Contents/PlugIns/TextualCoreTests.xctest.dSYM" \
	"$APP_BUNDLE/Contents/PlugIns/TextualCoreTests.app" \
	"$APP_BUNDLE/Contents/PlugIns/TextualCoreTests.app.dSYM"

echo "Building $APP_NAME for arm64…"

if ! xcodebuild \
		-project "$PROJECT_PATH" \
		-scheme "Textual (Debug)" \
		-configuration Debug \
		-arch arm64 \
		-derivedDataPath "$DERIVED_DATA_DIR" \
		CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
		SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
		CODE_SIGN_IDENTITY=- \
		DEVELOPMENT_TEAM= \
		PROVISIONING_PROFILE_SPECIFIER= \
		build >"$BUILD_LOG" 2>&1; then
	echo "Build failed. Last diagnostics:" >&2
	tail -n 80 "$BUILD_LOG" >&2
	exit 1
fi

echo "Build succeeded: $APP_BUNDLE"

if [[ ! -x "$APP_BINARY" ]]; then
	echo "Build succeeded but the app executable was not found at: $APP_BINARY" >&2
	exit 1
fi

open_app() {
	/usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
	run)
		open_app
		;;
	--debug|debug)
		lldb -- "$APP_BINARY"
		;;
	--logs|logs)
		open_app
		/usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
		;;
	--telemetry|telemetry)
		open_app
		/usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
		;;
	--verify|verify)
		open_app
		for _ in {1..10}; do
			if pgrep -x "$APP_NAME" >/dev/null; then
				exit 0
			fi

			sleep 1
		done

		echo "$APP_NAME did not remain running after launch" >&2
		exit 1
		;;
esac
