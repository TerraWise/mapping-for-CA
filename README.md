# mapping-for-CA

Generates satellite map images of a farm for client reports:

- **Farm boundary map**: the boundary outlined in blue on Esri satellite imagery.
- **Historical planting map**: the same, plus historical planting in yellow (only if a planting layer is supplied).

Each map has a legend, a scale bar, a north arrow and the TerraWise logo, and is saved as a PNG in `map-pic/`.

The maps are built in R with leaflet, saved as HTML, and screenshotted by headless Chromium through Playwright (Python, called from R via reticulate).

## Requirements

- **R 4.6** (the version recorded in `renv.lock`)
- **Python 3.14**, used by renv to create the project's virtualenv. On Ubuntu/Debian also install `python3.14-venv`.
- **pandoc** on your `PATH`, which is used to save self-contained HTML. It comes with RStudio and Quarto, or install it with `sudo apt install pandoc` or `conda install pandoc`.

## One-time setup

From the project root:

```bash
# 1. Restore the R packages and the Python virtualenv (playwright etc. from requirements.txt)
Rscript -e 'renv::restore()'

# 2. Download the Chromium build Playwright uses
renv/python/virtualenvs/renv-python-3.14/bin/python -m playwright install chromium
```

On a fresh Linux machine, Chromium may also need system libraries. To install them (this uses sudo):
`renv/python/virtualenvs/renv-python-3.14/bin/python -m playwright install-deps chromium`.

Also check that `assets/Logo.png` and `assets/north_arrow.png` are present. Without them, the maps show broken-image boxes where the logo and north arrow should be, and no error is raised.

## Input data

Put the client's shapefiles in `spatial/`. This folder is git-ignored, so client data never gets committed.

| Folder | Required? | Contents |
|---|---|---|
| `spatial/boundary/` | Yes | Exactly **one** `.shp` (with its `.dbf`, `.shx`, `.prj`, …): the farm boundary |
| `spatial/planting/` | No | At most **one** `.shp`: historical planting. Leave the folder empty or remove it to skip the planting map |

Layers can be in any coordinate system; they are reprojected to WGS84.

### Grouped maps

If the boundary has a column named `group` (any capitalisation), you get **one set of maps per group** instead of a single whole-farm set:

- Each group's maps are centred on that group.
- Planting is clipped to the group.
- A group with no planting gets only a boundary map.
- Features with an empty group are left out, with a warning.

## Running

Run from the project root, so that renv activates:

```bash
Rscript main.R
```

All settings are optional flags:

| Flag | Default | Description |
|---|---|---|
| `--title` | `Client name` | Legend title |
| `--zoom` | `12` | Map zoom level, a whole number from 1 to 18 (higher is closer) |
| `--width` | `1000` | PNG width in pixels (100–5000) |
| `--height` | `1000` | PNG height in pixels (100–5000) |
| `--lon-offset` | `0` | Move the map centre east (+) or west (−), in degrees |
| `--lat-offset` | `0` | Move the map centre north (+) or south (−), in degrees |

Example:

```bash
Rscript main.R --title "Example Farm" --zoom 13 --width 1600 --height 900 \
    --lon-offset 0.01 --lat-offset -0.005
```

`Rscript main.R --help` lists the flags. Invalid values stop the script with a message saying what's wrong.

The offsets apply to every map; with grouped maps, each group's centre moves by the same amount. As a rough guide, 0.01° is about 1 km.

You can also `source("main.R")` from an interactive R session. There are no flags in that case, so the defaults are used.

## Output

PNGs are written to `map-pic/` (git-ignored) and overwrite earlier runs:

| Case | Files |
|---|---|
| No `group` column | `farm_boundary.png`, `historical_planting.png` |
| With groups | `farm_boundary_<group>.png`, `historical_planting_<group>.png` |

In group file names, anything other than letters and digits becomes `_` (for example `East-Block` becomes `farm_boundary_East_Block.png`). The script stops if two groups would end up with the same file name.

## Project layout

```
main.R                          Entry point: flags -> read inputs -> build maps -> screenshot
internal/R/cli.R                Command-line flags and validation
internal/R/spatial.R            Reading shapefiles, map centre, clipping planting to a group
internal/R/map.R                Leaflet map, legend styling, saving the HTML
internal/R/colour.R             TerraWise colours
internal/py/map_utils_playwright.py   Screenshots the HTML maps with headless Chromium
assets/                         Logo and north arrow drawn on every map
renv.lock, requirements.txt     Pinned R and Python dependencies
```

## Troubleshooting

- **`No module named pip`** when renv sets up Python: the virtualenv was created without pip. To fix it, run
  `renv/python/virtualenvs/renv-python-3.14/bin/python -m ensurepip --upgrade`, then re-run `renv::restore()`.
- **pandoc errors when saving the HTML**: pandoc isn't on your `PATH` (see Requirements).
- **Playwright reports that the browser executable doesn't exist**: run the `playwright install chromium` step from setup.
- **Warning that `numpy` isn't installed**: this is harmless. reticulate asks for numpy by default, but this project doesn't use it.
- **"tiles still loading after 30 s"**: the satellite imagery was slow to load, so that PNG may have blank tiles. Re-run the script.
- **After adding or removing R packages**: run `renv::snapshot()` so `renv.lock` stays up to date.
