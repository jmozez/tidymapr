# GeoSpaX recipes: read, validate, run and write

A recipe is a GeoSpaX workflow saved as YAML (format version 1): inputs,
a list of steps that use named tools, and outputs. These functions let
tidymapr and the GeoSpaX desktop GIS share recipes:

- `geo_recipe_read()` reads a recipe file (or YAML text);

- `geo_recipe_validate()` checks it as GeoSpaX does, reporting every
  problem at once before anything runs: the recipe id, unknown steps,
  `${...}` references to steps or inputs that do not exist, missing
  dependencies and circular ones. Steps that exist in GeoSpaX but not in
  tidymapr are listed as such;

- `geo_recipe_run()` runs a recipe in R with tidymapr's tools;

- `geo_recipe()`, `recipe_input()` and `recipe_step()` build a recipe in
  R, and `geo_recipe_write()` saves it for GeoSpaX.

Steps that tidymapr runs:

|  |  |
|----|----|
| GeoSpaX step | tidymapr |
| `io.open` | [`geo_read()`](https://tidymapr.in4metrix.dev/reference/geo-io.md) |
| `interpolate.idw` | [`geo_interpolate()`](https://tidymapr.in4metrix.dev/reference/geo_interpolate.md) (`method = "idw"`) |
| `interpolate.auto` | kriging against IDW by leave-one-out error, with a standard-error map |
| `aggregate.hexbin` | points counted (or summed or averaged) in auto-sized hexagons |
| `stats.hotspots` | [`geo_hotspot()`](https://tidymapr.in4metrix.dev/reference/geo-local.md) (Getis-Ord Gi\*), on hexagon counts when no field is given |
| `automap.style` | the [`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md) rules |
| `export.map` | a [`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md) page saved as PNG, SVG or PDF |
| `export.data` | [`geo_write()`](https://tidymapr.in4metrix.dev/reference/geo-io.md) |
| `export.report` | an HTML report with the maps, every automatic decision and the run log |
| `terrain.derive` | [`geo_raster_terrain()`](https://tidymapr.in4metrix.dev/reference/geo-raster.md) |
| `rs.index` | [`geo_spectral_index()`](https://tidymapr.in4metrix.dev/reference/geo_spectral_index.md) on a raster you give |

Other GeoSpaX steps (device import, LiDAR, 3D scenes, online data
fetches, GRASS/SAGA, AI models) are reported by `geo_recipe_validate()`
and stop `geo_recipe_run()` with a clear message: run those recipes in
GeoSpaX.

Expressions follow GeoSpaX: `${inputs.x}`, `${step.key}`,
`${step.list.0}`, `${run.date}`, `${recipe}`, and fallbacks such as
`${inputs.title ?? Field map}`. A string that is exactly one `${...}`
keeps the referenced value's type.

## Usage

``` r
geo_recipe_read(path)

geo_recipe(id, title = id, description = NULL)

recipe_input(recipe, name, type = "layer", default = NULL, description = NULL)

recipe_step(recipe, id, use, ..., needs = NULL, when = NULL)

geo_recipe_write(x, path)

geo_recipe_validate(x)

geo_recipe_run(
  x,
  inputs = list(),
  dir = tempfile("recipe-run-"),
  quiet = FALSE
)
```

## Arguments

- path:

  Path to a recipe file (`.yaml`, `.yml` or `.json`), or YAML text.

- id, title, description:

  Recipe id (`a-z 0-9 - _`), title and description.

- recipe:

  A recipe to add to.

- name, type, default:

  Input name, type (`"layer"`, `"field"`, `"text"`, ...) and default
  value.

- use:

  GeoSpaX step name, for example `"export.map"`.

- ...:

  Step parameters (the step's `with:`).

- needs, when:

  Extra ordering (step ids) and a run condition.

- x:

  A recipe from `geo_recipe_read()` or `geo_recipe()`.

- inputs:

  Named list of recipe inputs. Layers can be file paths or `sf` /
  `SpatRaster` objects.

- dir:

  Folder for the run's outputs (maps, data, report).

- quiet:

  Suppress progress messages?

## Value

`geo_recipe_read()` and `geo_recipe()`: a `tmr_recipe`.
`geo_recipe_validate()`: a tibble of problems (`severity`, `step`,
`problem`), empty when the recipe is valid. `geo_recipe_run()`: a list
with each step's outputs, the run log and the output folder.
`geo_recipe_write()`: `path`, invisibly.

## See also

[`geo_automap()`](https://tidymapr.in4metrix.dev/reference/geo_automap.md),
[`geo_interpolate()`](https://tidymapr.in4metrix.dev/reference/geo_interpolate.md),
[`geo_hotspot()`](https://tidymapr.in4metrix.dev/reference/geo-local.md)

## Examples

``` r
# A recipe shipped with GeoSpaX: point samples to an interpolated surface
rec <- geo_recipe_read(system.file("recipes/interpolate-samples.yaml", package = "tidymapr"))
rec
#> GeoSpaX recipe "interpolate-samples" (v2): Field samples → interpolated surface
#> (kriging or IDW, automatically)
#> Inputs: layer and field
#> Steps: samples (io.open), surface (interpolate.auto), style_samples
#> (automap.style), map (export.map), uncertainty (export.map), and report
#> (export.report)
#> Outputs: surface, map, uncertainty, and report
geo_recipe_validate(rec)
#> # A tibble: 0 × 3
#> # ℹ 3 variables: severity <chr>, step <chr>, problem <chr>

# Run it on the Meuse river soil samples (zinc, mg/kg; shipped with terra)
meuse <- terra::unwrap(readRDS(system.file("ex/meuse.rds", package = "terra")))
samples <- sf::st_as_sf(meuse, coords = c("x", "y"), crs = 28992)
out <- geo_recipe_run(rec, inputs = list(layer = samples, field = "zinc"))
#> samples (io.open)
#> surface (interpolate.auto)
#> style_samples (automap.style)
#> map (export.map)
#> uncertainty (export.map)
#> report (export.report)
out$surface$method_label
#> [1] "ordinary kriging, exponential variogram"
list.files(out$dir)
#> [1] "map.png"         "report.html"     "uncertainty.png"

# Build a recipe in R and save it for GeoSpaX
r <- geo_recipe("zinc-hotspots", "Zinc hot spots") |>
  recipe_input("layer", "layer", description = "soil samples") |>
  recipe_step("samples", "io.open", layer = "${inputs.layer}") |>
  recipe_step("hot", "stats.hotspots", layer = "${samples.layer}", field = "zinc") |>
  recipe_step("map", "export.map", layers = list("${hot.layer}"), scale_bar = "checker")
geo_recipe_validate(r)
#> # A tibble: 0 × 3
#> # ℹ 3 variables: severity <chr>, step <chr>, problem <chr>
geo_recipe_write(r, tempfile(fileext = ".yaml"))
```
