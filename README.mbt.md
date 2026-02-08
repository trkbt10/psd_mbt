# psd_fmt

A PSD/PSB file parser and viewer written in [MoonBit](https://www.moonbitlang.com/), compiled to WebAssembly.

**[Live Demo](https://trkbt10.github.io/psd_mbt/)**

## Features

- **Full PSD/PSB parsing** — Sections 1-5 of the Adobe Photoshop file format
  - File Header, Color Mode Data, Image Resources, Layer and Mask Information, Image Data
- **47 Additional Layer Information (ALI) keys** — Text layers (TySh), vector masks, smart objects, effects, adjustment layers, and more
- **50 Image Resource IDs** — Grid/guides, thumbnails, ICC profiles, slices, alpha channels, etc.
- **Compression support** — Raw, RLE (PackBits), ZIP, and ZIP with prediction
- **8-bit and 16-bit depth** support
- **PSB (Large Document)** support with 64-bit offsets
- **Round-trip fidelity** — Unknown resources and ALI blocks are preserved as raw bytes
- **Descriptor format** — Recursive parser for PSD's nested Descriptor data structure

### Web Viewer

- **WebGL2 rendering** with multi-layer FBO compositing
- **Layer tree** with visibility toggling
- **Blend mode** support
- **Drag-and-drop** PSD file loading
- **Composite-first loading** — Section 5 composite displayed instantly, per-layer data loaded in background
- **Web Worker** decompression for large channels via browser-native `DecompressionStream`

## Quick Start

### Prerequisites

- [MoonBit](https://www.moonbitlang.com/) (v0.1.20260126+)
- [Node.js](https://nodejs.org/) 22+

### Build & Run

```bash
# Install MoonBit dependencies
moon update

# Type check and run tests
moon check && moon test

# Build WASM
moon build --target wasm-gc
cp _build/wasm-gc/release/build/cmd/wasm/wasm.wasm web/public/wasm/psd_fmt.wasm

# Start the web viewer
cd web && npm install && npm run dev
```

Open `http://localhost:5173` and drop a PSD file onto the page.

## Project Structure

```
psd_fmt/
├── binary/           # Big-endian binary Reader/Writer
├── types/            # Shared types (PsdVersion, ColorMode, Compression, etc.)
├── header/           # Section 1: File Header
├── color_mode_data/  # Section 2: Color Mode Data
├── image_resources/  # Section 3: Image Resources (50 typed resource IDs)
├── layer_and_mask/   # Section 4: Layer and Mask Information (47 ALI keys)
├── image_data/       # Section 5: Composite Image Data
├── compression/      # RLE/ZIP compression and decompression
├── descriptor/       # PSD Descriptor format parser
├── cmd/wasm/         # WASM entry point
├── web/              # React + WebGL2 viewer (Vite, Zustand, Playwright)
└── fixtures/         # Generated PSD test fixtures
```

## Testing

```bash
# MoonBit unit tests (265 tests)
moon test

# Web E2E and visual tests (Playwright)
cd web && npx playwright test

# Validate fixtures against psd-tools
uv run --with psd-tools python scripts/verify.py validate
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Parser/Builder | MoonBit → WebAssembly (wasm-gc) |
| Compression | gmlewis/zlib, gmlewis/flate |
| Frontend | React 19, TypeScript 5.7, Vite 6 |
| Rendering | WebGL2 with FBO compositing |
| State | Zustand |
| Testing | moon test, Playwright, psd-tools |

## License

[Apache-2.0](LICENSE)
