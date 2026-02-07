#!/bin/bash
set -e
cd "$(dirname "$0")/../.."
moon build --target wasm-gc
cp _build/wasm-gc/release/build/cmd/wasm/wasm.wasm web/public/wasm/psd_fmt.wasm
echo "WASM built and copied to web/public/wasm/psd_fmt.wasm"
