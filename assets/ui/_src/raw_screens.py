# Renders the raw screens (exact device point sizes @3x) into ../raw
import sys
from concurrent.futures import ThreadPoolExecutor
from common import *

def raw_pages():
    return {
        # name: (html, w_pt, h_pt)
        "present_669x951pt@3x":          (present_screen(3), INNER_W, INNER_H),
        "present-laser_669x951pt@3x":    (present_screen(3, laser=(0.30, 0.42)), INNER_W, INNER_H),
        "transition-135deg_669x951pt@3x":(transition_screen(0.5), INNER_W, INNER_H),
        "edit-180deg_669x951pt@3x":      (edit_screen(3, 6, 1.0), INNER_W, INNER_H),
        "ended-outer_466x678pt@3x":      (ended_screen(), OUTER_W, OUTER_H),
        "recap-mail-iphone_402x874pt@3x":(mail_iphone(), IPHONE_W, IPHONE_H),
        "recap-mail-duo-outer_466x678pt@3x": (mail_duo_outer(), OUTER_W, OUTER_H),
    }

def render(names=None, dpr=3):
    pages = raw_pages()
    jobs = []
    for name, (html, w, h) in pages.items():
        if names and not any(n in name for n in names): continue
        p = write_html("raw-" + name, page(html, w=w, h=h, bg="#000"))
        jobs.append((p, RAW / (name + ".png"), w, h))
    def run(j):
        p, out, w, h = j
        shot(p, out, w, h, dpr)
        return out, png_size(out)
    with ThreadPoolExecutor(3) as ex:
        for out, size in ex.map(run, jobs):
            print(out.name, size)

if __name__ == "__main__":
    args = sys.argv[1:]
    dpr = 3
    if args and args[0].startswith("dpr="):
        dpr = int(args[0][4:]); args = args[1:]
    render(args or None, dpr)
