# Column handling ---------------------------------------------------------

tmr_check_data <- function(data, call = caller_env()) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame, not {.obj_type_friendly {data}}.",
      call = call
    )
  }
  if (nrow(data) == 0) {
    cli::cli_abort("{.arg data} must have at least one row.", call = call)
  }
  invisible(data)
}

tmr_pick <- function(quo, data, arg, call = caller_env()) {
  loc <- tidyselect::eval_select(
    quo,
    data,
    allow_rename = FALSE,
    error_call = call
  )
  if (length(loc) != 1) {
    cli::cli_abort(
      "{.arg {arg}} must select exactly one column, not {length(loc)}.",
      call = call
    )
  }
  names(loc)
}

tmr_group_cols <- function(data, by, call = caller_env()) {
  by_cols <- names(tidyselect::eval_select(by, data, error_call = call))
  if (length(by_cols) > 0 && dplyr::is_grouped_df(data)) {
    cli::cli_abort(
      "Can't supply {.arg .by} when {.arg data} is a grouped data frame.",
      call = call
    )
  }
  if (length(by_cols) == 0) {
    by_cols <- dplyr::group_vars(data)
  }
  by_cols
}

tmr_check_number <- function(x, arg, min = 0, max = Inf, whole = FALSE,
                             call = caller_env()) {
  ok <- is.numeric(x) && length(x) == 1 && !is.na(x) && x >= min && x <= max
  if (ok && whole) ok <- abs(x - round(x)) < 1e-8
  if (!ok) {
    what <- if (whole) "a whole number" else "a number"
    cli::cli_abort(
      "{.arg {arg}} must be {what} between {min} and {max}.",
      call = call
    )
  }
  invisible(x)
}

tmr_new <- function(x, class) {
  tibble::new_tibble(x, class = class)
}
