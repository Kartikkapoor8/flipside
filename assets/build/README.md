# Build (not app code)

Regenerates every asset in `../brand` from the token set at the top of `build.py`.

    python3 build.py && python3 sheet.py

Needs: Google Chrome (headless render), Python 3.9+, `pip3 install --user fonttools uharfbuzz`.
`alternates/` holds the rejected/parked options: the mark geometry matrix used to pick θ/thickness, and a split-tone wordmark (Flip | side).
