# `knnips`

> An incredibly slow $k$-NN implementation in MIPS-32 assembly. Or
> rather... $k$-Fugue in MIDI from MARS? 🎶 The oracles in `egg.s` tell
> &mdash; should bytes align with stars, and "bach" be drawn by shell &mdash;
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

## Licensing

`knnips` is licensed under the terms of the [GPL-3.0 license](LICENSE).

### External dependencies

The MARS software (`Mars4_5.jar`) is licensed under the terms of the MIT
license
(<https://courses.missouristate.edu/KenVollmar/mars/license.htm>). Its
license is included the `Mars4_5.jar` archive, and can be obtained with:

    jar -xf Mars4_5.jar MARSlicense.txt

The `MARSlicense.txt` file is included in this repository for compliance
with the license's terms.
