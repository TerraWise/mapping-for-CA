library(reticulate)
library(mapview)
library(here)

source(here("internal", "R", "map.R"))
source(here("internal", "R", "spatial.R"))
source(here("internal", "R", "colour.R"))

use_condaenv("CA-report")
source_python(here("internal", "py", "map_utils_playwright.py"))

map_title <- "Client name"

farm_boundary <- read_sf(Sys.glob(here("spatial", "boundary", "*.shp"))) |>
    st_make_valid() |>
    st_transform(4326)

group_col <- names(farm_boundary)[tolower(names(farm_boundary)) == "group"]
has_groups <- length(group_col) > 0
groups <- if (has_groups) sort(unique(farm_boundary[[group_col[1]]])) else NULL

sf_use_s2(FALSE)
centroid <- st_centroid(st_union(farm_boundary))
sf_use_s2(TRUE)

coords <- st_coordinates(centroid)

lon <- coords[[1, 1]] - 0
lat <- coords[[1, 2]] - 0

proposed_planting <- st_read(Sys.glob(here(
    "spatial",
    "planting",
    "*.shp"
))) |>
    st_make_valid() |>
    st_transform(4326)


sf_features <- list(farm_boundary, proposed_planting)
cols <- c(blue, yellow)

legend_colors <- c(blue, yellow)
legend_labels <- c("Farm Boundary", "Historical Planting")


if (has_groups) {
    jobs <= c()
    group_data <- lapply(groups, function(g) {
        b <- farm_boundary[farm_boundary[[group_col[1]]] == g, ]
        c_pt <- st_centroid(st_union(b))
        coords_g <- st_coordinates(c_pt)
        planting_g <- st_intersection2(proposed_planting, b)
        group_entry <- list(
            boundary = b,
            lon = coords_g[[1, 1]] - 0,
            lat = coords_g[[1, 2]] - 0,
            sf_features = list(b, planting_g)
        )
    })

    for (i in seq_along(groups)) {
        g <- groups[[i]]
        safe <- str_replace_all(g, "[^a-zA-Z0-9]+", "_")
        gd <- group_data[[i]]
        build_and_save_map(
            gd$sf_features,
            gd$lon,
            gd$lat,
            paste0(
                "farm_boundary_",
                safe,
                ".html"
            )
        )
        jobs <- append(jobs, array(
            list(
                paste0("farm_boundary_", safe, ".html"),
                paste0("farm_boundary_", safe, ".png"),
                1000,
                1000
            )
            )
        )
    }
    batch_map_to_image(jobs)
} else {
    build_and_save_map(
        sf_features,
        lon,
        lat,
        "farm_boundary.html"
    )
    map_to_image("farm_boundary.html", "farm_boundary.png", 1000, 1000)
}