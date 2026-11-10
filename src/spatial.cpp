#include <Rcpp.h>
#include <cmath>
#include <vector>
#include <algorithm>
#include <limits>
#include <random>
#ifdef _OPENMP
#include <omp.h>
#endif
using namespace Rcpp;

static inline int tmr_threads(int threads) {
#ifdef _OPENMP
  return threads > 0 ? threads : 1;
#else
  (void) threads;
  return 1;
#endif
}

static inline double hav_m(double lon1, double lat1, double lon2, double lat2) {
  const double r = M_PI / 180.0;
  const double dlon = (lon2 - lon1) * r;
  const double dlat = (lat2 - lat1) * r;
  const double a = std::sin(dlat / 2.0) * std::sin(dlat / 2.0) +
    std::cos(lat1 * r) * std::cos(lat2 * r) *
    std::sin(dlon / 2.0) * std::sin(dlon / 2.0);
  return 6371000.0 * 2.0 * std::atan2(std::sqrt(a), std::sqrt(std::max(0.0, 1.0 - a)));
}

static inline double dist_xy(double x1, double y1, double x2, double y2,
                             bool lonlat) {
  if (lonlat) return hav_m(x1, y1, x2, y2);
  const double dx = x1 - x2, dy = y1 - y2;
  return std::sqrt(dx * dx + dy * dy);
}

// Fisher-Jenks optimal classification of sorted values into k classes
// (minimum within-class sum of squares; Fisher 1958, Jenks 1977). Returns
// the k - 1 inner break values (upper bounds of classes 1 .. k - 1).
// [[Rcpp::export]]
NumericVector geo_jenks_cpp(NumericVector x, int k) {
  const int n = x.size();
  if (k < 2 || n < k) stop("Need at least k values and k >= 2.");
  // Prefix sums for O(1) segment cost
  std::vector<double> s1(n + 1, 0.0), s2(n + 1, 0.0);
  for (int i = 0; i < n; ++i) {
    s1[i + 1] = s1[i] + x[i];
    s2[i + 1] = s2[i] + x[i] * x[i];
  }
  auto ssq = [&](int a, int b) { // segment [a, b] inclusive, 0-based
    const double m = b - a + 1;
    const double s = s1[b + 1] - s1[a];
    return (s2[b + 1] - s2[a]) - s * s / m;
  };
  const double inf = std::numeric_limits<double>::infinity();
  // cost[j][i]: best cost of splitting x[0..i] into j + 1 classes
  std::vector<std::vector<double>> cost(k, std::vector<double>(n, inf));
  std::vector<std::vector<int>> back(k, std::vector<int>(n, 0));
  for (int i = 0; i < n; ++i) cost[0][i] = ssq(0, i);
  for (int j = 1; j < k; ++j) {
    for (int i = j; i < n; ++i) {
      double best = inf;
      int arg = j;
      for (int m = j; m <= i; ++m) { // last class is [m, i]
        const double c = cost[j - 1][m - 1] + ssq(m, i);
        if (c < best) { best = c; arg = m; }
      }
      cost[j][i] = best;
      back[j][i] = arg;
    }
  }
  NumericVector brk(k - 1);
  int i = n - 1;
  for (int j = k - 1; j >= 1; --j) {
    const int m = back[j][i];
    brk[j - 1] = x[m - 1];
    i = m - 1;
  }
  return brk;
}

// Inverse-distance-weighted prediction. A target that coincides with a
// sample takes its value. maxdist <= 0 means no limit.
// [[Rcpp::export]]
NumericVector geo_idw_cpp(NumericVector xs, NumericVector ys, NumericVector zs,
                          NumericVector xp, NumericVector yp, double power,
                          bool lonlat, double maxdist, int threads = 1) {
  const int ns = xs.size(), np = xp.size();
  NumericVector out(np);
  const double *X = xs.begin(), *Y = ys.begin(), *Z = zs.begin();
  const double *PX = xp.begin(), *PY = yp.begin();
  double *O = out.begin();
#ifdef _OPENMP
#pragma omp parallel for num_threads(tmr_threads(threads)) schedule(static)
#endif
  for (int p = 0; p < np; ++p) {
    double num = 0.0, den = 0.0;
    bool exact = false;
    for (int s = 0; s < ns; ++s) {
      const double d = dist_xy(X[s], Y[s], PX[p], PY[p], lonlat);
      if (maxdist > 0 && d > maxdist) continue;
      if (d < 1e-12) { O[p] = Z[s]; exact = true; break; }
      const double w = power == 2.0 ? 1.0 / (d * d) : 1.0 / std::pow(d, power);
      num += w * Z[s];
      den += w;
    }
    if (!exact) O[p] = den > 0 ? num / den : NA_REAL;
  }
  return out;
}

static double vario(double h, int model, double nugget, double psill,
                    double range) {
  if (h <= 0) return 0.0;
  double g;
  if (model == 1) { // exponential
    g = 1.0 - std::exp(-h / range);
  } else if (model == 2) { // spherical
    const double r = h / range;
    g = r >= 1.0 ? 1.0 : 1.5 * r - 0.5 * r * r * r;
  } else { // gaussian
    g = 1.0 - std::exp(-(h * h) / (range * range));
  }
  return nugget + psill * g;
}

// Ordinary kriging with a fitted variogram (model 1 exponential,
// 2 spherical, 3 gaussian; gstat's parameterisation). Solves the full
// system once and returns prediction and kriging variance per target.
// [[Rcpp::export]]
List geo_krige_cpp(NumericVector xs, NumericVector ys, NumericVector zs,
                   NumericVector xp, NumericVector yp, int model,
                   double nugget, double psill, double range, bool lonlat,
                   bool variance = true, int threads = 1) {
  const int n = xs.size(), np = xp.size();
  const int m = n + 1;
  NumericMatrix A(m, m);
  for (int i = 0; i < n; ++i) {
    for (int j = 0; j < n; ++j) {
      A(i, j) = i == j ? 0.0 :
        vario(dist_xy(xs[i], ys[i], xs[j], ys[j], lonlat), model, nugget, psill, range);
    }
    A(i, n) = 1.0;
    A(n, i) = 1.0;
  }
  A(n, n) = 0.0;
  // Invert A once with Gauss-Jordan elimination (partial pivoting)
  std::vector<double> a(m * m), inv(m * m, 0.0);
  for (int i = 0; i < m; ++i) {
    for (int j = 0; j < m; ++j) a[i * m + j] = A(i, j);
    inv[i * m + i] = 1.0;
  }
  for (int c = 0; c < m; ++c) {
    int piv = c;
    for (int r = c + 1; r < m; ++r) {
      if (std::fabs(a[r * m + c]) > std::fabs(a[piv * m + c])) piv = r;
    }
    if (std::fabs(a[piv * m + c]) < 1e-14) stop("Kriging system is singular (duplicate locations?).");
    if (piv != c) {
      for (int j = 0; j < m; ++j) {
        std::swap(a[c * m + j], a[piv * m + j]);
        std::swap(inv[c * m + j], inv[piv * m + j]);
      }
    }
    const double d = a[c * m + c];
    for (int j = 0; j < m; ++j) { a[c * m + j] /= d; inv[c * m + j] /= d; }
    for (int r = 0; r < m; ++r) {
      if (r == c) continue;
      const double f = a[r * m + c];
      if (f == 0.0) continue;
      for (int j = 0; j < m; ++j) {
        a[r * m + j] -= f * a[c * m + j];
        inv[r * m + j] -= f * inv[c * m + j];
      }
    }
  }
  NumericVector pred(np), var(np);
  // Prediction is b . (A^-1 z): precompute alpha = A^-1 [z, 0] once, so each
  // target costs O(n) instead of O(n^2). A^-1 is symmetric.
  std::vector<double> alpha(m, 0.0);
  for (int i = 0; i < m; ++i) {
    double s2 = 0.0;
    for (int j = 0; j < n; ++j) s2 += inv[i * m + j] * zs[j];
    alpha[i] = s2;
  }
  const double *XS = xs.begin(), *YS = ys.begin(), *XP = xp.begin(), *YP = yp.begin();
  double *PR = pred.begin(), *VA = var.begin();
#ifdef _OPENMP
#pragma omp parallel for num_threads(tmr_threads(threads)) schedule(static)
#endif
  for (int p = 0; p < np; ++p) {
    std::vector<double> b(m);
    for (int i = 0; i < n; ++i) {
      b[i] = vario(dist_xy(XS[i], YS[i], XP[p], YP[p], lonlat), model, nugget, psill, range);
    }
    b[n] = 1.0;
    double z = 0.0;
    for (int i = 0; i < m; ++i) z += b[i] * alpha[i];
    PR[p] = z;
    if (variance) {
      // sigma^2 = b' A^-1 b, using symmetry of A^-1
      double v = 0.0;
      for (int i = 0; i < m; ++i) {
        const double *row = &inv[i * m];
        double s2 = 0.0;
        for (int j = 0; j < m; ++j) s2 += row[j] * b[j];
        v += b[i] * s2;
      }
      VA[p] = v;
    } else {
      VA[p] = NA_REAL;
    }
  }
  return List::create(_["prediction"] = pred, _["variance"] = var);
}

// D8 flow direction on a DEM stored row-major (row 0 at the top). Codes
// follow ESRI / terra: 1 E, 2 SE, 4 S, 8 SW, 16 W, 32 NW, 64 N, 128 NE;
// 0 for a pit or flat cell with no lower neighbour; NA for NA cells.
// [[Rcpp::export]]
IntegerVector geo_d8_cpp(NumericVector z, int nrow, int ncol, double xres,
                         double yres) {
  const int dr[8] = {0, 1, 1, 1, 0, -1, -1, -1};
  const int dc[8] = {1, 1, 0, -1, -1, -1, 0, 1};
  const int code[8] = {1, 2, 4, 8, 16, 32, 64, 128};
  const double diag = std::sqrt(xres * xres + yres * yres);
  IntegerVector out(nrow * ncol);
  for (int r = 0; r < nrow; ++r) {
    for (int c = 0; c < ncol; ++c) {
      const int i = r * ncol + c;
      if (ISNAN(z[i])) { out[i] = NA_INTEGER; continue; }
      double best = 0.0;
      int dir = 0;
      for (int k = 0; k < 8; ++k) {
        const int rr = r + dr[k], cc = c + dc[k];
        if (rr < 0 || rr >= nrow || cc < 0 || cc >= ncol) continue;
        const double zn = z[rr * ncol + cc];
        if (ISNAN(zn)) continue;
        const double len = (dr[k] != 0 && dc[k] != 0) ? diag : (dr[k] != 0 ? yres : xres);
        const double drop = (z[i] - zn) / len;
        if (drop > best) { best = drop; dir = code[k]; }
      }
      out[i] = dir;
    }
  }
  return out;
}

static inline int d8_target(int code, int r, int c, int nrow, int ncol) {
  int dr, dc;
  switch (code) {
  case 1: dr = 0; dc = 1; break;
  case 2: dr = 1; dc = 1; break;
  case 4: dr = 1; dc = 0; break;
  case 8: dr = 1; dc = -1; break;
  case 16: dr = 0; dc = -1; break;
  case 32: dr = -1; dc = -1; break;
  case 64: dr = -1; dc = 0; break;
  case 128: dr = -1; dc = 1; break;
  default: return -1;
  }
  const int rr = r + dr, cc = c + dc;
  if (rr < 0 || rr >= nrow || cc < 0 || cc >= ncol) return -1;
  return rr * ncol + cc;
}

// Flow accumulation (number of upslope cells, including the cell itself)
// from D8 codes, by topological order (Kahn's algorithm), O(n).
// [[Rcpp::export]]
NumericVector geo_flowacc_cpp(IntegerVector dir, int nrow, int ncol,
                              NumericVector weight) {
  const int n = nrow * ncol;
  std::vector<int> to(n, -1), indeg(n, 0);
  for (int r = 0; r < nrow; ++r) {
    for (int c = 0; c < ncol; ++c) {
      const int i = r * ncol + c;
      if (dir[i] == NA_INTEGER) continue;
      const int t = d8_target(dir[i], r, c, nrow, ncol);
      if (t >= 0 && dir[t] != NA_INTEGER) { to[i] = t; indeg[t]++; }
    }
  }
  NumericVector acc(n);
  std::vector<int> queue;
  queue.reserve(n);
  for (int i = 0; i < n; ++i) {
    if (dir[i] == NA_INTEGER) { acc[i] = NA_REAL; continue; }
    acc[i] = weight[i];
    if (indeg[i] == 0) queue.push_back(i);
  }
  for (size_t q = 0; q < queue.size(); ++q) {
    const int i = queue[q];
    const int t = to[i];
    if (t < 0) continue;
    acc[t] += acc[i];
    if (--indeg[t] == 0) queue.push_back(t);
  }
  return acc;
}

// Watershed labels: every cell that drains (by D8) into outlet k gets
// label k (1-based); others get NA.
// [[Rcpp::export]]
IntegerVector geo_watershed_cpp(IntegerVector dir, int nrow, int ncol,
                                IntegerVector outlets) {
  const int n = nrow * ncol;
  std::vector<int> to(n, -1);
  for (int r = 0; r < nrow; ++r) {
    for (int c = 0; c < ncol; ++c) {
      const int i = r * ncol + c;
      if (dir[i] == NA_INTEGER) continue;
      to[i] = d8_target(dir[i], r, c, nrow, ncol);
    }
  }
  // Reverse graph: walk upstream from each outlet
  std::vector<std::vector<int>> from(n);
  for (int i = 0; i < n; ++i) if (to[i] >= 0) from[to[i]].push_back(i);
  IntegerVector lab(n, NA_INTEGER);
  for (int k = 0; k < outlets.size(); ++k) {
    const int o = outlets[k];
    if (o < 0 || o >= n) continue;
    std::vector<int> stack(1, o);
    lab[o] = k + 1;
    while (!stack.empty()) {
      const int i = stack.back();
      stack.pop_back();
      for (int u : from[i]) {
        if (lab[u] == NA_INTEGER) { lab[u] = k + 1; stack.push_back(u); }
      }
    }
  }
  return lab;
}


// k nearest neighbours by great-circle (or planar) distance. Returns a
// 1-based n x k index matrix, nearest first. Partial sort per row: O(n log k).
// [[Rcpp::export]]
IntegerMatrix geo_knn_cpp(NumericVector x, NumericVector y, int k, bool lonlat,
                          int threads = 1) {
  const int n = x.size();
  IntegerMatrix out(n, k);
  const double *X = x.begin(), *Y = y.begin();
#ifdef _OPENMP
#pragma omp parallel for num_threads(tmr_threads(threads)) schedule(dynamic, 64)
#endif
  for (int i = 0; i < n; ++i) {
    std::vector<std::pair<double, int>> d;
    d.reserve(n - 1);
    for (int j = 0; j < n; ++j) {
      if (j == i) continue;
      d.emplace_back(dist_xy(X[i], Y[i], X[j], Y[j], lonlat), j);
    }
    std::partial_sort(d.begin(), d.begin() + k, d.end());
    for (int r = 0; r < k; ++r) out(i, r) = d[r].second + 1;
  }
  return out;
}

// Conditional permutation p-values for local Moran's I (Anselin 1995):
// for site i, its neighbours' values are drawn at random from the other
// n - 1 sites. nb and w are row-major n x kmax (0 = no neighbour). Each
// site gets its own generator seeded from R, so results follow set.seed()
// and do not depend on the number of threads.
// [[Rcpp::export]]
NumericVector geo_lisa_perm_cpp(NumericVector z, IntegerVector nb,
                                NumericVector w, IntegerVector nnb, int kmax,
                                int nperm, int threads = 1) {
  const int n = z.size();
  NumericVector p(n);
  std::vector<unsigned int> seeds(n);
  for (int i = 0; i < n; ++i) {
    seeds[i] = static_cast<unsigned int>(R::unif_rand() * 4294967295.0);
  }
  const double *Z = z.begin(), *W = w.begin();
  const int *NB = nb.begin(), *NN = nnb.begin();
  double *P = p.begin();
#ifdef _OPENMP
#pragma omp parallel for num_threads(tmr_threads(threads)) schedule(dynamic, 16)
#endif
  for (int i = 0; i < n; ++i) {
    const int k = NN[i];
    double obs = 0.0;
    for (int r = 0; r < k; ++r) obs += W[i * kmax + r] * Z[NB[i * kmax + r] - 1];
    std::vector<int> pool;
    pool.reserve(n - 1);
    for (int j = 0; j < n; ++j) if (j != i) pool.push_back(j);
    std::mt19937 gen(seeds[i]);
    int ge = 0, le = 0;
    const int m = n - 1;
    for (int b = 0; b < nperm; ++b) {
      double sim = 0.0;
      for (int r = 0; r < k; ++r) {
        std::uniform_int_distribution<int> pick(r, m - 1);
        const int q = pick(gen);
        std::swap(pool[r], pool[q]);
        sim += W[i * kmax + r] * Z[pool[r]];
      }
      if (sim >= obs) ++ge;
      if (sim <= obs) ++le;
    }
    P[i] = std::min(1.0, (1.0 + std::min(ge, le)) * 2.0 / (nperm + 1.0));
  }
  return p;
}

// Longest edge of the minimum spanning tree of a distance matrix (Prim's
// algorithm, O(n^2)): the truncation distance used by geo_mem().
// [[Rcpp::export]]
double geo_mst_max_edge_cpp(NumericMatrix d) {
  const int n = d.nrow();
  if (n < 2) return 0.0;
  std::vector<double> best(n, std::numeric_limits<double>::infinity());
  std::vector<bool> in(n, false);
  in[0] = true;
  for (int j = 1; j < n; ++j) if (std::isfinite(d(0, j))) best[j] = d(0, j);
  double max_edge = 0.0;
  for (int step = 1; step < n; ++step) {
    int pick = -1;
    double val = std::numeric_limits<double>::infinity();
    for (int j = 0; j < n; ++j) {
      if (!in[j] && best[j] < val) { val = best[j]; pick = j; }
    }
    if (pick < 0) break;  // disconnected (infinite distances)
    in[pick] = true;
    if (val > max_edge) max_edge = val;
    for (int j = 0; j < n; ++j) {
      const double dj = d(pick, j);
      if (!in[j] && std::isfinite(dj) && dj < best[j]) best[j] = dj;
    }
  }
  return max_edge;
}
