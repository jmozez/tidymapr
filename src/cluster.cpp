// DBSCAN (Ester et al. 1996) for planar points, with a uniform grid of cell
// size eps so that each neighbourhood query looks at 9 cells only.
// Labels: 0 = noise, 1..k = clusters. Border points join the first cluster
// that reaches them, as in the dbscan package (Hahsler et al. 2019).
#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <vector>
#include <cstdint>

using namespace Rcpp;

// [[Rcpp::export]]
List dbscan_cpp(NumericVector x, NumericVector y, double eps, int min_pts) {
  const int n = x.size();
  const double e2 = eps * eps;
  double xmin = *std::min_element(x.begin(), x.end());
  double ymin = *std::min_element(y.begin(), y.end());
  auto key = [&](int64_t gx, int64_t gy) {
    return (int64_t)(((uint64_t)gx << 32) ^ (uint64_t)(uint32_t)gy);
  };
  std::unordered_map<int64_t, std::vector<int>> grid;
  std::vector<int64_t> gx(n), gy(n);
  for (int i = 0; i < n; i++) {
    gx[i] = (int64_t)std::floor((x[i] - xmin) / eps);
    gy[i] = (int64_t)std::floor((y[i] - ymin) / eps);
    grid[key(gx[i], gy[i])].push_back(i);
  }
  auto neighbours = [&](int i, std::vector<int>& out) {
    out.clear();
    for (int64_t dx = -1; dx <= 1; dx++) {
      for (int64_t dy = -1; dy <= 1; dy++) {
        auto it = grid.find(key(gx[i] + dx, gy[i] + dy));
        if (it == grid.end()) continue;
        for (int j : it->second) {
          double ddx = x[j] - x[i], ddy = y[j] - y[i];
          if (ddx * ddx + ddy * ddy <= e2) out.push_back(j);
        }
      }
    }
  };
  IntegerVector cluster(n, 0);
  LogicalVector core(n, false);
  std::vector<char> visited(n, 0);
  std::vector<int> nb, nb2, queue;
  int c = 0;
  for (int i = 0; i < n; i++) {
    if (visited[i]) continue;
    visited[i] = 1;
    neighbours(i, nb);
    if ((int)nb.size() < min_pts) continue;  // noise for now
    core[i] = true;
    c++;
    cluster[i] = c;
    queue.assign(nb.begin(), nb.end());
    for (size_t q = 0; q < queue.size(); q++) {
      int j = queue[q];
      if (cluster[j] == 0) cluster[j] = c;  // border or core
      if (visited[j]) continue;
      visited[j] = 1;
      neighbours(j, nb2);
      if ((int)nb2.size() >= min_pts) {
        core[j] = true;
        for (int k : nb2) {
          if (!visited[k] || cluster[k] == 0) queue.push_back(k);
        }
      }
    }
  }
  return List::create(_["cluster"] = cluster, _["core"] = core);
}
