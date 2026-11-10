// A small software renderer for 3D terrain maps: the DEM becomes two
// triangles per cell, lit by the sun (Lambert shading with cast shadows found
// by marching towards the sun over the grid), seen from any azimuth and
// angle in orthographic projection, and rasterised with a depth buffer.
// Block-diagram sides are drawn down to a base level.
#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <vector>
#ifdef _OPENMP
#include <omp.h>
#endif

using namespace Rcpp;

struct View {
  double ct, st, cp, sp;  // cos/sin of azimuth (theta) and tilt (phi)
  double scale, ox, oy;
};

// World (x east, y north, z up) to screen (sx right, sy up) and depth
// (larger = nearer the viewer)
static inline void project(const View& v, double x, double y, double z,
                           double& sx, double& sy, double& depth) {
  // Rotate so that the viewer looks from azimuth theta (0 = from the south)
  double x1 = x * v.ct - y * v.st;
  double y1 = x * v.st + y * v.ct;  // positive: away from the viewer
  sx = x1;
  sy = y1 * v.sp + z * v.cp;
  depth = -y1 * v.cp + z * v.sp;
}

struct Img {
  int w, h;
  std::vector<double> r, g, b, a, zb;
  Img(int w_, int h_) : w(w_), h(h_), r(w_ * h_, 1), g(w_ * h_, 1), b(w_ * h_, 1),
                        a(w_ * h_, 0), zb(w_ * h_, -1e300) {}
};

static void tri(Img& im, const double* X, const double* Y, const double* D,
                const double* R, const double* G, const double* B) {
  double minx = std::floor(std::min({X[0], X[1], X[2]}));
  double maxx = std::ceil(std::max({X[0], X[1], X[2]}));
  double miny = std::floor(std::min({Y[0], Y[1], Y[2]}));
  double maxy = std::ceil(std::max({Y[0], Y[1], Y[2]}));
  int x0 = std::max(0, (int)minx), x1 = std::min(im.w - 1, (int)maxx);
  int y0 = std::max(0, (int)miny), y1 = std::min(im.h - 1, (int)maxy);
  double den = (Y[1] - Y[2]) * (X[0] - X[2]) + (X[2] - X[1]) * (Y[0] - Y[2]);
  if (std::fabs(den) < 1e-12) return;
  for (int py = y0; py <= y1; py++) {
    double cy = py + 0.5;
    for (int px = x0; px <= x1; px++) {
      double cx = px + 0.5;
      double l0 = ((Y[1] - Y[2]) * (cx - X[2]) + (X[2] - X[1]) * (cy - Y[2])) / den;
      double l1 = ((Y[2] - Y[0]) * (cx - X[2]) + (X[0] - X[2]) * (cy - Y[2])) / den;
      double l2 = 1.0 - l0 - l1;
      const double e = -1e-9;
      if (l0 < e || l1 < e || l2 < e) continue;
      double d = l0 * D[0] + l1 * D[1] + l2 * D[2];
      int k = py * im.w + px;
      if (d <= im.zb[k]) continue;
      im.zb[k] = d;
      im.r[k] = l0 * R[0] + l1 * R[1] + l2 * R[2];
      im.g[k] = l0 * G[0] + l1 * G[1] + l2 * G[2];
      im.b[k] = l0 * B[0] + l1 * B[1] + l2 * B[2];
      im.a[k] = 1.0;
    }
  }
}

// z: elevation matrix (row 0 = north), NA allowed; cr/cg/cb: drape colours
// 0-1 per cell. Returns the image (row 0 = top) and the view for overlays.
// [[Rcpp::export]]
List render_dem_cpp(NumericMatrix z, double dx, double dy,
                    NumericMatrix cr, NumericMatrix cg, NumericMatrix cb,
                    double theta, double phi, double zscale,
                    int width, int height,
                    double sun_azimuth, double sun_elevation,
                    bool shadow, double ambient, double base_frac,
                    int threads = 1) {
  const int nr = z.nrow(), nc = z.ncol();
  const double pi = 3.14159265358979323846;
  // World coordinates of the vertices (centred)
  auto wx = [&](int c) { return (c - (nc - 1) / 2.0) * dx; };
  auto wy = [&](int r) { return ((nr - 1) / 2.0 - r) * dy; };
  double zmin = 1e300, zmax = -1e300;
  for (int i = 0; i < nr * nc; i++) {
    if (!NumericVector::is_na(z[i])) {
      zmin = std::min(zmin, z[i]);
      zmax = std::max(zmax, z[i]);
    }
  }
  const double base = (zmin - base_frac * (zmax - zmin)) * zscale;

  // Lighting: sun direction, normals by central differences, cast shadows
  double saz = sun_azimuth * pi / 180.0, sel = sun_elevation * pi / 180.0;
  double sx = std::sin(saz) * std::cos(sel), sy = std::cos(saz) * std::cos(sel),
         sz = std::sin(sel);
  NumericMatrix light(nr, nc);
  auto Z = [&](int r, int c) {
    r = std::min(std::max(r, 0), nr - 1);
    c = std::min(std::max(c, 0), nc - 1);
    double v = z(r, c);
    return NumericVector::is_na(v) ? zmin : v;
  };
#ifdef _OPENMP
#pragma omp parallel for num_threads(threads) schedule(dynamic)
#endif
  for (int r = 0; r < nr; r++) {
    for (int c = 0; c < nc; c++) {
      double dzdx = (Z(r, c + 1) - Z(r, c - 1)) * zscale / (2 * dx);
      double dzdy = (Z(r - 1, c) - Z(r + 1, c)) * zscale / (2 * dy);
      double nx = -dzdx, ny = -dzdy, nz = 1.0;
      double nl = std::sqrt(nx * nx + ny * ny + nz * nz);
      double lam = std::max(0.0, (nx * sx + ny * sy + nz * sz) / nl);
      double shade = 1.0;
      if (shadow && lam > 0) {
        // March towards the sun one cell at a time
        double step = std::min(dx, dy);
        double h = Z(r, c) * zscale;
        double px = wx(c), py = wy(r);
        double tz = std::tan(sel);
        for (int k = 1; k < 4 * std::max(nr, nc); k++) {
          double qx = px + sx / std::cos(sel) * step * k;
          double qy = py + sy / std::cos(sel) * step * k;
          double fc = qx / dx + (nc - 1) / 2.0;
          double fr = (nr - 1) / 2.0 - qy / dy;
          if (fc < 0 || fr < 0 || fc > nc - 1 || fr > nr - 1) break;
          double ray = h + tz * step * k;
          if (ray > zmax * zscale) break;
          if (Z((int)std::round(fr), (int)std::round(fc)) * zscale > ray + 1e-9) {
            shade = 0.0;
            break;
          }
        }
      }
      light(r, c) = ambient + (1.0 - ambient) * lam * shade;
    }
  }

  // Fit the projected block (top and base corners) into the image
  View v;
  double th = theta * pi / 180.0, ph = phi * pi / 180.0;
  v.ct = std::cos(th);
  v.st = std::sin(th);
  v.cp = std::cos(ph);
  v.sp = std::sin(ph);
  double mnx = 1e300, mxx = -1e300, mny = 1e300, mxy = -1e300;
  for (int r = 0; r < nr; r++) {
    for (int c = 0; c < nc; c++) {
      double zz[2] = {Z(r, c) * zscale, base};
      for (double zv : zz) {
        double a, b, d;
        project(v, wx(c), wy(r), zv, a, b, d);
        mnx = std::min(mnx, a);
        mxx = std::max(mxx, a);
        mny = std::min(mny, b);
        mxy = std::max(mxy, b);
      }
    }
  }
  double margin = 0.03;
  v.scale = std::min(width * (1 - 2 * margin) / (mxx - mnx), height * (1 - 2 * margin) / (mxy - mny));
  v.ox = (width - (mxx - mnx) * v.scale) / 2 - mnx * v.scale;
  v.oy = (height - (mxy - mny) * v.scale) / 2 - mny * v.scale;
  auto toimg = [&](double a, double b, double& X, double& Y) {
    X = a * v.scale + v.ox;
    Y = height - (b * v.scale + v.oy);  // image row 0 at the top
  };

  Img im(width, height);
  // Terrain: two triangles per cell
  for (int r = 0; r < nr - 1; r++) {
    for (int c = 0; c < nc - 1; c++) {
      int rr[4] = {r, r, r + 1, r + 1}, cc[4] = {c, c + 1, c + 1, c};
      bool skip = false;
      double X[4], Y[4], D[4], R[4], G[4], B[4];
      for (int k = 0; k < 4; k++) {
        double zv = z(rr[k], cc[k]);
        if (NumericVector::is_na(zv) || NumericVector::is_na(cr(rr[k], cc[k]))) {
          skip = true;
          break;
        }
        double a, b;
        project(v, wx(cc[k]), wy(rr[k]), zv * zscale, a, b, D[k]);
        toimg(a, b, X[k], Y[k]);
        double l = light(rr[k], cc[k]);
        R[k] = cr(rr[k], cc[k]) * l;
        G[k] = cg(rr[k], cc[k]) * l;
        B[k] = cb(rr[k], cc[k]) * l;
      }
      if (skip) continue;
      int t1[3] = {0, 1, 2}, t2[3] = {0, 2, 3};
      for (int* t : {t1, t2}) {
        double tx[3] = {X[t[0]], X[t[1]], X[t[2]]}, ty[3] = {Y[t[0]], Y[t[1]], Y[t[2]]};
        double td[3] = {D[t[0]], D[t[1]], D[t[2]]};
        double tr[3] = {R[t[0]], R[t[1]], R[t[2]]}, tg[3] = {G[t[0]], G[t[1]], G[t[2]]};
        double tb[3] = {B[t[0]], B[t[1]], B[t[2]]};
        tri(im, tx, ty, td, tr, tg, tb);
      }
    }
  }
  // Block sides: quads from the edge of the terrain down to the base
  if (base_frac > 0) {
    auto side = [&](int r0, int c0, int r1, int c1, double tone) {
      // No wall where the terrain itself is missing (irregular outlines)
      if (NumericVector::is_na(z(r0, c0)) || NumericVector::is_na(z(r1, c1))) return;
      double z0 = Z(r0, c0) * zscale, z1 = Z(r1, c1) * zscale;
      double P[4][3] = {{wx(c0), wy(r0), z0}, {wx(c1), wy(r1), z1},
                        {wx(c1), wy(r1), base}, {wx(c0), wy(r0), base}};
      double X[4], Y[4], D[4];
      for (int k = 0; k < 4; k++) {
        double a, b;
        project(v, P[k][0], P[k][1], P[k][2], a, b, D[k]);
        toimg(a, b, X[k], Y[k]);
      }
      double R[3] = {tone, tone, tone};
      int t1[3] = {0, 1, 2}, t2[3] = {0, 2, 3};
      for (int* t : {t1, t2}) {
        double tx[3] = {X[t[0]], X[t[1]], X[t[2]]}, ty[3] = {Y[t[0]], Y[t[1]], Y[t[2]]};
        double td[3] = {D[t[0]], D[t[1]], D[t[2]]};
        tri(im, tx, ty, td, R, R, R);
      }
    };
    for (int c = 0; c < nc - 1; c++) {
      side(0, c, 0, c + 1, 0.62);           // north
      side(nr - 1, c, nr - 1, c + 1, 0.55);  // south
    }
    for (int r = 0; r < nr - 1; r++) {
      side(r, 0, r + 1, 0, 0.68);            // west
      side(r, nc - 1, r + 1, nc - 1, 0.5);   // east
    }
  }
  NumericVector out_r(width * height), out_g(width * height), out_b(width * height),
      out_a(width * height), out_z(width * height);
  for (int i = 0; i < width * height; i++) {
    out_r[i] = std::min(1.0, std::max(0.0, im.r[i]));
    out_g[i] = std::min(1.0, std::max(0.0, im.g[i]));
    out_b[i] = std::min(1.0, std::max(0.0, im.b[i]));
    out_a[i] = im.a[i];
    out_z[i] = im.zb[i];
  }
  return List::create(_["r"] = out_r, _["g"] = out_g, _["b"] = out_b, _["a"] = out_a,
                      _["depth"] = out_z, _["width"] = width, _["height"] = height,
                      _["view"] = NumericVector::create(v.ct, v.st, v.cp, v.sp, v.scale,
                                                         v.ox, v.oy),
                      _["zmin"] = zmin, _["zmax"] = zmax);
}

// Project points (world coordinates relative to the DEM centre) into the image
// [[Rcpp::export]]
NumericMatrix project_points_cpp(NumericVector x, NumericVector y, NumericVector z,
                                 NumericVector view, int height) {
  View v;
  v.ct = view[0];
  v.st = view[1];
  v.cp = view[2];
  v.sp = view[3];
  v.scale = view[4];
  v.ox = view[5];
  v.oy = view[6];
  int n = x.size();
  NumericMatrix out(n, 3);
  for (int i = 0; i < n; i++) {
    double a, b, d;
    project(v, x[i], y[i], z[i], a, b, d);
    out(i, 0) = a * v.scale + v.ox;
    out(i, 1) = height - (b * v.scale + v.oy);
    out(i, 2) = d;
  }
  return out;
}
