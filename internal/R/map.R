library(leaflet)
library(leafem)
library(geojsonsf)
library(here)
# mapview::mapshot2() needs webshot2, which mapview only Suggests; naming it here
# makes renv record it in renv.lock
requireNamespace("webshot2", quietly = TRUE)


# Build a base leaflet map with satellite imagery, scale bar, logos, and an outline
# for each of the (one or two) layers in sf_features
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
        addLogo(
            here("assets", "Logo.png"),
            position = "bottomright",
            width = 189,
            height = 68
        ) |>
        addLogo(
            here("assets", "north_arrow.png"),
            position = "topleft",
            width = 40,
            height = 55
        )
    if (length(sf_features) > 1) {
        m <- m |>
            addGeoJSON(
                sf_geojson(sf_features[[2]]),
                color = cols[2],
                fill = FALSE,
                opacity = 1,
                weight = 2
            )
    }
    m
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

build_and_save_map <- function(sf_features, lon, lat, cols, labels, title, url, zoom = 12) {
    map <- TW_map(sf_features, cols, lon, lat, zoom) |>
        addLegend(
            position = "bottomleft",
            colors = cols,
            labels = labels,
            title = title,
            opacity = 1
        ) |>
        resize_legend(18, 20, 6)
    
    mapview::mapshot2(map, url)
}

# Save one map as HTML in tempdir() and return its screenshot job for Python:
# list(html, png, width, height), with the PNG going to map-pic/
save_map <- function(name, suffix, features, cols, labels, centre, title, zoom, width, height) {
    html <- file.path(tempdir(), paste0(name, suffix, ".html"))
    build_and_save_map(
        sf_features = features,
        lon = centre$lon,
        lat = centre$lat,
        cols = cols,
        labels = labels,
        title = title,
        url = html,
        zoom = zoom
    )
    list(html, here("map-pic", paste0(name, suffix, ".png")), width, height)
}
