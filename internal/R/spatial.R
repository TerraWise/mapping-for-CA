library(sf)
library(here)


# Read the single shapefile in spatial/<folder>/ as valid WGS84, or NULL if none
read_layer <- function(folder) {
    path <- Sys.glob(here("spatial", folder, "*.shp"))
    if (length(path) == 0) {
        return(NULL)
    }
    if (length(path) > 1) {
        stop(
            "Expected one .shp file in spatial/", folder, ", found ", length(path),
            call. = FALSE
        )
    }
    read_sf(path) |>
        st_make_valid() |>
        st_transform(4326)
}

# Map centre: centroid of the dissolved area (planar, s2 off), shifted by the offsets.
# The caller's s2 setting is restored afterwards.
area_centre <- function(area, lon_offset = 0, lat_offset = 0) {
    old_s2 <- sf_use_s2(FALSE)
    on.exit(sf_use_s2(old_s2), add = TRUE)
    xy <- st_coordinates(st_centroid(st_union(area)))
    # [[ ]] gives unnamed numbers; named ones would break setView's JSON
    list(lon = xy[[1, "X"]] + lon_offset, lat = xy[[1, "Y"]] + lat_offset)
}

# Clip planting to an area (planar, s2 off), keeping polygon parts only.
# Pieces that only touch the edge come back as lines/points, which leaflet
# would draw as stray lines and default markers.
clip_planting <- function(planting, area) {
    old_s2 <- sf_use_s2(FALSE)
    on.exit(sf_use_s2(old_s2), add = TRUE)
    planting <- st_set_agr(planting, "constant") # avoids the "assumed constant" warning
    clipped <- st_intersection(planting, st_union(area))
    if (any(st_is(clipped, "GEOMETRYCOLLECTION"))) {
        clipped <- st_collection_extract(clipped, "POLYGON")
    }
    clipped[st_dimension(clipped) %in% 2, ]
}
