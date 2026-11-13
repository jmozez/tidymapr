// Stochastic colonisation-extinction simulation of range shifts on a grid.
//
// Each time step, an empty cell j is colonised with probability
//   1 - exp(-c * s_j * sum_i K(d_ij)),  K(d) = exp(-d / mean) for d <= max,
// summed over occupied cells i (propagule pressure from a negative
// exponential dispersal kernel). The kernel is normalised to sum to 1 over
// the neighbourhood, so the pressure is the kernel-weighted share of
// occupied neighbours (0 to 1) and does not depend on the cell size; and an occupied cell persists with
// probability s_j ^ p. Suitability s in [0, 1]; negative values are
// unsuitable (water, outside the study area). Colonisation is computed
// from the occupancy at the start of the step (synchronous update).
// Simulations run in parallel with independent random streams, so results
// do not depend on the number of threads.

#include <Rcpp.h>
#include <random>
#include <vector>
#include <cmath>
#ifdef _OPENMP
#include <omp.h>
#endif

using namespace Rcpp;

struct Offset {
  int dr, dc;
  double w;
};

// [[Rcpp::export]]
NumericMatrix shift_simulate_cpp(NumericMatrix suit, IntegerVector init,
                                 int nrow, int ncol, NumericVector cell_w,
                                 double cell_h, double kmean, double kmax,
                                 double colon, double persist, int sub_steps,
                                 int nsim, double seed, int threads) {
  const int ncell = nrow * ncol;
  const int nlayer = suit.ncol();
  if (suit.nrow() != ncell || init.size() != ncell || cell_w.size() != nrow) {
    stop("Dimension mismatch.");
  }
  // Dispersal offsets for each row (cell width changes with latitude)
  std::vector<std::vector<Offset>> off(nrow);
  for (int r = 0; r < nrow; ++r) {
    double cw = cell_w[r];
    int rr = static_cast<int>(std::floor(kmax / cell_h));
    int rc = static_cast<int>(std::floor(kmax / cw));
    for (int dr = -rr; dr <= rr; ++dr) {
      for (int dc = -rc; dc <= rc; ++dc) {
        if (dr == 0 && dc == 0) continue;
        double d = std::sqrt(std::pow(dr * cell_h, 2) + std::pow(dc * cw, 2));
        if (d <= kmax) off[r].push_back({dr, dc, std::exp(-d / kmean)});
      }
    }
    double tot = 0.0;
    for (const Offset& o : off[r]) tot += o.w;
    if (tot > 0) {
      for (Offset& o : off[r]) o.w /= tot;
    }
  }
  std::vector<double> s(suit.begin(), suit.end());
  std::vector<double> acc(static_cast<size_t>(ncell) * nlayer, 0.0);
#ifdef _OPENMP
  if (threads > 0) omp_set_num_threads(threads);
#endif
#pragma omp parallel
  {
    std::vector<double> local(static_cast<size_t>(ncell) * nlayer, 0.0);
    std::vector<unsigned char> occ(ncell), next(ncell);
    std::vector<double> press(ncell);
    std::uniform_real_distribution<double> unif(0.0, 1.0);
#pragma omp for schedule(static)
    for (int k = 0; k < nsim; ++k) {
      std::mt19937_64 rng(static_cast<uint64_t>(seed) * 1000003ULL + k);
      for (int j = 0; j < ncell; ++j) occ[j] = init[j] > 0 ? 1 : 0;
      for (int t = 0; t < nlayer; ++t) {
        const double* st = &s[static_cast<size_t>(t) * ncell];
        for (int sub = 0; sub < sub_steps; ++sub) {
          std::fill(press.begin(), press.end(), 0.0);
          for (int j = 0; j < ncell; ++j) {
            if (!occ[j]) continue;
            int r = j / ncol, c = j % ncol;  // row-major cell index (terra order)
            for (const Offset& o : off[r]) {
              int r2 = r + o.dr, c2 = c + o.dc;
              if (r2 < 0 || r2 >= nrow || c2 < 0 || c2 >= ncol) continue;
              press[r2 * ncol + c2] += o.w;
            }
          }
          for (int j = 0; j < ncell; ++j) {
            double sj = st[j];
            if (!(sj > 0)) {
              next[j] = 0;
            } else if (occ[j]) {
              next[j] = unif(rng) < std::pow(sj, persist) ? 1 : 0;
            } else if (press[j] > 0) {
              double pc = 1.0 - std::exp(-colon * sj * press[j]);
              next[j] = unif(rng) < pc ? 1 : 0;
            } else {
              next[j] = 0;
            }
          }
          occ.swap(next);
        }
        double* lt = &local[static_cast<size_t>(t) * ncell];
        for (int j = 0; j < ncell; ++j) lt[j] += occ[j];
      }
    }
#pragma omp critical
    for (size_t i = 0; i < acc.size(); ++i) acc[i] += local[i];
  }
  NumericMatrix out(ncell, nlayer);
  for (size_t i = 0; i < acc.size(); ++i) out[i] = acc[i] / nsim;
  return out;
}
