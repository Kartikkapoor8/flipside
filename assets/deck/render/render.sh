#!/bin/sh
# Re-render every PNG in this folder from deck.json, fallback-deck.json and render/brand.css.
# Needs Google Chrome in /Applications. Takes about two minutes.
cd "$(dirname "$0")" && exec python3 build.py
