PtvPack are a noise/pro/fasttracker (.mod) modules packer
and replay routine targeting the Apollo Vampire cards.

It handles modules from 1 to 16 channels with up to 5 octaves.
The (adaptive) replay uses hardware mixing
(Look at test.asm for an example about how to use it).

The patterns structure is optimized to increase compression ratio,
the converter can split them from samples to generate 2 files
and the samples can optionally be packed with ADPCM.

It's a command line tool (Windows and Amiga executable packers are provided).

Have fun,
h.
