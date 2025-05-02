#ifndef _MAIN_H_
#define _MAIN_H_

// -------------------------------------------------
// Includes
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// -------------------------------------------------
// Types
typedef unsigned char BYTE;
typedef unsigned char * LPBYTE;
typedef unsigned short WORD;
typedef unsigned int DWORD;

// -------------------------------------------------
// Structures
typedef struct
{
    FILE *Output_PTV;
    FILE *Output_SMP;
    int Pos_In_Datas;
    BYTE *Input_Mem;
    int Input_Size;
    int Nbr_Files;
} FNC_TABLE, *LPFNC_TABLE;

// -------------------------------------------------
// Constants
#define MAX_PATH 262
#define FALSE 0
#define TRUE 1

enum
{
    ERR_LOADFILE,
    ERR_CREATEFILE,
    ERR_WRITEFILE,
    ERR_MEMORY,
    ERR_UNKNOWN_FORMAT,
};

#endif
