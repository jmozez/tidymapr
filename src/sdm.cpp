// Species distribution models in C++:
//  * sdm_lasso_logit_cpp(): weighted binomial lasso along a lambda path by
//    coordinate descent with active sets (the glmnet algorithm; Friedman,
//    Hastie and Tibshirani 2010), as used by Maxent's infinitely-weighted
//    logistic formulation (Fithian and Hastie 2013; Phillips et al. 2017).
//  * sdm_rf_fit_cpp() / sdm_rf_predict_cpp(): random forest of
//    classification trees grown on probability (Gini) splits (Breiman 2001).
#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <random>
#include <vector>
#ifdef _OPENMP
#include <omp.h>
#endif

using namespace Rcpp;

static inline double soft(double z, double g) {
  if (z > g) return z - g;
  if (z < -g) return z + g;
  return 0.0;
}

// [[Rcpp::export]]
List sdm_lasso_logit_cpp(NumericMatrix x0, NumericVector y, NumericVector w,
                         NumericVector penalty, NumericVector lambda,
                         int maxit = 100000, double thresh = 1e-7,
                         double pmin = 1e-8, int threads = 1) {
  const int n = x0.nrow(), p = x0.ncol(), nl = lambda.size();
  // glmnet: weights sum to one; penalty factors rescaled to sum to p
  double wsum = std::accumulate(w.begin(), w.end(), 0.0);
  std::vector<double> ww(n);
  for (int i = 0; i < n; i++) ww[i] = w[i] / wsum;
  double psum = std::accumulate(penalty.begin(), penalty.end(), 0.0);
  std::vector<double> pf(p);
  for (int j = 0; j < p; j++) pf[j] = penalty[j] * p / psum;

  // Centre every feature (weighted mean): the lasso solution is unchanged,
  // the intercept absorbs the shift, and coordinate descent converges far
  // faster because features no longer move with the intercept
  NumericMatrix x(n, p);
  std::vector<double> xm(p, 0.0);
  for (int j = 0; j < p; j++) {
    double m = 0.0;
    for (int i = 0; i < n; i++) m += ww[i] * x0(i, j);
    xm[j] = m;
    for (int i = 0; i < n; i++) x(i, j) = x0(i, j) - m;
  }
  // Start from the intercept-only fit
  double ybar = 0.0;
  for (int i = 0; i < n; i++) ybar += ww[i] * y[i];
  // Null deviance (weights summing to one) scales the convergence test, as
  // in glmnet
  double nulldev = -2.0 * (ybar * std::log(ybar) + (1.0 - ybar) * std::log(1.0 - ybar));
  const double tol = thresh * nulldev;
  double b0 = std::log(ybar / (1.0 - ybar));
  std::vector<double> beta(p, 0.0), eta(n, b0), prob(n), v(n), r(n);
  NumericMatrix path(p, nl);
  NumericVector a0(nl);
  IntegerVector npasses(nl);
  std::vector<char> active(p, 0);

  std::vector<char> strong(p, 1);
  for (int l = 0; l < nl; l++) {
    const double lam = lambda[l];
    const double lam_prev = l > 0 ? lambda[l - 1] : lam;
    int passes = 0;
    // Sequential strong rule (Tibshirani et al. 2012): a feature whose
    // gradient is small at the previous solution will stay at zero
    {
      std::vector<double> res(n);
      for (int i = 0; i < n; i++) {
        double pr = 1.0 / (1.0 + std::exp(-eta[i]));
        res[i] = ww[i] * (y[i] - pr);
      }
      const double* xp = &x[0];
#ifdef _OPENMP
#pragma omp parallel for num_threads(threads) schedule(static)
#endif
      for (int j = 0; j < p; j++) {
        double g = 0.0;
        const double* xj = xp + (size_t)j * n;
        for (int i = 0; i < n; i++) g += res[i] * xj[i];
        strong[j] = active[j] || std::fabs(g) >= pf[j] * (2.0 * lam - lam_prev);
      }
    }
    for (int kkt = 0; kkt < 50; kkt++) {
    for (int outer = 0; outer < 100; outer++) {
      // Quadratic approximation of the weighted log-likelihood
      for (int i = 0; i < n; i++) {
        double pr = 1.0 / (1.0 + std::exp(-eta[i]));
        pr = std::min(std::max(pr, pmin), 1.0 - pmin);
        prob[i] = pr;
        v[i] = ww[i] * pr * (1.0 - pr);
        r[i] = ww[i] * (y[i] - pr);  // v * working residual
      }
      std::vector<double> xv(p, 0.0);
      {
        const double* xp = &x[0];
#ifdef _OPENMP
#pragma omp parallel for num_threads(threads) schedule(static)
#endif
        for (int j = 0; j < p; j++) {
          if (!strong[j]) continue;
          double s = 0.0;
          const double* xj = xp + (size_t)j * n;
          for (int i = 0; i < n; i++) s += v[i] * xj[i] * xj[i];
          xv[j] = s;
        }
      }
      double vsum = std::accumulate(v.begin(), v.end(), 0.0);
      std::vector<double> beta_old = beta;
      double b0_old = b0;
      bool full = true;
      while (passes < maxit) {
        passes++;
        double dlx = 0.0;
        for (int j = 0; j < p; j++) {
          if (!strong[j]) continue;
          if (!full && !active[j]) continue;
          if (xv[j] <= 0) continue;
          double g = 0.0;
          for (int i = 0; i < n; i++) g += r[i] * x(i, j);
          double bj = beta[j];
          double nb = soft(g + xv[j] * bj, lam * pf[j]) / xv[j];
          if (nb != bj) {
            double d = nb - bj;
            beta[j] = nb;
            for (int i = 0; i < n; i++) r[i] -= d * v[i] * x(i, j);
            dlx = std::max(dlx, xv[j] * d * d);
            if (!active[j]) active[j] = 1;
          }
        }
        // Unpenalised intercept
        double g0 = std::accumulate(r.begin(), r.end(), 0.0);
        double d0 = g0 / vsum;
        b0 += d0;
        for (int i = 0; i < n; i++) r[i] -= d0 * v[i];
        dlx = std::max(dlx, vsum * d0 * d0);
        if (dlx < tol) {
          if (full) break;
          full = true;  // converged on the active set: check all features
        } else {
          full = false;
        }
      }
      std::vector<int> nz;
      for (int j = 0; j < p; j++) if (beta[j] != 0) nz.push_back(j);
      for (int i = 0; i < n; i++) eta[i] = b0;
      for (int j : nz) {
        const double bj = beta[j];
        for (int i = 0; i < n; i++) eta[i] += x(i, j) * bj;
      }
      double change = vsum * (b0 - b0_old) * (b0 - b0_old);
      for (int j = 0; j < p; j++) {
        double d = beta[j] - beta_old[j];
        change = std::max(change, xv[j] * d * d);
      }
      if (change < tol) break;
    }
    // KKT check on the features the strong rule left out
    bool violated = false;
    {
      std::vector<double> res(n);
      for (int i = 0; i < n; i++) {
        double pr = 1.0 / (1.0 + std::exp(-eta[i]));
        res[i] = ww[i] * (y[i] - pr);
      }
      const double* xp = &x[0];
      std::vector<char> add(p, 0);
#ifdef _OPENMP
#pragma omp parallel for num_threads(threads) schedule(static)
#endif
      for (int j = 0; j < p; j++) {
        if (strong[j]) continue;
        double g = 0.0;
        const double* xj = xp + (size_t)j * n;
        for (int i = 0; i < n; i++) g += res[i] * xj[i];
        if (std::fabs(g) > lam * pf[j]) add[j] = 1;
      }
      for (int j = 0; j < p; j++) {
        if (add[j]) {
          strong[j] = 1;
          violated = true;
        }
      }
    }
    if (!violated) break;
    }
    // Back to the uncentred features
    double b0u = b0;
    for (int j = 0; j < p; j++) {
      path(j, l) = beta[j];
      b0u -= beta[j] * xm[j];
    }
    a0[l] = b0u;
    npasses[l] = passes;
  }
  return List::create(_["beta"] = path, _["a0"] = a0, _["passes"] = npasses);
}

// ---- Random forest --------------------------------------------------------

struct Node {
  int var;        // -1 for a leaf
  double split;
  int left, right;
  double value;   // share of presences at a leaf
};

static int grow(std::vector<Node>& tree, const NumericMatrix& x,
                const NumericVector& y, std::vector<int>& idx, int lo, int hi,
                int mtry, int min_node, int depth, int max_depth,
                std::mt19937& rng) {
  int n = hi - lo;
  double s = 0.0;
  for (int k = lo; k < hi; k++) s += y[idx[k]];
  double mean = s / n;
  int id = tree.size();
  tree.push_back({-1, 0.0, -1, -1, mean});
  if (n < 2 * min_node || mean == 0.0 || mean == 1.0 || depth >= max_depth) return id;

  const int p = x.ncol();
  std::vector<int> vars(p);
  std::iota(vars.begin(), vars.end(), 0);
  std::shuffle(vars.begin(), vars.end(), rng);
  double best_gain = 1e-12, best_split = 0.0;
  int best_var = -1;
  std::vector<std::pair<double, double>> vals(n);
  double parent = s * (1.0 - mean);  // n * Gini / 2
  for (int m = 0; m < std::min(mtry, p); m++) {
    int j = vars[m];
    for (int k = 0; k < n; k++) vals[k] = {x(idx[lo + k], j), y[idx[lo + k]]};
    std::sort(vals.begin(), vals.end());
    double sl = 0.0;
    for (int k = 0; k < n - 1; k++) {
      sl += vals[k].second;
      int nl = k + 1, nr = n - nl;
      if (vals[k].first == vals[k + 1].first) continue;
      if (nl < min_node || nr < min_node) continue;
      double sr = s - sl;
      double imp = sl * (1.0 - sl / nl) + sr * (1.0 - sr / nr);
      double gain = parent - imp;
      if (gain > best_gain) {
        best_gain = gain;
        best_var = j;
        best_split = 0.5 * (vals[k].first + vals[k + 1].first);
      }
    }
  }
  if (best_var < 0) return id;
  int mid = std::partition(idx.begin() + lo, idx.begin() + hi, [&](int i) {
    return x(i, best_var) <= best_split;
  }) - idx.begin();
  if (mid == lo || mid == hi) return id;
  tree[id].var = best_var;
  tree[id].split = best_split;
  int l = grow(tree, x, y, idx, lo, mid, mtry, min_node, depth + 1, max_depth, rng);
  int r = grow(tree, x, y, idx, mid, hi, mtry, min_node, depth + 1, max_depth, rng);
  tree[id].left = l;
  tree[id].right = r;
  return id;
}

// Each tree is grown on a balanced bootstrap (as many background rows as
// presences, the down-sampling of Valavi et al. 2021) when `balanced`.
// [[Rcpp::export]]
List sdm_rf_fit_cpp(NumericMatrix x, NumericVector y, int ntree = 500,
                    int mtry = 2, int min_node = 1, int max_depth = 1000,
                    bool balanced = true, int seed = 1, int threads = 1) {
  const int n = x.nrow();
  std::vector<int> pres, back;
  for (int i = 0; i < n; i++) (y[i] > 0.5 ? pres : back).push_back(i);
  std::vector<std::vector<Node>> forest(ntree);
#ifdef _OPENMP
#pragma omp parallel for num_threads(threads) schedule(dynamic)
#endif
  for (int t = 0; t < ntree; t++) {
    std::mt19937 rng(seed * 100003 + t);
    std::vector<int> idx;
    if (balanced && !pres.empty() && !back.empty()) {
      int m = pres.size();
      std::uniform_int_distribution<int> up(0, pres.size() - 1), ub(0, back.size() - 1);
      for (int k = 0; k < m; k++) idx.push_back(pres[up(rng)]);
      for (int k = 0; k < m; k++) idx.push_back(back[ub(rng)]);
    } else {
      std::uniform_int_distribution<int> u(0, n - 1);
      for (int k = 0; k < n; k++) idx.push_back(u(rng));
    }
    std::vector<Node> tree;
    grow(tree, x, y, idx, 0, idx.size(), mtry, min_node, 0, max_depth, rng);
    forest[t] = tree;
  }
  // Flatten: one row per node with its tree number
  int total = 0;
  for (auto& tr : forest) total += tr.size();
  IntegerVector tree_id(total), var(total), left(total), right(total);
  NumericVector split(total), value(total);
  int k = 0;
  for (int t = 0; t < ntree; t++) {
    for (auto& nd : forest[t]) {
      tree_id[k] = t;
      var[k] = nd.var;
      split[k] = nd.split;
      left[k] = nd.left;
      right[k] = nd.right;
      value[k] = nd.value;
      k++;
    }
  }
  return List::create(_["tree"] = tree_id, _["var"] = var, _["split"] = split,
                      _["left"] = left, _["right"] = right, _["value"] = value,
                      _["ntree"] = ntree);
}

// [[Rcpp::export]]
NumericVector sdm_rf_predict_cpp(List forest, NumericMatrix x, int threads = 1) {
  IntegerVector tree_id = forest["tree"], var = forest["var"];
  IntegerVector left = forest["left"], right = forest["right"];
  NumericVector split = forest["split"], value = forest["value"];
  int ntree = forest["ntree"];
  std::vector<int> start(ntree, -1);
  for (int k = tree_id.size() - 1; k >= 0; k--) start[tree_id[k]] = k;
  const int n = x.nrow();
  NumericVector out(n);
  std::vector<int> vv(var.begin(), var.end()), ll(left.begin(), left.end()),
      rr(right.begin(), right.end());
  std::vector<double> ss(split.begin(), split.end()), va(value.begin(), value.end());
  std::vector<double> xx(x.begin(), x.end());
  std::vector<double> res(n);
#ifdef _OPENMP
#pragma omp parallel for num_threads(threads)
#endif
  for (int i = 0; i < n; i++) {
    double s = 0.0;
    for (int t = 0; t < ntree; t++) {
      int b = start[t], node = 0;
      while (vv[b + node] >= 0) {
        double xi = xx[i + (size_t)n * vv[b + node]];
        node = (xi <= ss[b + node]) ? ll[b + node] : rr[b + node];
      }
      s += va[b + node];
    }
    res[i] = s / ntree;
  }
  std::copy(res.begin(), res.end(), out.begin());
  return out;
}
