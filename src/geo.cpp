#include <Rcpp.h>
#include <cmath>
#include <algorithm>
using namespace Rcpp;

static inline double haversine_m(double lon1, double lat1,
                                 double lon2, double lat2) {
  const double to_rad = M_PI / 180.0;
  const double dlon = (lon2 - lon1) * to_rad;
  const double dlat = (lat2 - lat1) * to_rad;
  const double a = std::sin(dlat / 2.0) * std::sin(dlat / 2.0) +
    std::cos(lat1 * to_rad) * std::cos(lat2 * to_rad) *
    std::sin(dlon / 2.0) * std::sin(dlon / 2.0);
  return 6371000.0 * 2.0 * std::atan2(std::sqrt(a), std::sqrt(std::max(0.0, 1.0 - a)));
}

// Pairwise haversine distances for equal-length vectors (pair i uses i-th
// elements of each vector). Used by geo_distance().
// [[Rcpp::export]]
NumericVector geo_haversine_pair_cpp(NumericVector lon1, NumericVector lat1,
                                     NumericVector lon2, NumericVector lat2) {
  const int n = lon1.size();
  if (lat1.size() != n || lon2.size() != n || lat2.size() != n) {
    stop("All coordinate vectors must have the same length.");
  }
  NumericVector out(n);
  for (int i = 0; i < n; ++i) {
    if (!R_finite(lon1[i]) || !R_finite(lat1[i]) ||
        !R_finite(lon2[i]) || !R_finite(lat2[i])) {
      out[i] = NA_REAL;
    } else {
      out[i] = haversine_m(lon1[i], lat1[i], lon2[i], lat2[i]);
    }
  }
  return out;
}

// Dense n x n haversine distance matrix for Moran's I and cleaning.
// [[Rcpp::export]]
NumericMatrix geo_haversine_matrix_cpp(NumericVector lon, NumericVector lat) {
  const int n = lon.size();
  if (lat.size() != n) stop("`lon` and `lat` must have the same length.");
  NumericMatrix out(n, n);
  for (int i = 0; i < n; ++i) {
    out(i, i) = 0.0;
    for (int j = i + 1; j < n; ++j) {
      double d = NA_REAL;
      if (R_finite(lon[i]) && R_finite(lat[i]) &&
          R_finite(lon[j]) && R_finite(lat[j])) {
        d = haversine_m(lon[i], lat[i], lon[j], lat[j]);
      }
      out(i, j) = d;
      out(j, i) = d;
    }
  }
  return out;
}

// Pairwise Euclidean distances on equal-length vectors (pair i).
// [[Rcpp::export]]
NumericVector geo_euclidean_pair_cpp(NumericMatrix x1, NumericMatrix x2) {
  const int n = x1.nrow();
  const int p = x1.ncol();
  if (x2.nrow() != n || x2.ncol() != p) {
    stop("`x1` and `x2` must have the same dimensions.");
  }
  NumericVector out(n);
  for (int i = 0; i < n; ++i) {
    double s = 0.0;
    bool ok = true;
    for (int j = 0; j < p; ++j) {
      if (!R_finite(x1(i, j)) || !R_finite(x2(i, j))) {
        ok = false;
        break;
      }
      const double d = x1(i, j) - x2(i, j);
      s += d * d;
    }
    out[i] = ok ? std::sqrt(s) : NA_REAL;
  }
  return out;
}

// Dense n x n Euclidean distance matrix from an n x p matrix (rows = sites).
// [[Rcpp::export]]
NumericMatrix geo_euclidean_matrix_cpp(NumericMatrix x) {
  const int n = x.nrow();
  const int p = x.ncol();
  NumericMatrix out(n, n);
  for (int i = 0; i < n; ++i) {
    out(i, i) = 0.0;
    for (int j = i + 1; j < n; ++j) {
      double s = 0.0;
      bool ok = true;
      for (int k = 0; k < p; ++k) {
        if (!R_finite(x(i, k)) || !R_finite(x(j, k))) {
          ok = false;
          break;
        }
        const double d = x(i, k) - x(j, k);
        s += d * d;
      }
      const double v = ok ? std::sqrt(s) : NA_REAL;
      out(i, j) = v;
      out(j, i) = v;
    }
  }
  return out;
}

// Count neighbours within radius for each point (local metre or planar coords).
// [[Rcpp::export]]
IntegerVector geo_neighbour_count_cpp(NumericVector x, NumericVector y,
                                      double radius) {
  const int n = x.size();
  if (y.size() != n) stop("`x` and `y` must have the same length.");
  if (!(radius >= 0.0)) stop("`radius` must be non-negative.");
  const double r2 = radius * radius;
  IntegerVector out(n);
  for (int i = 0; i < n; ++i) {
    int c = 0;
    if (!R_finite(x[i]) || !R_finite(y[i])) {
      out[i] = NA_INTEGER;
      continue;
    }
    for (int j = 0; j < n; ++j) {
      if (i == j) continue;
      if (!R_finite(x[j]) || !R_finite(y[j])) continue;
      const double dx = x[i] - x[j];
      const double dy = y[i] - y[j];
      if (dx * dx + dy * dy <= r2) ++c;
    }
    out[i] = c;
  }
  return out;
}

// Torus-shift a rectangular habitat grid by (dx, dy) cells with wrap-around.
// grid is nrow*ncol integers in row-major order (row 0 = top).
// [[Rcpp::export]]
IntegerVector geo_torus_shift_cpp(IntegerVector grid, int nrow, int ncol,
                                  int dx, int dy) {
  if (grid.size() != nrow * ncol) {
    stop("`grid` length must equal nrow * ncol.");
  }
  IntegerVector out(nrow * ncol);
  // Normalise shifts into [0, ncol) / [0, nrow)
  int sx = dx % ncol;
  if (sx < 0) sx += ncol;
  int sy = dy % nrow;
  if (sy < 0) sy += nrow;
  for (int r = 0; r < nrow; ++r) {
    for (int c = 0; c < ncol; ++c) {
      const int rr = (r + sy) % nrow;
      const int cc = (c + sx) % ncol;
      out[rr * ncol + cc] = grid[r * ncol + c];
    }
  }
  return out;
}

// Spatially ordered accumulation: given distance-to-seed for each sample and
// species incidence (n_samples x n_species 0/1), return cumulative richness
// after adding samples in increasing distance order.
// [[Rcpp::export]]
IntegerVector geo_spatial_rarefy_cpp(NumericVector dist_to_seed,
                                     IntegerMatrix incidence) {
  const int n = dist_to_seed.size();
  const int s = incidence.ncol();
  if (incidence.nrow() != n) {
    stop("`incidence` rows must match `dist_to_seed` length.");
  }
  IntegerVector order = seq(0, n - 1);
  // Argsort by distance (stable for ties by index)
  std::sort(order.begin(), order.end(), [&](int a, int b) {
    if (dist_to_seed[a] < dist_to_seed[b]) return true;
    if (dist_to_seed[a] > dist_to_seed[b]) return false;
    return a < b;
  });
  IntegerVector seen(s);
  IntegerVector out(n);
  int rich = 0;
  for (int k = 0; k < n; ++k) {
    const int i = order[k];
    for (int j = 0; j < s; ++j) {
      if (incidence(i, j) > 0 && seen[j] == 0) {
        seen[j] = 1;
        ++rich;
      }
    }
    out[k] = rich;
  }
  return out;
}

// Linear predictor -> cloglog probability for large grids.
// [[Rcpp::export]]
NumericVector sdm_cloglog_cpp(NumericVector eta) {
  const int n = eta.size();
  NumericVector out(n);
  for (int i = 0; i < n; ++i) {
    if (!R_finite(eta[i])) {
      out[i] = NA_REAL;
    } else {
      // 1 - exp(-exp(eta)), clamped
      const double e = std::exp(eta[i]);
      const double p = 1.0 - std::exp(-e);
      if (p < 0.0) out[i] = 0.0;
      else if (p > 1.0) out[i] = 1.0;
      else out[i] = p;
    }
  }
  return out;
}

// Logistic (logit link) probability.
// [[Rcpp::export]]
NumericVector sdm_logistic_cpp(NumericVector eta) {
  const int n = eta.size();
  NumericVector out(n);
  for (int i = 0; i < n; ++i) {
    if (!R_finite(eta[i])) {
      out[i] = NA_REAL;
    } else {
      if (eta[i] >= 0) {
        const double e = std::exp(-eta[i]);
        out[i] = 1.0 / (1.0 + e);
      } else {
        const double e = std::exp(eta[i]);
        out[i] = e / (1.0 + e);
      }
    }
  }
  return out;
}

// Matrix-vector product X %*% beta for prediction grids (n x p) * p.
// [[Rcpp::export]]
NumericVector sdm_linear_predict_cpp(NumericMatrix x, NumericVector beta) {
  const int n = x.nrow();
  const int p = x.ncol();
  if (beta.size() != p) stop("`beta` length must equal ncol(x).");
  NumericVector out(n);
  for (int i = 0; i < n; ++i) {
    double s = 0.0;
    bool ok = true;
    for (int j = 0; j < p; ++j) {
      if (!R_finite(x(i, j)) || !R_finite(beta[j])) {
        ok = false;
        break;
      }
      s += x(i, j) * beta[j];
    }
    out[i] = ok ? s : NA_REAL;
  }
  return out;
}
