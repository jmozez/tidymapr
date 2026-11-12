// Two- and three-dimensional mid-domain null model (spreading dye; Jetz and Rahbek
// 2001). The domain is a raster mask; each range of L cells starts at a
// random domain cell and grows by adding a randomly chosen cell from its
// rook-neighbour frontier, as the one-dimensional model of rangemodelR.
// Random numbers come from R, so results follow set.seed().
#include <Rcpp.h>
#include <vector>

using namespace Rcpp;

// Cells are numbered layer by layer (row-major within a layer), so a 2D
// domain is the special case nlay = 1. Neighbours share a face: up to four
// within a layer and one above and one below.
// [[Rcpp::export]]
List geo_mde_cpp(IntegerVector domain, int nrow, int ncol, IntegerVector size,
                 int nsim, int nlay = 1) {
  const int nlayer = nrow * ncol;
  const int n = nlayer * nlay;
  std::vector<int> cells;
  for (int i = 0; i < n; i++) if (domain[i]) cells.push_back(i);
  const int nd = cells.size();
  // Richness per domain cell and simulation (domain cells in rows).
  IntegerMatrix rich(nd, nsim);
  std::vector<int> pos(n, -1);
  for (int k = 0; k < nd; k++) pos[cells[k]] = k;
  std::vector<int> mark(n, 0);  // 1 selected, 2 in frontier; reset per range
  std::vector<int> sel, front;
  int truncated = 0;
  RNGScope scope;
  for (int b = 0; b < nsim; b++) {
    for (int s = 0; s < size.size(); s++) {
      const int L = size[s];
      sel.clear();
      front.clear();
      int seed = cells[(int)(unif_rand() * nd) % nd];
      sel.push_back(seed);
      mark[seed] = 1;
      int cur = seed;
      while ((int)sel.size() < L) {
        int z = cur / nlayer, w = cur % nlayer;
        int r = w / ncol, c = w % ncol;
        int nb[6] = {r > 0 ? cur - ncol : -1, r < nrow - 1 ? cur + ncol : -1,
                     c > 0 ? cur - 1 : -1, c < ncol - 1 ? cur + 1 : -1,
                     z > 0 ? cur - nlayer : -1, z < nlay - 1 ? cur + nlayer : -1};
        for (int j = 0; j < 6; j++) {
          int v = nb[j];
          if (v >= 0 && domain[v] && mark[v] == 0) {
            mark[v] = 2;
            front.push_back(v);
          }
        }
        if (front.empty()) {
          truncated++;
          break;
        }
        int pick = (int)(unif_rand() * front.size()) % front.size();
        cur = front[pick];
        front[pick] = front.back();
        front.pop_back();
        mark[cur] = 1;
        sel.push_back(cur);
      }
      for (int v : sel) {
        rich(pos[v], b) += 1;
        mark[v] = 0;
      }
      for (int v : front) mark[v] = 0;
    }
  }
  return List::create(_["richness"] = rich, _["cells"] = IntegerVector(cells.begin(), cells.end()),
                      _["truncated"] = truncated);
}
