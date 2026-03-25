### Prerequisites
 - zig 0.15.2

### Instructions
 - Build the editor: `zig build`, run it with `./zig-out/bin/nvim`
 - Complete installation with runtime: `zig build install --prefix ~/.local`
 - Tests:
   + `zig build functionaltest` to run all functionaltests
   + `zig build functionaltest -- test/functional/autocmd/bufenter_spec.lua` to run the tests in one file
   + `zig build unittest` to run all unittests

#### Using system dependencies

See "Available System Integrations" in `zig build -h` to see available system integrations. Enabling an integration, e.g. `zig build -fsys=utf8proc` will use the system's installation of utf8proc.

`zig build --system deps_dir` will enable all integrations and turn off dependency fetching. This requires you to pre-download the dependencies which don't have a system integration into `deps_dir` (at the time of writing these are ziglua and the built-in tree-sitter parsers). You have to create subdirectories whose names are the respective package's hash under `deps_dir` and unpack the dependencies inside that directory - ziglua should go under `deps_dir/zlua-0.1.0-hGRpC1dCBQDf-IqqUifYvyr8B9-4FlYXqY8cl7HIetrC` and so on. Hashes should be taken from `build.zig.zon`.

See the `prepare` function of [this `PKGBUILD`](https://git.sr.ht/~chinmay/nvim_build/tree/26364a4cf9b4819f52a3e785fa5a43285fb9cea2/item/PKGBUILD#L90) for an example.

## Cross-compiling

Cross-compilation is not supported, but we collect notes here for reference (improvements welcome).
Also relevant for webassembly (WASM) build.

- Set `NVIM_HOST_PRG` so that the docs and tags generation works without
  depending on the target binary.
