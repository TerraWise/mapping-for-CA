library(optparse)


cli_options <- list(
    make_option("--title",
        default = "Client name",
        help = "Legend title [default: %default]"
    ),
    make_option("--lon-offset",
        dest = "lon_offset", type = "double", default = 0,
        help = "Shift every map centre east (+) or west (-), in degrees [default: %default]"
    ),
    make_option("--lat-offset",
        dest = "lat_offset", type = "double", default = 0,
        help = "Shift every map centre north (+) or south (-), in degrees [default: %default]"
    ),
    # Whole numbers are parsed as double and checked in parse_cli(), because
    # optparse's integer type silently truncates 12.7 to 12
    make_option("--zoom",
        type = "double", default = 12,
        help = "Map zoom level, 1-18 [default: %default]"
    ),
    make_option("--width",
        type = "double", default = 1000,
        help = "PNG width in pixels, 100-5000 [default: %default]"
    ),
    make_option("--height",
        type = "double", default = 1000,
        help = "PNG height in pixels, 100-5000 [default: %default]"
    )
)

# Stop unless opts[[name]] is a number (optparse keeps bad input as a string)
# that is finite, whole if required, and within [min, max]
check_number <- function(opts, name, min = -Inf, max = Inf, whole = FALSE) {
    x <- opts[[name]]
    ok <- is.numeric(x) && is.finite(x) && x >= min && x <= max &&
        (!whole || x == round(x))
    if (!ok) {
        flag <- paste0("--", gsub("_", "-", name))
        range <- if (is.finite(min)) paste0(" between ", min, " and ", max) else ""
        stop(
            flag, " must be a ", if (whole) "whole " else "", "number", range,
            ", got: ", format(x),
            call. = FALSE
        )
    }
}

# Parse the command-line flags (none when sourced interactively, giving the defaults)
parse_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
    parser <- OptionParser(usage = "Rscript main.R [options]", option_list = cli_options)
    opts <- suppressWarnings(parse_args(parser, args = args))

    check_number(opts, "lon_offset")
    check_number(opts, "lat_offset")
    check_number(opts, "zoom", 1, 18, whole = TRUE)
    check_number(opts, "width", 100, 5000, whole = TRUE)
    check_number(opts, "height", 100, 5000, whole = TRUE)

    # Integers, so Python/Playwright get ints
    opts$zoom <- as.integer(opts$zoom)
    opts$width <- as.integer(opts$width)
    opts$height <- as.integer(opts$height)
    opts
}
