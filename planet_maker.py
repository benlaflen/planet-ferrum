import numpy as np
import tkinter as tk
from tkinter import filedialog, colorchooser
from PIL import Image, ImageTk

SIZE = 512

PARAMS = [
    ('seed', 0, 9999, 1, 42),
    ('phase', 0, 150, 1, 50),
    ('light_elev', -45, 45, 1, 0),
    ('rotation', 0, 360, 1, 0),
    ('tilt', -90, 90, 1, 20),
    ('radius', 0.5, 0.98, 0.01, 0.88),
    ('scale', 0.5, 8, 0.1, 2.5),
    ('octaves', 1, 10, 1, 7),
    ('lacunarity', 1.5, 3, 0.05, 2.0),
    ('gain', 0.3, 0.7, 0.01, 0.5),
    ('warp', 0, 2, 0.05, 0.4),
    ('bump', 0, 3, 0.05, 1.0),
    ('rust', 0, 1, 0.01, 0.45),
    ('rust_scale', 0.5, 8, 0.1, 3.0),
    ('panels', 0, 40, 1, 12),
    ('seam', 0, 1, 0.01, 0.3),
    ('panel_var', 0, 0.3, 0.01, 0.08),
    ('vein_scale', 0.5, 8, 0.1, 1.5),
    ('vein_width', 0.002, 0.05, 0.001, 0.01),
    ('vein_glow', 0, 3, 0.05, 0.9),
    ('vein_halo', 0, 1, 0.01, 0.25),
    ('ice_lat', 0, 1.1, 0.01, 0.75),
    ('fog_density', 0, 3, 0.01, 0.6),
    ('atmo_strength', 0, 2, 0.01, 0.7),
    ('atmo_thickness', 0, 0.2, 0.005, 0.08),
    ('cloud_cover', 0, 1, 0.01, 0.4),
    ('cloud_scale', 0.5, 8, 0.1, 2.5),
    ('cloud_opacity', 0, 1, 0.01, 0.12),
    ('cloud_height', 0, 0.15, 0.005, 0.04),
    ('cloud_edge', 0, 2, 0.01, 1.5),
    ('terminator', 0, 0.5, 0.01, 0.15),
    ('ambient', 0, 0.3, 0.01, 0.02),
    ('specular', 0, 1, 0.01, 0.25),
    ('stars', 0, 0.01, 0.0005, 0.002),
]

# anything that changes the noise fields; everything else re-renders from cache
NOISE_KEYS = ('seed', 'radius', 'rotation', 'tilt', 'scale', 'octaves', 'lacunarity', 'gain', 'warp', 'rust_scale', 'vein_scale', 'cloud_scale', 'cloud_height')

COLORS = {
    'dark': '#2e2b29', 'mid': '#5f5a55', 'light': '#948d84', 'rust': '#6e4128', 'vein': '#5ee04a', 'ice': '#dfe6ee',
    'fog': '#24122e', 'cloud': '#b9a8c8', 'atmo': '#7a55a8',
}


def perlin3(p, perm, grads):
    i = np.floor(p).astype(np.int64)
    f = p - i
    u = f * f * f * (f * (f * 6 - 15) + 10)
    c = {}
    for dx in (0, 1):
        hx = perm[(i[:, 0] + dx) & 255]
        for dy in (0, 1):
            hy = perm[hx + ((i[:, 1] + dy) & 255)]
            for dz in (0, 1):
                g = grads[perm[hy + ((i[:, 2] + dz) & 255)]]
                c[dx, dy, dz] = g[:, 0] * (f[:, 0] - dx) + g[:, 1] * (f[:, 1] - dy) + g[:, 2] * (f[:, 2] - dz)
    ux, uy, uz = u[:, 0], u[:, 1], u[:, 2]
    x00 = c[0, 0, 0] + ux * (c[1, 0, 0] - c[0, 0, 0])
    x10 = c[0, 1, 0] + ux * (c[1, 1, 0] - c[0, 1, 0])
    x01 = c[0, 0, 1] + ux * (c[1, 0, 1] - c[0, 0, 1])
    x11 = c[0, 1, 1] + ux * (c[1, 1, 1] - c[0, 1, 1])
    y0 = x00 + uy * (x10 - x00)
    y1 = x01 + uy * (x11 - x01)
    return y0 + uz * (y1 - y0)


def fbm(p, octaves, lacunarity, gain, perm, grads):
    total = np.zeros(len(p))
    amp, freq, norm = 1.0, 1.0, 0.0
    for o in range(octaves):
        total += amp * perlin3(p * freq + o * 17.31, perm, grads)
        norm += amp
        amp *= gain
        freq *= lacunarity
    return total / norm


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def ramp(t, stops, colors):
    return np.stack([np.interp(t, stops, [c[k] for c in colors]) for k in range(3)], -1)


def render(P, C, cache, transparent):
    r = P['radius']
    ax = (np.arange(SIZE) + 0.5) / SIZE * 2 - 1
    x, y = np.meshgrid(ax / r, -ax / r)
    d2 = x * x + y * y
    rr = np.sqrt(d2)
    pw = 2 / (SIZE * r)
    inside = rr < 1 + pw
    n = np.stack([x[inside], y[inside], np.sqrt(np.clip(1 - d2[inside], 0, 1))], -1)
    n /= np.linalg.norm(n, axis=1, keepdims=True)

    a, t = np.radians(P['rotation']), np.radians(P['tilt'])
    ry = np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])
    rx = np.array([[1, 0, 0], [0, np.cos(t), -np.sin(t)], [0, np.sin(t), np.cos(t)]])
    q = n @ (rx @ ry)
    rc = 1 + P['cloud_height']
    shell = rr < rc + pw
    nc = np.stack([x[shell], y[shell], np.sqrt(np.clip(rc * rc - d2[shell], 0, None))], -1)
    nc /= np.linalg.norm(nc, axis=1, keepdims=True)
    qc = nc @ (rx @ ry)

    key = tuple(P[k] for k in NOISE_KEYS)
    if cache.get('key') != key:
        rng = np.random.default_rng(int(P['seed']))
        perm = np.tile(rng.permutation(256), 2)
        g = rng.normal(size=(256, 3))
        grads = g / np.linalg.norm(g, axis=1, keepdims=True)
        p = q * P['scale']
        if P['warp'] > 0:
            w = np.stack([fbm(p + off, 2, 2.0, 0.5, perm, grads) for off in (31.7, 57.3, 91.1)], -1)
            p = p + P['warp'] * w
        h = fbm(p, int(P['octaves']), P['lacunarity'], P['gain'], perm, grads) * 3
        rust = fbm(q * P['rust_scale'] + 200.0, 5, 2.0, 0.5, perm, grads) * 3
        vp = q * P['vein_scale'] + 400.0
        vp = vp + 0.3 * np.stack([fbm(vp * 2 + off, 2, 2.0, 0.5, perm, grads) for off in (11.1, 22.2, 33.3)], -1)
        vein = np.abs(fbm(vp, 2, 2.0, 0.4, perm, grads))
        cl = fbm(qc * P['cloud_scale'] * np.array([1, 2, 1]) + 600.0, 5, 2.0, 0.5, perm, grads) * 3
        cache.update(key=key, h=h, rust=rust, vein=vein, cl=cl)
    h, rust, vein, cl = cache['h'], cache['rust'], cache['vein'], cache['cl']

    col = ramp(np.clip((h + 1) / 2, 0, 1), [0, 0.5, 1], [C['dark'], C['mid'], C['light']])
    th = (0.5 - P['rust']) * 3
    rf = smoothstep(th, th + 0.6, rust) * (1 - 0.5 * np.clip((h + 1) / 2, 0, 1))
    col = col * (1 - rf[:, None]) + np.array(C['rust']) * rf[:, None]

    ice = smoothstep(P['ice_lat'] - 0.03, P['ice_lat'] + 0.03, np.abs(q[:, 1]) + 0.08 * h)
    col = col * (1 - ice[:, None]) + np.array(C['ice']) * ice[:, None]

    height = h * 0.3
    if P['panels'] > 0:
        lon = np.arctan2(q[:, 0], q[:, 2])
        lat = np.arcsin(np.clip(q[:, 1], -1, 1))
        u = lon / (2 * np.pi) * P['panels'] * 2
        v = lat / np.pi * P['panels']
        du = np.abs(u - np.round(u)) * np.cos(lat)
        dv = np.abs(v - np.round(v))
        s = smoothstep(0.05, 0.0, np.minimum(du, dv)) * P['seam']
        pid = np.floor(u) * 12.9898 + np.floor(v) * 78.233
        shade = (np.sin(pid) * 43758.5453) % 1 * 2 - 1
        col = col * (1 + shade * P['panel_var'])[:, None] * (1 - 0.6 * s)[:, None]
        height = height + shade * P['panel_var'] - 0.4 * s

    w = P['vein_width']
    core = smoothstep(w, w * 0.4, vein)
    halo = smoothstep(w * 4, 0, vein) ** 2 * P['vein_halo']
    col = col * (1 - core[:, None]) + np.array(C['vein']) * 0.4 * core[:, None]
    height = height - 0.3 * core

    H = np.zeros((SIZE, SIZE))
    H[inside] = height
    gy, gx = np.gradient(H)
    k = P['bump'] * SIZE * r / 2 * 0.05 * smoothstep(0, 0.15, n[:, 2])
    nb = n - np.stack([gx[inside] * k, -gy[inside] * k, np.zeros(len(n))], -1)
    nb /= np.linalg.norm(nb, axis=1, keepdims=True)

    ph, el = np.radians(P['phase']), np.radians(P['light_elev'])
    L = np.array([-np.sin(ph) * np.cos(el), np.sin(el), np.cos(ph) * np.cos(el)])
    ndl = n @ L
    soft = P['terminator']
    diffuse = np.clip((nb @ L + soft) / (1 + soft), 0, 1) * smoothstep(-soft - 1e-4, soft, ndl)
    hv = L + np.array([0, 0, 1.0])
    hv /= np.linalg.norm(hv) + 1e-9
    spec = np.clip(nb @ hv, 0, 1) ** 20 * P['specular'] * (1 - rf) * (1 - core) * (diffuse > 0)
    disk = col * (diffuse[:, None] + P['ambient']) + spec[:, None] * (0.5 + col)
    # veins are emissive, so they stay visible on the night side
    disk += np.array(C['vein']) * ((core + halo * 0.5) * P['vein_glow'])[:, None]
    T = max(P['atmo_thickness'], 1e-3)
    chord = np.sqrt((1 + T) ** 2 - np.minimum(d2[inside], 1)) - np.sqrt(np.clip(1 - d2[inside], 0, 1))
    fog = 1 - np.exp(-P['fog_density'] * chord / T)
    fog_lit = np.clip((ndl + 0.3) / 1.3, 0, 1) + P['ambient']
    disk = disk * (1 - fog[:, None]) + np.array(C['fog']) * (fog * fog_lit)[:, None]
    rim = (1 - n[:, 2]) ** 3 * P['atmo_strength'] * smoothstep(-0.3, 0.4, ndl)
    disk += np.array(C['atmo']) * rim[:, None]

    prem = np.zeros((SIZE, SIZE, 3))
    alpha = np.zeros((SIZE, SIZE))
    thick = P['atmo_thickness']
    if thick > 0:
        ring = (rr > 1 - pw) & (rr < 1 + thick)
        fall = (1 - np.maximum(rr[ring] - 1, 0) / thick) ** 2
        lx, ly = x[ring] / rr[ring], y[ring] / rr[ring]
        ah = np.clip(fall * P['atmo_strength'] * smoothstep(-0.4, 0.4, lx * L[0] + ly * L[1] + 0.3 * L[2]), 0, 1)
        prem[ring] = np.array(C['atmo']) * ah[:, None]
        alpha[ring] = ah

    cov = np.clip((1 - rr[inside]) / pw + 0.5, 0, 1)
    prem[inside] = disk * cov[:, None] + prem[inside] * (1 - cov[:, None])
    alpha[inside] = cov + alpha[inside] * (1 - cov)

    if P['cloud_opacity'] > 0:
        th = (0.5 - P['cloud_cover']) * 3
        base = smoothstep(th, th + 0.5, cl)
        # thin shell seen edge-on at the limb has a longer path through it
        path = 1 + P['cloud_edge'] * (1 / np.maximum(nc[:, 2], 0.05) - 1)
        ca = (1 - np.exp(-3 * P['cloud_opacity'] * base * path)) * np.clip((rc - rr[shell]) / pw + 0.5, 0, 1)
        clit = np.clip((nc @ L + soft) / (1 + soft), 0, 1) + P['ambient']
        prem[shell] = np.array(C['cloud']) * (clit * ca)[:, None] + prem[shell] * (1 - ca[:, None])
        alpha[shell] = ca + alpha[shell] * (1 - ca)

    if transparent:
        rgb = prem / np.maximum(alpha, 1e-6)[..., None]
        out = np.dstack([np.clip(rgb, 0, 1), alpha])
        return Image.fromarray((out * 255).astype(np.uint8), 'RGBA')
    if P['stars'] > 0:
        srng = np.random.default_rng(int(P['seed']) + 1)
        stars = (srng.random((SIZE, SIZE)) < P['stars']) * srng.random((SIZE, SIZE)) ** 2
        prem += stars[..., None] * (1 - alpha[..., None])
    return Image.fromarray((np.clip(prem, 0, 1) * 255).astype(np.uint8), 'RGB')


class App:
    def __init__(self, root):
        self.root = root
        self.vars = {}
        self.colors = dict(COLORS)
        self.cache = {}
        self.pending = None
        self.image = None

        panel = tk.Frame(root)
        panel.pack(side='left', fill='y', padx=4, pady=4)
        sliders = tk.Frame(panel)
        sliders.pack()
        for i, (name, lo, hi, res, default) in enumerate(PARAMS):
            v = tk.DoubleVar(value=default)
            tk.Scale(sliders, label=name, variable=v, from_=lo, to=hi, resolution=res, orient='horizontal',
                     length=170, command=lambda _: self.schedule()).grid(row=i // 3, column=i % 3, padx=2)
            self.vars[name] = v

        cols = tk.Frame(panel)
        cols.pack(pady=6)
        for i, name in enumerate(self.colors):
            lbl = tk.Label(cols, text=name, width=9, relief='raised', bg=self.colors[name])
            lbl.bind('<Button-1>', lambda e, n=name, w=lbl: self.pick(n, w))
            lbl.grid(row=i // 3, column=i % 3, padx=2, pady=2)
            self.set_fg(lbl, self.colors[name])

        btns = tk.Frame(panel)
        btns.pack(pady=6)
        self.transparent = tk.BooleanVar(value=False)
        tk.Button(btns, text='Random seed', command=self.random_seed).pack(side='left', padx=3)
        tk.Checkbutton(btns, text='Transparent BG', variable=self.transparent, command=self.schedule).pack(side='left', padx=3)
        tk.Button(btns, text='Save PNG', command=self.save).pack(side='left', padx=3)

        self.view = tk.Label(root, bg='#202020', width=SIZE, height=SIZE)
        self.view.pack(side='right', padx=4, pady=4)
        self.redraw()

    def set_fg(self, widget, c):
        widget.config(fg='white' if sum(int(c[i:i + 2], 16) for i in (1, 3, 5)) < 380 else 'black')

    def pick(self, name, widget):
        c = colorchooser.askcolor(self.colors[name])[1]
        if c:
            self.colors[name] = c
            widget.config(bg=c)
            self.set_fg(widget, c)
            self.schedule()

    def random_seed(self):
        self.vars['seed'].set(np.random.randint(10000))
        self.schedule()

    def schedule(self):
        if self.pending:
            self.root.after_cancel(self.pending)
        self.pending = self.root.after(150, self.redraw)

    def redraw(self):
        self.pending = None
        P = {k: v.get() for k, v in self.vars.items()}
        C = {k: tuple(int(c[i:i + 2], 16) / 255 for i in (1, 3, 5)) for k, c in self.colors.items()}
        self.image = render(P, C, self.cache, self.transparent.get())
        self.tkimg = ImageTk.PhotoImage(self.image)
        self.view.config(image=self.tkimg, width=SIZE, height=SIZE)

    def save(self):
        path = filedialog.asksaveasfilename(defaultextension='.png', filetypes=[('PNG', '*.png')])
        if path:
            self.image.save(path)


if __name__ == '__main__':
    root = tk.Tk()
    root.title('Planet Generator')
    App(root)
    root.mainloop()