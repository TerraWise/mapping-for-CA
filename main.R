library(here)


# Settings ---------------------------------------------------------------------

# Command-line flags (see `Rscript main.R --help`), e.g.
#   Rscript main.R --title "Example Farm" --zoom 13 --width 1600 --height 900 \
#       --lon-offset 0.01 --lat-offset -0.005
# Sourced interactively there are no flags, so the defaults are used.
# Parsed first so --help and bad flags return before the heavy setup below.
source(here("internal", "R", "cli.R"))
opts <- parse_cli()

library(reticulate)
source(here("internal", "R", "spatial.R"))
source(here("internal", "R", "map.R"))
source(here("internal", "R", "colour.R"))
source_python(here("internal", "py", "map_utils_playwright.py"))


# Inputs -----------------------------------------------------------------------

farm_boundary <- read_layer("boundary")
if (is.null(farm_boundary)) {
    stop("No boundary shapefile found in spatial/boundary", call. = FALSE)
}
historical_planting <- read_layer("planting") # NULL when there is no planting layer

# An optional "group" column (any case) gives one set of maps per group.
# Without it, the whole farm is one area and file names get no suffix.
group_col <- names(farm_boundary)[tolower(names(farm_boundary)) == "group"][1]
grouped <- !is.na(group_col)

if (grouped) {
    group <- farm_boundary[[group_col]]
    if (anyNA(group)) {
        warning(
            sum(is.na(group)), " boundary feature(s) have no group and are left off the maps",
            call. = FALSE
        )
    }
    areas <- split(farm_boundary, group) # one sf per group, sorted, NA dropped
    if (length(areas) == 0) {
        stop("The '", group_col, "' column has no values", call. = FALSE)
    }
    suffixes <- paste0("_", gsub("[^A-Za-z0-9]+", "_", names(areas)))
    clash <- suffixes %in% suffixes[duplicated(suffixes)]
    if (any(clash)) {
        stop(
            "These groups would share a file name: ",
            paste(names(areas)[clash], collapse = ", "),
            call. = FALSE
        )
    }
} else {
    areas <- list(farm_boundary)
    suffixes <- ""
}


# Maps -------------------------------------------------------------------------

jobs <- list()
for (i in seq_along(areas)) {
    area <- areas[[i]]
    centre <- area_centre(area, opts$lon_offset, opts$lat_offset)

    jobs[[length(jobs) + 1]] <- save_map(
        "farm_boundary", suffixes[i], list(area),
        blue, "Farm Boundary", centre,
        title = opts$title, zoom = opts$zoom, width = opts$width, height = opts$height
    )

    # The whole-farm map shows planting as supplied; group maps clip it to the group
    planting <- historical_planting
    if (grouped && !is.null(planting)) {
        planting <- clip_planting(planting, area)
        if (nrow(planting) == 0) {
            message(
                "No historical planting in group '", names(areas)[i],
                "'; skipping its planting map"
            )
            planting <- NULL
        }
    }
    if (!is.null(planting)) {
        jobs[[length(jobs) + 1]] <- save_map(
            "historical_planting", suffixes[i], list(area, planting),
            c(blue, yellow), c("Farm Boundary", "Historical Planting"), centre,
            title = opts$title, zoom = opts$zoom, width = opts$width, height = opts$height
        )
    }
}

# One browser for all screenshots; Python deletes each HTML after capturing it
batch_map_to_image(jobs)
