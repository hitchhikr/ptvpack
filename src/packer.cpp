// ---------------------------------------------------------------------------
// Includes
#include "packer.h"

static int pack_stepsizeTable[] =
{
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
};

/* Intel ADPCM step variation table */
int pack_indextable[16] =
{
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8,
};

int adpcm_coder(char *indata, char *outdata, int len)
{
    char *inp;                  /* Input buffer pointer */
    signed char *outp;          /* output buffer pointer */
    int val;                    /* Current input sample value */
    int sign;                   /* Current adpcm sign bit */
    int delta;                  /* Current adpcm output value */
    int diff;                   /* Difference between val and valprev */
    int step;                   /* Stepsize */
    int valpred;                /* Predicted output value */
    int vpdiff;                 /* Current change to valpred */
    int index;                  /* Current step change index */
    int outputbuffer = 0;       /* place to keep previous 4-bit value */
    int bufferstep;             /* toggle between outputbuffer/output */
     int ret_len = 0;
    outp = (signed char *) outdata;
    inp = indata;

    valpred = 0;
    index = 0;
    step = pack_stepsizeTable[index];

    bufferstep = 1;

    for(; len > 0; len--)
    {
        val = (*inp++) << 8;
        //if(val & 0x8000) val |= 0xffff0000;
        /* Step 1 - compute difference with previous value */
        /* Step 4 - Clamp previous value to 16 bits */
        if(valpred > 32767) valpred = 32767;
        else if(valpred < -32768) valpred = -32768;

        diff = val - valpred;
        sign = (diff < 0) ? 8 : 0;
        if(sign) diff = (-diff);

        /* Step 2 - Divide and clamp */
        /* Note:
        ** This code *approximately* computes:
        **    delta = diff*4/step;
        **    vpdiff = (delta+0.5)*step/4;
        ** but in shift step bits are dropped. The net result of this is
        ** that even if you have fast mul/div hardware you cannot put it to
        ** good use since the fixup would be too expensive.
        */
        delta = 0;
        vpdiff = (step >> 3);

        if(diff >= step)
        {
            delta = 4;
            diff -= step;
            vpdiff += step;
        }
        step >>= 1;
        if(diff >= step)
        {
            delta |= 2;
            diff -= step;
            vpdiff += step;
        }
        step >>= 1;
        if(diff >= step)
        {
            delta |= 1;
            vpdiff += step;
        }

        /* Step 3 - Update previous value */
        if(sign) valpred -= vpdiff;
        else valpred += vpdiff;

        /* Step 5 - Assemble value, update index and step values */
        delta |= sign;

        index += pack_indextable[delta];
        if(index < 0) index = 0;
        if(index > 88) index = 88;
        step = pack_stepsizeTable[index];

        if(bufferstep)
        {
            outputbuffer = (delta << 4) & 0xf0;
        }
        else
        {
            *outp++ = (delta & 0x0f) | outputbuffer;
            ret_len++;
        }
        bufferstep = !bufferstep;
    }

    /* Output last step, if needed */
    if(!bufferstep)
    {
        *outp++ = outputbuffer;
        ret_len++;
    }
    return(ret_len);
}
