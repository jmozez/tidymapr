#' GeoSpaX recipes: read, validate, run and write
#'
#' @description
#' A recipe is a GeoSpaX workflow saved as YAML (format version 1): inputs,
#' a list of steps that use named tools, and outputs. These functions let
#' tidymapr and the GeoSpaX desktop GIS share recipes:
#'
#' * `geo_recipe_read()` reads a recipe file (or YAML text);
#' * `geo_recipe_validate()` checks it as GeoSpaX does, reporting every
#'   problem at once before anything runs: the recipe id, unknown steps,
#'   `${...}` references to steps or inputs that do not exist, missing
#'   dependencies and circular ones. Steps that exist in GeoSpaX but not in
#'   tidymapr are listed as such;
#' * `geo_recipe_run()` runs a recipe in R with tidymapr's tools;
#' * `geo_recipe()`, `recipe_input()` and `recipe_step()` build a recipe in
#'   R, and `geo_recipe_write()` saves it for GeoSpaX.
#'
#' Steps that tidymapr runs:
#'
#' | GeoSpaX step | tidymapr |
#' |---|---|
#' | `io.open` | [geo_read()] |
#' | `interpolate.idw` | [geo_interpolate()] (`method = "idw"`) |
#' | `interpolate.auto` | kriging against IDW by leave-one-out error, with a standard-error map |
#' | `aggregate.hexbin` | points counted (or summed or averaged) in auto-sized hexagons |
#' | `stats.hotspots` | [geo_hotspot()] (Getis-Ord Gi*), on hexagon counts when no field is given |
#' | `automap.style` | the [geo_automap()] rules |
#' | `export.map` | a [geo_automap()] page saved as PNG, SVG or PDF |
#' | `export.data` | [geo_write()] |
#' | `export.report` | an HTML report with the maps, every automatic decision and the run log |
#' | `terrain.derive` | [geo_raster_terrain()] |
#' | `rs.index` | [geo_spectral_index()] on a raster you give |
#'
#' Other GeoSpaX steps (device import, LiDAR, 3D scenes, online data
#' fetches, GRASS/SAGA, AI models) are reported by `geo_recipe_validate()`
#' and stop `geo_recipe_run()` with a clear message: run those recipes in
#' GeoSpaX.
#'
#' Expressions follow GeoSpaX: `${inputs.x}`, `${step.key}`,
#' `${step.list.0}`, `${run.date}`, `${recipe}`, and fallbacks such as
#' `${inputs.title ?? Field map}`. A string that is exactly one `${...}`
#' keeps the referenced value's type.
#'
#' @param path Path to a recipe file (`.yaml`, `.yml` or `.json`), or YAML
#'   text.
#' @param x A recipe from `geo_recipe_read()` or `geo_recipe()`.
#' @param inputs Named list of recipe inputs. Layers can be file paths or
#'   `sf` / `SpatRaster` objects.
#' @param dir Folder for the run's outputs (maps, data, report).
#' @param quiet Suppress progress messages?
#' @return `geo_recipe_read()` and `geo_recipe()`: a `tmr_recipe`.
#'   `geo_recipe_validate()`: a tibble of problems (`severity`, `step`,
#'   `problem`), empty when the recipe is valid. `geo_recipe_run()`: a list
#'   with each step's outputs, the run log and the output folder.
#'   `geo_recipe_write()`: `path`, invisibly.
#' @seealso [geo_automap()], [geo_interpolate()], [geo_hotspot()]
#' @name geo-recipe
#' @examplesIf rlang::is_installed(c("yaml", "sf", "terra", "gstat", "ggplot2"))
#' # A recipe shipped with GeoSpaX: point samples to an interpolated surface
#' rec <- geo_recipe_read(system.file("recipes/interpolate-samples.yaml", package = "tidymapr"))
#' rec
#' geo_recipe_validate(rec)
#'
#' # Run it on the Meuse river soil samples (zinc, mg/kg; shipped with terra)
#' meuse <- terra::unwrap(readRDS(system.file("ex/meuse.rds", package = "terra")))
#' samples <- sf::st_as_sf(meuse, coords = c("x", "y"), crs = 28992)
#' out <- geo_recipe_run(rec, inputs = list(layer = samples, field = "zinc"))
#' out$surface$method_label
#' list.files(out$dir)
#'
#' # Build a recipe in R and save it for GeoSpaX
#' r <- geo_recipe("zinc-hotspots", "Zinc hot spots") |>
#'   recipe_input("layer", "layer", description = "soil samples") |>
#'   recipe_step("samples", "io.open", layer = "${inputs.layer}") |>
#'   recipe_step("hot", "stats.hotspots", layer = "${samples.layer}", field = "zinc") |>
#'   recipe_step("map", "export.map", layers = list("${hot.layer}"), scale_bar = "checker")
#' geo_recipe_validate(r)
#' geo_recipe_write(r, tempfile(fileext = ".yaml"))
NULL

# GeoSpaX v1 step names (docs/AUTOMATION.md, step catalogue)
tmr_geospax_steps <- function() {
  c(
    "devices.import", "devices.import_photos", "devices.import_tracks",
    "sensor.snapshot", "sensor.summary", "io.open", "vector.sql",
    "vector.buffer", "aggregate.hexbin", "interpolate.idw",
    "interpolate.auto", "stats.hotspots", "automap.style", "style.apply",
    "overviews.build", "layout.auto", "export.map", "export.png",
    "export.svg", "export.pdf", "export.series", "data.fetch", "taxa.worms",
    "tool", "export.report", "export.data", "python", "r", "script.python",
    "script.r", "dem.fetch", "ai.detect", "embeddings.fetch",
    "embeddings.similar", "embeddings.cluster", "embeddings.classify",
    "embeddings.change", "terrain.derive", "terrain.contours",
    "hydro.network", "lidar.3dtiles", "lidar.grid", "scene.3d",
    "raster.classify", "raster.sample", "rs.search", "rs.index", "rs.fetch",
    "grass", "saga"
  )
}

tmr_recipe_steps <- function() {
  list(
    io.open = tmr_step_open,
    interpolate.idw = tmr_step_idw,
    interpolate.auto = tmr_step_interp_auto,
    aggregate.hexbin = tmr_step_hexbin,
    stats.hotspots = tmr_step_hotspots,
    automap.style = tmr_step_style,
    style.apply = tmr_step_style,
    layout.auto = tmr_step_style,
    export.map = tmr_step_map,
    export.png = tmr_step_map,
    export.svg = tmr_step_map,
    export.pdf = tmr_step_map,
    export.data = tmr_step_data,
    export.report = tmr_step_report,
    terrain.derive = tmr_step_terrain,
    rs.index = tmr_step_index
  )
}

# ---- reading and writing -----------------------------------------------------

#' @rdname geo-recipe
#' @export
geo_recipe_read <- function(path) {
  rlang::check_installed("yaml")
  txt <- if (length(path) == 1 && file.exists(path)) {
    paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  } else {
    paste(path, collapse = "\n")
  }
  x <- tryCatch(yaml::yaml.load(txt), error = function(e) {
    cli::cli_abort(c("Could not parse the recipe.", "x" = conditionMessage(e)))
  })
  if (!is.list(x) || is.null(x$recipe)) {
    cli::cli_abort("Not a GeoSpaX recipe: there is no {.field recipe} key.")
  }
  structure(x, class = "tmr_recipe")
}

#' @export
print.tmr_recipe <- function(x, ...) {
  steps <- vapply(x$steps %||% list(), function(s) paste0(s$id, " (", s$use, ")"), character(1))
  ttl <- x$title %||% ""
  cli::cli_text("{.strong GeoSpaX recipe} {.val {x$recipe}} (v{x$version %||% 1}): {ttl}")
  if (length(x$inputs)) cli::cli_text("Inputs: {.field {names(x$inputs)}}")
  cli::cli_text("Steps: {steps}")
  if (length(x$outputs)) cli::cli_text("Outputs: {.field {unlist(x$outputs)}}")
  invisible(x)
}

#' @rdname geo-recipe
#' @param id,title,description Recipe id (`a-z 0-9 - _`), title and
#'   description.
#' @export
geo_recipe <- function(id, title = id, description = NULL) {
  structure(
    list(
      recipe = id, version = 1L, title = title, description = description,
      inputs = list(), steps = list(), outputs = NULL
    ),
    class = "tmr_recipe"
  )
}

#' @rdname geo-recipe
#' @param recipe A recipe to add to.
#' @param name,type,default Input name, type (`"layer"`, `"field"`,
#'   `"text"`, ...) and default value.
#' @export
recipe_input <- function(recipe, name, type = "layer", default = NULL,
                         description = NULL) {
  recipe$inputs[[name]] <- tmr_compact(list(
    type = type, default = default,
    description = description
  ))
  recipe
}

#' @rdname geo-recipe
#' @param use GeoSpaX step name, for example `"export.map"`.
#' @param ... Step parameters (the step's `with:`).
#' @param needs,when Extra ordering (step ids) and a run condition.
#' @export
recipe_step <- function(recipe, id, use, ..., needs = NULL, when = NULL) {
  step <- tmr_compact(list(
    id = id, use = use, needs = needs, when = when,
    with = list(...)
  ))
  recipe$steps[[length(recipe$steps) + 1]] <- step
  recipe
}

#' @rdname geo-recipe
#' @export
geo_recipe_write <- function(x, path) {
  rlang::check_installed("yaml")
  if (!inherits(x, "tmr_recipe")) cli::cli_abort("{.arg x} must be a recipe.")
  bad <- geo_recipe_validate(x)
  bad <- bad[bad$severity == "error", ]
  if (nrow(bad)) {
    cli::cli_abort(c(
      "The recipe has {nrow(bad)} problem{?s}:",
      stats::setNames(bad$problem, rep("x", nrow(bad)))
    ))
  }
  keys <- c("recipe", "version", "title", "description", "triggers", "inputs", "steps", "outputs")
  out <- tmr_compact(unclass(x)[intersect(keys, names(x))])
  header <- "# Written by tidymapr; runs in GeoSpaX (recipe format v1).\n"
  writeLines(c(header, yaml::as.yaml(out, indent.mapping.sequence = TRUE)), path, useBytes = TRUE)
  invisible(path)
}

# ---- validation ---------------------------------------------------------------

#' @rdname geo-recipe
#' @export
geo_recipe_validate <- function(x) {
  if (!inherits(x, "tmr_recipe")) x <- geo_recipe_read(x)
  acc <- new.env(parent = emptyenv())
  acc$probs <- list()
  add <- function(sev, step, msg) {
    row <- tibble::tibble(severity = sev, step = step %||% NA_character_, problem = msg)
    acc$probs[[length(acc$probs) + 1]] <- row
  }
  if (!is.character(x$recipe) || !grepl("^[a-z0-9_-]{1,64}$", x$recipe)) {
    add("error", NULL, "the recipe id must be 1-64 characters of a-z, 0-9, '-' or '_'")
  }
  steps <- x$steps %||% list()
  if (!length(steps)) add("error", NULL, "the recipe has no steps")
  ids <- vapply(steps, function(s) as.character(s$id %||% NA), character(1))
  if (anyNA(ids)) add("error", NULL, "every step needs an id")
  dup <- unique(ids[duplicated(ids) & !is.na(ids)])
  for (d in dup) add("error", d, sprintf("step id '%s' is used more than once", d))
  known <- tmr_geospax_steps()
  ours <- names(tmr_recipe_steps())
  inputs <- names(x$inputs %||% list())
  specials <- c("inputs", "run", "trigger", "recipe", "item")
  deps <- stats::setNames(vector("list", length(ids)), ids)
  for (s in steps) {
    sid <- as.character(s$id %||% "?")
    use <- s$use %||% ""
    if (!use %in% known) {
      near <- known[utils::adist(use, known) <= 2]
      add("error", sid, sprintf(
        "unknown step '%s'%s", use,
        if (length(near)) sprintf(" (did you mean '%s'?)", near[1]) else ""
      ))
    } else if (!use %in% ours) {
      add("geospax-only", sid, sprintf("'%s' runs in GeoSpaX, not in tidymapr", use))
    }
    refs <- tmr_recipe_refs(list(s$with, s$when, s$for_each))
    for (r in refs) {
      head <- strsplit(r, ".", fixed = TRUE)[[1]][1]
      if (head %in% specials) {
        if (head == "inputs") {
          nm <- strsplit(r, ".", fixed = TRUE)[[1]][2]
          if (!is.na(nm) && !nm %in% inputs) {
            add("error", sid, sprintf(
              "step '%s' refers to ${%s}, but there is no input called '%s'", sid, r, nm
            ))
          }
        }
      } else if (!head %in% ids) {
        add("error", sid, sprintf(
          "step '%s' refers to ${%s}, but there is no step or input called '%s'", sid, r, head
        ))
      } else {
        deps[[sid]] <- union(deps[[sid]], head)
      }
    }
    for (n in unlist(s$needs)) {
      if (!n %in% ids) {
        add("error", sid, sprintf("step '%s' needs '%s', which is not a step", sid, n))
      } else {
        deps[[sid]] <- union(deps[[sid]], n)
      }
    }
  }
  for (o in unlist(x$outputs)) {
    if (!o %in% ids) add("error", NULL, sprintf("output '%s' is not a step", o))
  }
  cyc <- tmr_recipe_cycle(ids[!is.na(ids)], deps)
  if (length(cyc)) {
    add("error", NULL, sprintf(
      "these steps depend on each other in a circle: %s", paste(cyc, collapse = ", ")
    ))
  }
  if (!length(acc$probs)) {
    return(tibble::tibble(severity = character(), step = character(), problem = character()))
  }
  do.call(rbind, acc$probs)
}

tmr_recipe_refs <- function(x) {
  txt <- unlist(rapply(list(x), function(v) as.character(v), how = "unlist"))
  m <- regmatches(txt, gregexpr("\\$\\{[^}]+\\}", txt))
  r <- unique(unlist(m))
  r <- sub("^\\$\\{\\s*", "", sub("\\s*\\}$", "", r))
  trimws(sub("\\?\\?.*$", "", r))
}

# Steps in a cycle (Kahn's algorithm leaves them unprocessed)
tmr_recipe_cycle <- function(ids, deps) {
  left <- ids
  repeat {
    done <- setdiff(ids, left)
    ready <- left[vapply(left, function(i) all(setdiff(deps[[i]], i) %in% done), logical(1))]
    if (!length(ready)) break
    left <- setdiff(left, ready)
  }
  left
}

tmr_recipe_order <- function(ids, deps) {
  done <- character()
  while (length(done) < length(ids)) {
    nxt <- ids[!ids %in% done & vapply(ids, function(i) all(deps[[i]] %in% done), logical(1))][1]
    done <- c(done, nxt)
  }
  done
}

# ---- running ------------------------------------------------------------------

#' @rdname geo-recipe
#' @export
geo_recipe_run <- function(x, inputs = list(), dir = tempfile("recipe-run-"), quiet = FALSE) {
  if (!inherits(x, "tmr_recipe")) x <- geo_recipe_read(x)
  probs <- geo_recipe_validate(x)
  err <- probs[probs$severity == "error", ]
  if (nrow(err)) {
    cli::cli_abort(c(
      "The recipe has {nrow(err)} problem{?s}:",
      stats::setNames(err$problem, rep("x", nrow(err)))
    ))
  }
  gso <- probs[probs$severity == "geospax-only", ]
  if (nrow(gso)) {
    cli::cli_abort(c(
      "This recipe uses steps that run in GeoSpaX only:",
      stats::setNames(gso$problem, rep("x", nrow(gso))),
      "i" = "Open the recipe in GeoSpaX to run it."
    ))
  }
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  # Inputs: given values, else defaults; "auto" layers need a value from R
  inp <- list()
  for (nm in names(x$inputs %||% list())) {
    def <- x$inputs[[nm]]$default
    inp[[nm]] <- inputs[[nm]] %||% def
    if (is.null(inp[[nm]])) cli::cli_abort("Input {.field {nm}} has no value and no default.")
  }
  extra <- setdiff(names(inputs), names(inp))
  if (length(extra)) cli::cli_warn("Input{?s} {.field {extra}} {?is/are} not used by the recipe.")
  now <- Sys.time()
  ctx <- list(
    inputs = inp, recipe = x$recipe,
    run = list(
      date = format(now, "%Y-%m-%d"), time = format(now, "%H:%M"),
      datetime = format(now, "%Y-%m-%d %H:%M"), id = basename(dir), dir = dir
    ),
    .steps = list(), .log = list(), .maps = list(), .decisions = list()
  )
  steps <- x$steps
  ids <- vapply(steps, function(s) s$id, character(1))
  deps <- stats::setNames(lapply(steps, function(s) {
    refs <- tmr_recipe_refs(list(s$with, s$when, s$for_each))
    heads <- vapply(strsplit(refs, ".", fixed = TRUE), `[`, character(1), 1)
    unique(c(intersect(heads, ids), unlist(s$needs)))
  }), ids)
  handlers <- tmr_recipe_steps()
  for (sid in tmr_recipe_order(ids, deps)) {
    s <- steps[[match(sid, ids)]]
    if (!is.null(s$when) && !isTRUE(as.logical(tmr_recipe_eval(s$when, ctx)))) {
      ctx$.steps[[sid]] <- list(skipped = TRUE)
      ctx$.log[[length(ctx$.log) + 1]] <- tibble::tibble(
        step = sid, use = s$use, status = "skipped", seconds = 0
      )
      next
    }
    with <- tmr_recipe_eval(s$with %||% list(), ctx)
    if (!quiet) cli::cli_inform("{.field {sid}} ({s$use})")
    t0 <- Sys.time()
    res <- handlers[[s$use]](with, ctx, sid, s$use)
    ctx$.maps <- c(ctx$.maps, res$.maps)
    ctx$.decisions <- c(ctx$.decisions, res$.decisions)
    res$.maps <- NULL
    res$.decisions <- NULL
    ctx$.steps[[sid]] <- res
    ctx$.log[[length(ctx$.log) + 1]] <- tibble::tibble(
      step = sid, use = s$use, status = "done",
      seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
    )
  }
  outs <- unlist(x$outputs) %||% ids
  res <- ctx$.steps[outs]
  res$log <- do.call(rbind, ctx$.log)
  res$dir <- dir
  res
}

# Resolve ${...} expressions in a value (recursively for lists)
tmr_recipe_eval <- function(v, ctx) {
  if (is.list(v)) {
    return(lapply(v, tmr_recipe_eval, ctx = ctx))
  }
  # yaml simplifies a sequence of strings to a character vector
  if (is.character(v) && length(v) > 1 && any(grepl("${", v, fixed = TRUE))) {
    return(lapply(as.list(v), tmr_recipe_eval, ctx = ctx))
  }
  if (!is.character(v) || length(v) != 1 || !grepl("${", v, fixed = TRUE)) {
    return(v)
  }
  whole <- regmatches(v, regexec("^\\$\\{([^}]+)\\}$", v))[[1]]
  if (length(whole)) {
    return(tmr_recipe_lookup(whole[2], ctx))
  }
  m <- gregexpr("\\$\\{([^}]+)\\}", v)
  parts <- regmatches(v, m)[[1]]
  vals <- vapply(parts, function(p) {
    val <- tmr_recipe_lookup(sub("^\\$\\{", "", sub("\\}$", "", p)), ctx)
    tmr_recipe_text(val)
  }, character(1))
  regmatches(v, m) <- list(vals)
  v
}

tmr_recipe_lookup <- function(expr, ctx) {
  fb <- NULL
  if (grepl("??", expr, fixed = TRUE)) {
    sp <- strsplit(expr, "??", fixed = TRUE)[[1]]
    expr <- trimws(sp[1])
    fb <- trimws(sp[2])
  }
  path <- strsplit(trimws(expr), ".", fixed = TRUE)[[1]]
  cur <- if (path[1] %in% c("inputs", "run", "recipe")) ctx[[path[1]]] else ctx$.steps[[path[1]]]
  for (k in path[-1]) {
    if (is.null(cur)) break
    cur <- if (grepl("^[0-9]+$", k) && is.null(names(cur))) cur[[as.integer(k) + 1]] else cur[[k]]
  }
  if (is.null(cur) || (is.character(cur) && identical(cur, "auto") && !is.null(fb))) fb else cur
}

tmr_recipe_text <- function(val) {
  if (is.null(val)) {
    return("")
  }
  nm <- attr(val, "tmr_name")
  if (!is.null(nm)) {
    return(nm)
  }
  if (inherits(val, c("sf", "SpatRaster"))) {
    return("layer")
  }
  if (is.list(val)) {
    return(paste(vapply(val, tmr_recipe_text, character(1)), collapse = ", "))
  }
  paste(as.character(val), collapse = ", ")
}

tmr_named <- function(obj, name) {
  attr(obj, "tmr_name") <- name
  obj
}

tmr_compact <- function(x) x[!vapply(x, is.null, logical(1))]

# Best numeric field: the numeric column with the most distinct values
tmr_recipe_field <- function(layer, field) {
  if (!is.null(field) && !identical(field, "auto") && !identical(field, "none")) {
    return(field)
  }
  d <- sf::st_drop_geometry(layer)
  num <- names(d)[vapply(d, is.numeric, logical(1))]
  num <- num[!grepl("^(id|fid|objectid|x|y|lon|lat)$", tolower(num))]
  if (!length(num)) cli::cli_abort("No numeric field to use; set {.field field}.")
  num[which.max(vapply(d[num], function(v) length(unique(v)), integer(1)))]
}

# ---- step handlers ----------------------------------------------------------------

tmr_step_open <- function(w, ctx, sid, use) {
  lay <- w$layer
  if (is.null(lay) || identical(lay, "auto")) {
    cli::cli_abort(
      "Step {.field {sid}}: give the layer as a recipe input (a file or an sf/SpatRaster object)."
    )
  }
  obj <- if (is.character(lay)) geo_read(lay) else lay
  name <- attr(lay, "tmr_name") %||%
    if (is.character(lay)) tools::file_path_sans_ext(basename(lay)) else sid
  list(layer = tmr_named(obj, name), layers = list(tmr_named(obj, name)))
}

tmr_recipe_grid <- function(pts, n = 100) {
  bb <- sf::st_bbox(pts)
  res <- max(bb["xmax"] - bb["xmin"], bb["ymax"] - bb["ymin"]) / n
  terra::rast(
    xmin = bb["xmin"] - res / 2, xmax = bb["xmax"] + res / 2,
    ymin = bb["ymin"] - res / 2, ymax = bb["ymax"] + res / 2,
    resolution = res, crs = sf::st_crs(pts)$wkt
  )
}

tmr_recipe_hull_mask <- function(r, pts) {
  hull <- terra::vect(sf::st_convex_hull(sf::st_union(pts)))
  terra::mask(r, hull)
}

tmr_step_idw <- function(w, ctx, sid, use) {
  pts <- tmr_recipe_points(w$layer)
  f <- tmr_recipe_field(pts, w$field)
  g <- tmr_recipe_grid(pts)
  r <- geo_interpolate(pts, !!rlang::sym(f), g, power = w$power %||% 2, name = f)
  r <- tmr_recipe_hull_mask(r, pts)
  list(
    raster = tmr_named(r, w$name %||% f), field = f, method = "idw",
    method_label = "IDW", has_se = FALSE
  )
}

tmr_recipe_points <- function(layer) {
  if (!inherits(layer, "sf")) cli::cli_abort("This step needs a point layer.")
  if (isTRUE(sf::st_is_longlat(layer))) {
    ctr <- sf::st_coordinates(sf::st_centroid(sf::st_union(layer)))
    layer <- sf::st_transform(layer, geo_local_utm_crs(ctr[1], ctr[2]))
  }
  layer
}

# Kriging vs IDW by leave-one-out cross-validation; the lower RMSE wins
tmr_step_interp_auto <- function(w, ctx, sid, use) {
  rlang::check_installed("gstat")
  pts <- tmr_recipe_points(w$layer)
  f <- tmr_recipe_field(pts, w$field)
  z <- pts[[f]]
  keep <- is.finite(z)
  pts <- pts[keep, ]
  xy <- sf::st_coordinates(pts)
  z <- pts[[f]]
  vg <- tmr_variogram(pts, f, "Exp", 0, NULL, NULL)
  n <- nrow(pts)
  loo <- vapply(seq_len(n), function(i) {
    k <- geo_krige_cpp(
      xy[-i, 1], xy[-i, 2], z[-i], xy[i, 1], xy[i, 2], 1L,
      vg$nugget, vg$psill, vg$range, FALSE, FALSE, 1L
    )$prediction
    d <- geo_idw_cpp(xy[-i, 1], xy[-i, 2], z[-i], xy[i, 1], xy[i, 2], 2, FALSE, 0, 1L)
    c(k, d)
  }, numeric(2))
  rmse <- sqrt(rowMeans((loo - matrix(z, 2, n, byrow = TRUE))^2))
  g <- tmr_recipe_grid(pts)
  krige <- rmse[1] <= rmse[2]
  r <- if (krige) {
    geo_interpolate(pts, !!rlang::sym(f), g,
      method = "kriging", model = "Exp",
      nugget = vg$nugget, psill = vg$psill, range = vg$range, name = f
    )
  } else {
    geo_interpolate(pts, !!rlang::sym(f), g, name = f)
  }
  r <- tmr_recipe_hull_mask(r, pts)
  se <- if (krige) {
    s <- sqrt(r[["variance"]])
    names(s) <- paste(f, "standard error")
    tmr_named(s, paste(f, "standard error"))
  }
  label <- if (krige) "ordinary kriging, exponential variogram" else "IDW, power 2"
  why <- sprintf(
    "Leave-one-out RMSE: kriging %.3g, IDW %.3g, so %s.", rmse[1], rmse[2],
    if (krige) "kriging" else "IDW"
  )
  list(
    raster = tmr_named(r[[1]], w$name %||% f), se = se, has_se = krige,
    field = f, method = if (krige) "kriging" else "idw", method_label = label,
    rmse = stats::setNames(rmse, c("kriging", "idw")),
    .decisions = list(tibble::tibble(
      step = sid, element = "interpolation", choice = label, reason = why
    ))
  )
}

tmr_step_hexbin <- function(w, ctx, sid, use) {
  pts <- tmr_recipe_points(w$layer)
  bb <- sf::st_bbox(pts)
  cell <- max(bb["xmax"] - bb["xmin"], bb["ymax"] - bb["ymin"]) / (w$cells %||% 25)
  hex <- sf::st_sf(geometry = sf::st_make_grid(pts, cellsize = cell, square = FALSE))
  # Each point goes to one cell only (points on a shared edge go to the first)
  own <- vapply(sf::st_intersects(pts, hex), function(i) if (length(i)) i[1] else NA_integer_, 1L)
  hit <- lapply(seq_len(nrow(hex)), function(j) which(own == j))
  stat <- w$stat %||% if (!is.null(w$field) && !identical(w$field, "auto")) "mean" else "count"
  hex$count <- lengths(hit)
  if (stat %in% c("sum", "mean")) {
    f <- tmr_recipe_field(pts, w$field)
    v <- pts[[f]]
    hex[[f]] <- vapply(hit, function(i) if (length(i)) get(stat)(v[i]) else NA_real_, numeric(1))
  }
  hex <- hex[hex$count > 0, ]
  list(layer = tmr_named(hex, w$name %||% "hexbins"), cells = nrow(hex), cell_size = unname(cell))
}

tmr_step_hotspots <- function(w, ctx, sid, use) {
  pts <- tmr_recipe_points(w$layer)
  f <- w$field
  base <- if (is.null(f) || identical(f, "auto") || identical(f, "none")) {
    tmr_step_hexbin(list(layer = pts, cells = 25), ctx, sid, use)$layer
  } else {
    pts
  }
  val <- if (is.null(f) || identical(f, "auto") || identical(f, "none")) "count" else f
  ctr <- suppressWarnings(sf::st_centroid(base))
  ll <- sf::st_coordinates(sf::st_transform(ctr, 4326))
  tab <- sf::st_drop_geometry(base)
  tab$lon <- ll[, 1]
  tab$lat <- ll[, 2]
  k <- min(8, nrow(tab) - 1)
  hs <- geo_hotspot(tab, !!rlang::sym(val), k = k)
  hs$p_fdr <- stats::p.adjust(hs$p_value, "fdr")
  hs$confidence <- cut(hs$p_fdr, c(-Inf, 0.01, 0.05, 0.1, Inf),
    labels = c("99%", "95%", "90%", "not significant")
  )
  hs$hotspot <- factor(
    ifelse(hs$confidence == "not significant", "not significant",
      paste(ifelse(hs$gi_star > 0, "Hot spot", "Cold spot"), hs$confidence)
    ),
    levels = c(
      paste("Hot spot", c("99%", "95%", "90%")), "not significant",
      paste("Cold spot", c("90%", "95%", "99%"))
    )
  )
  out <- sf::st_sf(hs[, setdiff(names(hs), c("lon", "lat"))], geometry = sf::st_geometry(base))
  list(
    layer = tmr_named(out, w$name %||% "hotspots"), field = val,
    .decisions = list(tibble::tibble(
      step = sid, element = "hot spots",
      choice = sprintf("Getis-Ord Gi*, %d nearest neighbours, FDR-corrected", k),
      reason = paste(
        "Classes at 90, 95 and 99% confidence after the false discovery rate",
        "correction, as GeoSpaX."
      )
    ))
  )
}

tmr_step_style <- function(w, ctx, sid, use) {
  list(layers = w$layers %||% list(w$layer), style_field = w$field %||% "auto")
}

tmr_step_map <- function(w, ctx, sid, use) {
  rlang::check_installed("ggplot2")
  layers <- w$layers %||% list(w$layer)
  if (!is.list(layers) || inherits(layers, c("sf", "SpatRaster"))) layers <- list(layers)
  rasters <- Filter(function(l) inherits(l, "SpatRaster"), layers)
  vecs <- Filter(function(l) inherits(l, "sf"), layers)
  # A styled field from an automap.style step, if any
  styled <- unlist(lapply(ctx$.steps, function(s) s$style_field))
  pick <- function(v) {
    if ("none" %in% styled) {
      return(NULL)
    }
    nm <- names(sf::st_drop_geometry(v))
    hit <- intersect(c("hotspot", setdiff(styled, "auto")), nm)
    if (length(hit)) hit[1] else NULL
  }
  sb <- w$scale_bar %||% "auto"
  na <- w$north_arrow %||% "auto"
  if (identical(sb, "none")) sb <- FALSE
  if (identical(na, "none")) na <- FALSE
  bg <- if (length(rasters)) rasters[[1]] else NULL
  if (length(vecs)) {
    v <- vecs[[1]]
    col <- pick(v)
    p <- if (!is.null(col)) {
      pal <- "auto"
      if (identical(col, "hotspot")) {
        conv <- c(
          "Hot spot 99%" = "#B2182B", "Hot spot 95%" = "#EF8A62",
          "Hot spot 90%" = "#FDDBC7", "not significant" = "#E0E0E0",
          "Cold spot 90%" = "#D1E5F0", "Cold spot 95%" = "#67A9CF",
          "Cold spot 99%" = "#2166AC"
        )
        pal <- unname(conv[sort(unique(as.character(v$hotspot)))])
      }
      geo_automap(v, !!rlang::sym(col),
        background = bg, palette = pal,
        background_title = attr(bg, "tmr_name"), scale_bar = sb, north_arrow = na,
        legend_title = w$legend_title %||% col
      )
    } else {
      geo_automap(v,
        background = bg, background_title = attr(bg, "tmr_name"),
        scale_bar = sb, north_arrow = na
      )
    }
  } else if (!is.null(bg)) {
    p <- geo_automap(bg,
      legend_title = w$legend_title %||% attr(bg, "tmr_name"),
      scale_bar = sb, north_arrow = na
    )
  } else {
    cli::cli_abort("Step {.field {sid}}: no layers to map.")
  }
  if (!is.null(w$title)) p <- p + ggplot2::labs(title = w$title)
  default_fmt <- switch(use,
    export.png = "png",
    export.svg = "svg",
    export.pdf = "pdf",
    "png"
  )
  fmt <- unlist(w$format %||% default_fmt)
  name <- w$name %||% sid
  files <- vapply(fmt, function(ext) {
    f <- file.path(ctx$run$dir, paste0(name, ".", ext))
    ggplot2::ggsave(f, p,
      width = w$width %||% 9, height = w$height %||% 6.5,
      dpi = w$dpi %||% 300, bg = "white"
    )
    f
  }, character(1))
  dec <- geo_automap_explain(p)
  dec$step <- sid
  list(
    files = unname(files), plot = p,
    .maps = list(list(step = sid, title = w$title %||% name, file = files[[1]])),
    .decisions = list(dec[, c("step", "element", "choice", "reason")])
  )
}

tmr_step_data <- function(w, ctx, sid, use) {
  lay <- w$layer
  fmt <- w$format %||% "gpkg"
  f <- file.path(ctx$run$dir, paste0(w$name %||% attr(lay, "tmr_name") %||% sid, ".", fmt))
  geo_write(lay, f, overwrite = TRUE)
  list(file = f)
}

tmr_step_terrain <- function(w, ctx, sid, use) {
  r <- geo_raster_terrain(w$dem %||% w$raster, v = unlist(w$products %||% c("slope", "aspect")))
  list(raster = tmr_named(r[[1]], names(r)[1]), rasters = r)
}

tmr_step_index <- function(w, ctx, sid, use) {
  if (is.null(w$raster)) {
    cli::cli_abort(paste(
      "Step {.field {sid}}: tidymapr computes indices from a raster you give",
      "({.field raster}); GeoSpaX can also search STAC."
    ))
  }
  r <- geo_spectral_index(w$raster, toupper(w$index %||% "NDVI"), threshold = "otsu")
  list(raster = tmr_named(r[[1]], toupper(w$index %||% "NDVI")), threshold = attr(r, "threshold"))
}

tmr_step_report <- function(w, ctx, sid, use) {
  f <- file.path(ctx$run$dir, "report.html")
  esc <- function(x) gsub("<", "&lt;", gsub("&", "&amp;", as.character(x)))
  maps <- vapply(ctx$.maps, function(m) {
    sprintf("<h2>%s</h2><img src=\"%s\" style=\"max-width:100%%\">", esc(m$title), basename(m$file))
  }, character(1))
  dec <- if (length(ctx$.decisions)) do.call(rbind, ctx$.decisions) else NULL
  rows <- if (!is.null(dec)) {
    paste0("<tr><td>", esc(dec$step), "</td><td>", esc(dec$element), "</td><td>", esc(dec$choice),
      "</td><td>", esc(dec$reason), "</td></tr>",
      collapse = ""
    )
  } else {
    ""
  }
  log <- do.call(rbind, ctx$.log)
  lrows <- paste0(
    "<tr><td>", esc(log$step), "</td><td>", esc(log$use), "</td><td>", esc(log$status),
    "</td><td>", log$seconds, " s</td></tr>",
    collapse = ""
  )
  html <- paste0(
    "<!doctype html><html><head><meta charset=\"utf-8\"><title>",
    esc(w$title %||% ctx$recipe), "</title><style>",
    "body{font-family:Inter,Arial,sans-serif;max-width:1000px;margin:2em auto;",
    "color:#222;background:#fff}table{border-collapse:collapse;width:100%}",
    "td,th{border-bottom:1px solid #ddd;padding:4px 8px;text-align:left;",
    "vertical-align:top}</style>",
    "</head><body><h1>", esc(w$title %||% ctx$recipe), "</h1>",
    "<p>Recipe <code>", esc(ctx$recipe), "</code>, run ", esc(ctx$run$datetime),
    " with tidymapr.</p>",
    paste(maps, collapse = ""),
    "<h2>How this map was made</h2><table><tr><th>Step</th><th>Element</th>",
    "<th>Choice</th><th>Why</th></tr>", rows, "</table>",
    "<h2>Run log</h2><table><tr><th>Step</th><th>Tool</th><th>Status</th>",
    "<th>Time</th></tr>", lrows, "</table>",
    "</body></html>"
  )
  writeLines(html, f, useBytes = TRUE)
  list(file = f)
}
