// Stochastic spread on a grid: range shifts (colonisation-extinction) and
// spatial epidemics (SIR).
//
// Dispersal kernels. The kernel is a 2D density f(d) of the distance d
// between source and destination, truncated at kmax and normalised to sum
// to 1 over the neighbourhood, so the pressure on a cell is the
// kernel-weighted share of occupied (or infected) neighbours and does not
// depend on the cell size.
//   * exponential: f(d) = exp(-d / a), a = mean / 2 (in two dimensions the
//     distance of an exponential density is Gamma(2, a), mean 2a);
//   * 2Dt (Clark et al. 1999), fat-tailed: f(d) = (1 + d^2 / u)^-(p + 1),
//     with u chosen so that the mean distance is `mean`:
//     mean = sqrt(pi u) / 2 * Gamma(p - 1/2) / Gamma(p), p > 1/2.
// Resistance (optional): the distance is replaced by an effective distance,
// d times the mean resistance of the cells crossed on the straight line
// from source to destination (1 = baseline; cells with resistance <= 0 or
// missing are impassable). This straight-line approximation keeps the
// computation local; it is not a least-cost path.
//
// Range shifts. Each step an empty cell j is colonised with probability
//   1 - exp(-c * s_j * P_j),  P_j = sum_i K(i, j) over occupied cells i,
// and an occupied cell persists with probability s_j^p * (1 - D_j), where D
// is an optional disturbance probability (clearing, fire, eradication).
// Long-distance jumps (optional): each step, Poisson(rate * occupied cells)
// propagules land on cells drawn in proportion to jump weights (roads,
// ports, towns) and establish with probability s_j.
//
// Epidemics. Chain-binomial SIR with hosts N_j per cell. Each step a
// susceptible in cell j is infected with probability 1 - exp(-lambda_j),
//   lambda_j = beta * ((1 - m) * I_j / N_j + m * sum_i K(i, j) I_i / N_i),
// infected hosts recover with probability 1 - exp(-gamma) and recovered
// hosts lose immunity with probability 1 - exp(-omega). An infected host
// stays infectious for 1 / (1 - exp(-gamma)) steps on average, so in a
// well-mixed population R0 = beta / (1 - exp(-gamma)).
//
// Simulations run in parallel with independent random streams, so results
// do not depend on the number of threads.

#include <Rcpp.h>
#include <random>
#include <vector>
#include <cmath>
#include <algorithm>
#ifdef _OPENMP
#include <omp.h>
#endif

using namespace Rcpp;

struct Offset {
  int dr, dc;
  double d;                  // geometric distance (m)
  double w;                  // normalised kernel weight at distance d
  int path_start, path_len;  // straight-line path cells in Kernel::path
};

struct Kernel {
  int type;        // 0 exponential, 1 2Dt
  double a, u, p;  // parameters
  double kmax;
  std::vector<std::vector<Offset>> uoff;  // unique kernels
  std::vector<double> unorm;              // their normalising constants
  std::vector<int> rowk;                  // kernel used by each row
  const std::vector<Offset>& off(int r) const { return uoff[rowk[r]]; }
  double norm(int r) const { return unorm[rowk[r]]; }
  std::vector<int> path;                 // flattened (dr, dc) pairs
  double f(double d) const {
    if (d > kmax) return 0.0;
    if (type == 0) return std::exp(-d / a);
    return std::pow(1.0 + d * d / u, -(p + 1.0));
  }
};

static Kernel build_kernel(int nrow, NumericVector cell_w, double cell_h,
                           int type, double mean, double shape, double kmax,
                           bool with_path = false) {
  Kernel K;
  K.type = type;
  K.kmax = kmax;
  K.p = shape;
  K.a = mean / 2.0;
  K.u = 1.0;
  if (type == 1) {
    double g = std::exp(std::lgamma(shape - 0.5) - std::lgamma(shape));
    double su = 2.0 * mean / (std::sqrt(M_PI) * g);
    K.u = su * su;
  }
  K.rowk.assign(nrow, 0);
  double last_w = -1.0;
  for (int r = 0; r < nrow; ++r) {
    double cw = cell_w[r];
    // Rows whose cell width differs by under 0.5% share one kernel
    if (last_w > 0 && std::fabs(cw - last_w) <= 0.005 * last_w) {
      K.rowk[r] = static_cast<int>(K.uoff.size()) - 1;
      continue;
    }
    last_w = cw;
    std::vector<Offset> offs;
    int rr = static_cast<int>(std::floor(kmax / cell_h));
    int rc = static_cast<int>(std::floor(kmax / cw));
    double tot = 0.0;
    for (int dr = -rr; dr <= rr; ++dr) {
      for (int dc = -rc; dc <= rc; ++dc) {
        if (dr == 0 && dc == 0) continue;
        double d = std::sqrt(std::pow(dr * cell_h, 2) + std::pow(dc * cw, 2));
        if (d > kmax) continue;
        Offset o;
        o.dr = dr;
        o.dc = dc;
        o.d = d;
        o.w = K.f(d);
        o.path_start = static_cast<int>(K.path.size() / 2);
        int n = std::max(std::abs(dr), std::abs(dc));
        if (with_path) {
          for (int k = 1; k <= n; ++k) {
            K.path.push_back(static_cast<int>(std::lround(static_cast<double>(dr) * k / n)));
            K.path.push_back(static_cast<int>(std::lround(static_cast<double>(dc) * k / n)));
          }
        }
        o.path_len = n;
        tot += o.w;
        offs.push_back(o);
      }
    }
    double nm = tot > 0 ? tot : 1.0;
    for (Offset& o : offs) o.w /= nm;
    K.uoff.push_back(offs);
    K.unorm.push_back(nm);
    K.rowk[r] = static_cast<int>(K.uoff.size()) - 1;
  }
  return K;
}

// Weight from source (r, c) through offset o; resistance optional
static inline double kernel_weight(const Kernel& K, const Offset& o, int r, int c,
                                   int ncol, const double* res) {
  if (res == nullptr) return o.w;
  double sum = 0.0;
  for (int k = 0; k < o.path_len; ++k) {
    int pr = r + K.path[2 * (o.path_start + k)];
    int pc = c + K.path[2 * (o.path_start + k) + 1];
    double v = res[pr * ncol + pc];
    if (!(v > 0) || !std::isfinite(v)) return 0.0;
    sum += v;
  }
  double rbar = sum / o.path_len;
  return K.f(o.d * rbar) / K.norm(r);
}

// [[Rcpp::export]]
List kernel_info_cpp(int nrow, NumericVector cell_w, double cell_h, int type,
                     double mean, double shape, double kmax) {
  Kernel K = build_kernel(nrow, cell_w, cell_h, type, mean, shape, kmax);
  int r = 0;
  double md = 0.0, tail = 0.0;
  for (const Offset& o : K.off(r)) {
    md += o.w * o.d;
    if (o.d > 5 * mean) tail += o.w;
  }
  return List::create(_["realised_mean"] = md, _["share_beyond_5mean"] = tail,
                      _["n_neighbours"] = static_cast<int>(K.off(r).size()),
                      _["u"] = K.u);
}

// [[Rcpp::export]]
NumericMatrix shift_simulate_cpp(NumericMatrix suit, IntegerVector init,
                                 int nrow, int ncol, NumericVector cell_w,
                                 double cell_h, int ktype, double kmean,
                                 double kshape, double kmax, double colon,
                                 double persist, int sub_steps, int nsim,
                                 double seed, int threads,
                                 NumericVector resistance, NumericMatrix disturb,
                                 double jump_rate, NumericVector jump_w) {
  const int ncell = nrow * ncol;
  const int nlayer = suit.ncol();
  if (suit.nrow() != ncell || init.size() != ncell || cell_w.size() != nrow) {
    stop("Dimension mismatch.");
  }
  const bool has_res = resistance.size() == ncell;
  const bool has_dist = disturb.nrow() == ncell;
  const bool has_jump = jump_rate > 0 && jump_w.size() == ncell;
  if (has_dist && disturb.ncol() != nlayer) stop("Disturbance layers mismatch.");
  Kernel K = build_kernel(nrow, cell_w, cell_h, ktype, kmean, kshape, kmax, has_res);
  std::vector<double> s(suit.begin(), suit.end());
  std::vector<double> res;
  if (has_res) res.assign(resistance.begin(), resistance.end());
  std::vector<double> dist;
  if (has_dist) dist.assign(disturb.begin(), disturb.end());
  std::vector<double> cum;
  if (has_jump) {
    cum.resize(ncell);
    double tot = 0.0;
    for (int j = 0; j < ncell; ++j) {
      double v = jump_w[j];
      tot += (std::isfinite(v) && v > 0) ? v : 0.0;
      cum[j] = tot;
    }
    if (!(tot > 0)) stop("Jump weights are all zero.");
  }
  const double* rp = has_res ? res.data() : nullptr;
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
        const double* dt = has_dist ? &dist[static_cast<size_t>(t) * ncell] : nullptr;
        for (int sub = 0; sub < sub_steps; ++sub) {
          std::fill(press.begin(), press.end(), 0.0);
          int n_occ = 0;
          for (int j = 0; j < ncell; ++j) {
            if (!occ[j]) continue;
            ++n_occ;
            int r = j / ncol, c = j % ncol;  // row-major cell index (terra order)
            for (const Offset& o : K.off(r)) {
              int r2 = r + o.dr, c2 = c + o.dc;
              if (r2 < 0 || r2 >= nrow || c2 < 0 || c2 >= ncol) continue;
              press[r2 * ncol + c2] += kernel_weight(K, o, r, c, ncol, rp);
            }
          }
          for (int j = 0; j < ncell; ++j) {
            double sj = st[j];
            if (!(sj > 0)) {
              next[j] = 0;
            } else if (occ[j]) {
              double ps = std::pow(sj, persist);
              if (dt != nullptr) {
                double dj = dt[j];
                if (std::isfinite(dj) && dj > 0) ps *= (1.0 - std::min(dj, 1.0));
              }
              next[j] = unif(rng) < ps ? 1 : 0;
            } else if (press[j] > 0) {
              double pc = 1.0 - std::exp(-colon * sj * press[j]);
              next[j] = unif(rng) < pc ? 1 : 0;
            } else {
              next[j] = 0;
            }
          }
          if (has_jump && n_occ > 0) {
            std::poisson_distribution<int> pois(jump_rate * n_occ);
            int nj = pois(rng);
            for (int q = 0; q < nj; ++q) {
              double x = unif(rng) * cum[ncell - 1];
              int j = static_cast<int>(std::upper_bound(cum.begin(), cum.end(), x) - cum.begin());
              if (j >= ncell) j = ncell - 1;
              double sj = st[j];
              if (sj > 0 && !next[j] && unif(rng) < sj) next[j] = 1;
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

static inline int rbinom_int(std::mt19937_64& rng, int n, double p) {
  if (n <= 0 || p <= 0) return 0;
  if (p >= 1) return n;
  std::binomial_distribution<int> b(n, p);
  return b(rng);
}

// [[Rcpp::export]]
List epidemic_simulate_cpp(IntegerVector hosts, IntegerVector init_inf,
                           int nrow, int ncol, NumericVector cell_w,
                           double cell_h, int ktype, double kmean, double kshape,
                           double kmax, double beta, double gamma, double omega,
                           double coupling, IntegerVector times, int nsim,
                           double seed, int threads, NumericVector resistance) {
  const int ncell = nrow * ncol;
  const int nt = times.size();
  const int tmax = nt ? times[nt - 1] : 0;
  if (hosts.size() != ncell || init_inf.size() != ncell || cell_w.size() != nrow) {
    stop("Dimension mismatch.");
  }
  const bool has_res = resistance.size() == ncell;
  Kernel K = build_kernel(nrow, cell_w, cell_h, ktype, kmean, kshape, kmax, has_res);
  std::vector<double> res;
  if (has_res) res.assign(resistance.begin(), resistance.end());
  const double* rp = has_res ? res.data() : nullptr;
  std::vector<int> N(hosts.begin(), hosts.end());
  const double p_rec = 1.0 - std::exp(-gamma);
  const double p_wane = 1.0 - std::exp(-omega);
  std::vector<double> prev_acc(static_cast<size_t>(ncell) * nt, 0.0);
  std::vector<double> reach_acc(static_cast<size_t>(ncell) * nt, 0.0);
  std::vector<double> curve_acc(static_cast<size_t>(tmax) + 1, 0.0);
  std::vector<double> final_acc(nsim, 0.0);
#ifdef _OPENMP
  if (threads > 0) omp_set_num_threads(threads);
#endif
#pragma omp parallel
  {
    std::vector<double> lprev(prev_acc.size(), 0.0), lreach(reach_acc.size(), 0.0);
    std::vector<double> lcurve(curve_acc.size(), 0.0);
    std::vector<int> S(ncell), I(ncell), R(ncell);
    std::vector<unsigned char> ever(ncell);
    std::vector<double> press(ncell);
#pragma omp for schedule(static)
    for (int k = 0; k < nsim; ++k) {
      std::mt19937_64 rng(static_cast<uint64_t>(seed) * 1000003ULL + k);
      long long total_n = 0, total_i = 0;
      for (int j = 0; j < ncell; ++j) {
        int n = std::max(N[j], 0);
        I[j] = std::min(std::max(init_inf[j], 0), n);
        S[j] = n - I[j];
        R[j] = 0;
        ever[j] = I[j] > 0;
        total_n += n;
        total_i += I[j];
      }
      long long cum_inf = total_i;
      lcurve[0] += static_cast<double>(total_i);
      int ti = 0;
      for (int step = 1; step <= tmax; ++step) {
        std::fill(press.begin(), press.end(), 0.0);
        if (coupling > 0) {
          for (int j = 0; j < ncell; ++j) {
            if (I[j] == 0) continue;
            double prev_j = static_cast<double>(I[j]) / N[j];
            int r = j / ncol, c = j % ncol;
            for (const Offset& o : K.off(r)) {
              int r2 = r + o.dr, c2 = c + o.dc;
              if (r2 < 0 || r2 >= nrow || c2 < 0 || c2 >= ncol) continue;
              press[r2 * ncol + c2] += prev_j * kernel_weight(K, o, r, c, ncol, rp);
            }
          }
        }
        total_i = 0;
        for (int j = 0; j < ncell; ++j) {
          if (N[j] <= 0) continue;
          double lam = beta * ((1.0 - coupling) * static_cast<double>(I[j]) / N[j] +
            coupling * press[j]);
          int new_i = rbinom_int(rng, S[j], 1.0 - std::exp(-lam));
          int new_r = rbinom_int(rng, I[j], p_rec);
          int new_s = rbinom_int(rng, R[j], p_wane);
          S[j] += new_s - new_i;
          I[j] += new_i - new_r;
          R[j] += new_r - new_s;
          if (new_i > 0) ever[j] = 1;
          cum_inf += new_i;
          total_i += I[j];
        }
        lcurve[step] += static_cast<double>(total_i);
        while (ti < nt && times[ti] == step) {
          for (int j = 0; j < ncell; ++j) {
            size_t q = static_cast<size_t>(ti) * ncell + j;
            if (N[j] > 0) lprev[q] += static_cast<double>(I[j]) / N[j];
            lreach[q] += ever[j];
          }
          ++ti;
        }
      }
      final_acc[k] = total_n > 0 ? static_cast<double>(cum_inf) / total_n : 0.0;
    }
#pragma omp critical
    {
      for (size_t i = 0; i < prev_acc.size(); ++i) prev_acc[i] += lprev[i];
      for (size_t i = 0; i < reach_acc.size(); ++i) reach_acc[i] += lreach[i];
      for (size_t i = 0; i < curve_acc.size(); ++i) curve_acc[i] += lcurve[i];
    }
  }
  NumericMatrix prev(ncell, nt), reach(ncell, nt);
  for (size_t i = 0; i < prev_acc.size(); ++i) {
    prev[i] = prev_acc[i] / nsim;
    reach[i] = reach_acc[i] / nsim;
  }
  NumericVector curve(curve_acc.size());
  for (size_t i = 0; i < curve_acc.size(); ++i) curve[i] = curve_acc[i] / nsim;
  return List::create(_["prevalence"] = prev, _["reached"] = reach,
                      _["infected"] = curve,
                      _["attack"] = NumericVector(final_acc.begin(), final_acc.end()));
}
