library(leaflet)
library(leafem)
library(leaflet.extras)
library(geojsonsf)
library(here)


# Build a base leaflet map with satellite imagery, scale bar, logos, and two GeoJSON boundary overlays
TW_map <- function(
    sf_features,
    cols,
    lon,
    lat,
    zoom,
    width = NULL,
    height = NULL
) {
    m <- leaflet(
        options = leafletOptions(zoomControl = FALSE),
        width = width,
        height = height
    ) |>
        addProviderTiles("Esri.WorldImagery") |>
        setView(lng = lon, lat = lat, zoom = zoom) |>
        addScaleBar(
            position = "bottomleft",
            options = scaleBarOptions(imperial = FALSE, maxWidth = 200)
        ) |>
        addGeoJSON(
            sf_geojson(sf_features[[1]]),
            color = cols[1],
            fill = FALSE,
            opacity = 1
        ) |>
        addGeoJSON(
            sf_geojson(sf_features[[2]]),
            color = cols[2],
            fill = FALSE,
            opacity = 1,
            weight = 2
        ) |>
        addLogo(
            here("static", "map", "Logo.png"),
            position = "bottomright",
            width = 189,
            height = 68
        ) |>
        addLogo(
            here("static", "map", "north_arrow.png"),
            position = "topleft",
            width = 40,
            height = 55
        )
}

# Adjust legend font size, colour swatch size, and padding via CSS injection
resize_legend <- function(map, font_size = 12, icon_size = 14, padding = 6) {
    css <- htmltools::tags$style(htmltools::HTML(sprintf(
        ".info.legend { font-size: %dpx; padding: %dpx; }
         .info.legend i { height: %dpx !important; width: %dpx !important; margin-right: 4px; }",
        font_size,
        padding,
        icon_size,
        icon_size
    )))
    htmlwidgets::appendContent(map, css)
}

build_and_save_map <- function(sf_features, lon, lat, url) {
    map <- TW_map(sf_features, cols, lon, lat, 12) |>
        addLegend(
            position = "bottomleft",
            colors = legend_colors,
            labels = legend_labels,
            title = map_title,
            opacity = 1
        ) |>
        resize_legend(18, 20, 6)
    mapshot2(map, url = url)
}