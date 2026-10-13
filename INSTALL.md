If a package is not provided for your platform, you can build Neovim from source. See [BUILD.md](./BUILD.md) for details.  If you have the [prerequisites](./BUILD.md#build-prerequisites) then building is easy:
```bash
make CMAKE_BUILD_TYPE=Release
sudo make install
```

For Unix-like systems this installs Neovim to `/usr/local`, while for Windows to `C:\Program Files`. Note, however, that this can complicate uninstallation. The following example avoids this by isolating an installation under `$HOME/neovim`:
```bash
rm -r build/  # clear the CMake cache
make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/neovim"
make install
export PATH="$HOME/neovim/bin:$PATH"
```

## Uninstall

There is a CMake target to _uninstall_ after `make install`:

```bash
sudo cmake --build build/ --target uninstall
```

Alternatively, just delete the `CMAKE_INSTALL_PREFIX` artifacts:

```bash
sudo rm /usr/local/bin/nvim
sudo rm -r /usr/local/share/nvim/
```
