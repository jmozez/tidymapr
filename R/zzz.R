.onLoad <- function(libname, pkgname) {
  # Register tidymapr's advisor with tidyvisor, replacing tidyvisor's
  # built-in one, so tidyvisor() uses the functions of this version.
  tidyvisor::register_advisor(
    package = pkgname,
    title = "Spatial ecology: distributions, spread, epidemics, range shifts",
    questions = c("distribution", "spread", "epidemic", "range_shift", "autocorrelation"),
    classes = c(
      "tmr_epi_growth", "tmr_spread_rate", "tmr_epidemic", "tmr_shift_ensemble",
      "tmr_sdm_ensemble", "tmr_sdm_integrated", "tmr_geo_moran"
    ),
    advise = tmr_advise,
    interpret = tmr_interpret,
    claims = function(x, args) {
      # community data (often with coordinates too) belong to tidydiversity
      if (any(c("abundance", "formula", "treatment") %in% args)) {
        return(FALSE)
      }
      nm <- tolower(names(x))
      any(c("date", "cases", "lon", "lat", "longitude", "latitude", "presence") %in% c(nm, args))
    }
  )
}
