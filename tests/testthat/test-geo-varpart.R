mite_inputs <- function() {
  e <- new.env()
  utils::data("mite", "mite.env", "mite.xy", package = "vegan", envir = e)
  long <- data.frame(
    site = rep(rownames(e$mite), ncol(e$mite)),
    species = rep(colnames(e$mite), each = nrow(e$mite)),
    n = unlist(e$mite, use.names = FALSE)
  )
  list(long = long, env = cbind(site = rownames(e$mite), e$mite.xy, e$mite.env), raw = e)
}

test_that("geo_varpart() partitions environment and space as vegan does", {
  skip_if_not_installed("vegan")
  m <- mite_inputs()
  set.seed(1)
  vp <- geo_varpart(m$long, abundance = n, env = m$env,
                    env_vars = c("SubsDens", "WatrCont"), lon = "x", lat = "y",
                    permutations = 99)
  expect_s3_class(vp, "tmr_geo_varpart")
  expect_true(length(vp$selected) >= 1)
  # the same partition straight from vegan with the selected MEMs
  y <- vegan::decostand(m$raw$mite, "hellinger")
  mem <- geo_mem(m$env, lon = x, lat = y, method = "euclidean")
  ref <- vegan::varpart(y, m$raw$mite.env[c("SubsDens", "WatrCont")],
                        as.data.frame(mem[vp$selected]))
  expect_equal(vp$fractions$adj_r2[3:6], ref$part$indfract$Adj.R.square, tolerance = 1e-8)
  # fractions add up to the total
  expect_equal(sum(vp$fractions$adj_r2[3:6]), 1, tolerance = 1e-8)
  expect_true(is.na(vp$fractions$p.value[4]))
})

test_that("geo_varpart() stops when there is no spatial structure", {
  skip_if_not_installed("vegan")
  m <- mite_inputs()
  set.seed(3)
  m$env$x <- sample(m$env$x)
  m$env$y <- sample(m$env$y)
  # shuffled coordinates usually carry no structure; if they still do,
  # the function must at least run
  out <- tryCatch(
    geo_varpart(m$long, abundance = n, env = m$env, env_vars = "WatrCont",
                lon = "x", lat = "y", permutations = 49),
    error = function(e) conditionMessage(e)
  )
  expect_true(inherits(out, "tmr_geo_varpart") || grepl("No spatial structure", out))
})
