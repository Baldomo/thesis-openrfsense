# OpenRFSense Bachelor Thesis
This repository contains all the source code and tooling required to build my bachelor's thesis book. This project is mainly powered by the [Quarto](https://quarto.org/) publishing system and a custom LaTeX template originally distributed by the University of Trento.

The code should be pulled with:
```shell
$ git clone --recursive https://github.com/Baldomo/thesis-openrfsense
```

[VSCodium](https://vscodium.com/)/Visual Studio Code was used for development and writing, with the Quarto editor extension.

## Building
[`makesh`](https://github.com/Baldomo/makesh) is used to build the project and provide tooling under the `bin/` directory. The following command will fetch all required dependencies and build the final PDF in the `output/` directory:
```shell
$ ./make
```

See `./make --list` to get a more detailed list of possible targets.
