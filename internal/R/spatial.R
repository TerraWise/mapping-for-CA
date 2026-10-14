library(sf)
library(units)
library(stringr)
library(dplyr)


# Compute sf intersection, disabling S2 geometry if the call throws an error.
# Normalises GEOMETRYCOLLECTION rows by extracting their polygon component in-place;
# POLYGON/MULTIPOLYGON and POINT/LINESTRING rows are left unchanged.
st_intersection2 <- function(x, y) {
    prev_s2 <- sf_use_s2()
    result <- tryCatch(
        st_intersection(x, y),
        error = function(e) {
            sf_use_s2(FALSE)
            st_intersection(x, y)
        }
    )
    sf_use_s2(prev_s2)
    result <- st_make_valid(result)
    gc_mask <- st_geometry_type(result) == "GEOMETRYCOLLECTION"
    if (any(gc_mask)) {
        result[gc_mask, ] <- st_collection_extract(result[gc_mask, ], "POLYGON")
    }
    result
}


# Sum the area of all features in an sf object and return the total in hectares
get_area_ha <- function(farm_bound) {
    area_m2 <- sum(st_area(farm_bound))
    area_ha <- set_units(area_m2, ha)
    return(round(area_ha, 2))
}


# Extract the lower bound of each "x - y" value label and sort the sf object in descending order
add_and_sort <- function(sf) {
    v <- vector()
    for (i in 1:length(sf$value)) {
        pre <- as.numeric(
            unlist(str_split_1(sf$value[[i]], pattern = " - ")[[1]])
        )
        v <- c(v, pre)
    }

    sf$pre <- v

    sf <- arrange(sf, desc(pre))

    return(sf)
}


# Parse "x - y" value labels from an sf object, clamp negatives to min_value, and return rounded label strings
clean_dash <- function(sf, significant_number, min_value) {
    legend.values <- lapply(unique(sf$value), str_split_1, pattern = " - ")
    legend.values <- unlist(lapply(legend.values, as.numeric))
    legend.values[legend.values < 0] <- min_value

    clean.vals <- vector()

    for (i in seq(2, length(legend.values), by = 2)) {
        pre <- round(legend.values[[i - 1]], significant_number)
        suf <- round(legend.values[[i]], significant_number)
        clean.vals <- append(clean.vals, paste(pre, "-", suf))
    }

    return(clean.vals)
}


# Read one or more GeoJSON files matching a glob pattern, merge them, and return sorted by value label
read_spatial_layer <- function(glob_pattern) {
    layer_path <- Sys.glob(glob_pattern)
    sf_obj <- st_read(layer_path[1]) |>
        st_make_valid() |>
        st_transform(4326)
    if (length(layer_path) > 1) {
        for (i in seq(2, length(layer_path))) {
            temp.sf <- st_read(layer_path[i]) |>
                st_make_valid() |>
                st_transform(4326)
            sf_obj <- rbind(sf_obj, temp.sf)
        }
    }
    gc_mask <- st_geometry_type(sf_obj) == "GEOMETRYCOLLECTION" & !st_is_empty(sf_obj)
    if (any(gc_mask)) {
        sf_obj[gc_mask, ] <- st_collection_extract(sf_obj[gc_mask, ], "POLYGON")
    }
    sf_obj <- sf_obj[!st_is_empty(sf_obj), ]
    add_and_sort(sf_obj)
}


# Read soil typelayer (either GEOJSON or SHP)
read_soil_type <- function() {
    layer_path <- Sys.glob(here("spatial", "soil-type", "*.*json"))
    if (length(layer_path) == 0) {
        layer_path <- Sys.glob(here("spatial", "soil-type", "*.shp"))
    }
    read_sf(layer_path)
}
