# `knnips`

> An incredibly slow $k$-NN implementation in MIPS-32 assembly. Or
> rather... $k$-Fugue in MIDI from MARS? 🎶 The oracles in `egg.s` tell
> --- should bytes align with stars, and "bach" be drawn by shell ---
> then you shall hear the bars.

---

`knnips` implements the $k$-nearest neighbors algorithm in MIPS-32
assembly, running in the MARS emulator.

This was made initially for a university project, but I decided to give
it a little fun twist.

## Usage

Run with MARS directly:

    echo K | java -jar Mars4_5.jar knn.s | tail -n +3

Or with the helper script:

    ./knn.sh K

Where `K` is the parameter to the $k$-NN algorithm. For `knn.sh`, `K`
defaults to 1 if not given.

## How it works

TODO
