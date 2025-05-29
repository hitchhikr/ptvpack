// -------------------------------------------------
// ptvpack v1.3c
// Written by Franck 'hitchhikr' Charlet.

// -------------------------------------------------
// Includes
#include "main.h"

#ifdef HOST_BIG_ENDIAN
#define SEPARATOR "/"
#else
#define SEPARATOR "\\"
#endif

// -------------------------------------------------
// Errors table
char *Errors_Msg[] =
{
    "Can't load input file.\n",
    "Can't create output file.\n",
    "Can't write into output file.\n",
    "Not enough memory.\n",
    "Not a noise/protracker/fasttracker 1 module.\n",
};

#define REF_BLOCK_NOTES 0
#define REF_BLOCK_INSTR 1
#define REF_BLOCK_FX 2
#define REF_BLOCK_Data 3

// -------------------------------------------------
// Structures
typedef struct
{
    int On;
    int Length;
    int FineTune;
    int Volume;
    int Repeat_Start;
    int Repeat_Length;
    char *Data;
} SAMPLE_INFOS, *LPSAMPLE_INFOS;

typedef struct
{
    int Note;
    int Row_Dat[4];
    int Ref_Block[4];
} TRACK_DAT, *LPTRACK_DAT;

typedef struct
{
    TRACK_DAT Channel[16];
} TRACK_ROW, *LPTRACK_ROW;

typedef struct
{
    TRACK_ROW Rows[64];
} TRACKS, *LPTRACKS;

typedef struct
{
    BYTE Data[16];
} DAT_BLOCK, *LPDAT_BLOCK;

// -------------------------------------------------
// Variables
FILE *Input;
FNC_TABLE Serv;
BYTE Sample_Name[22];
LPTRACKS Patterns = NULL;
int Compression_Kbps;
char Dest_FileName[MAX_PATH];
char Dest_FileName_Smp[MAX_PATH];

WORD mt_periods[] =
{
    3424,3232,3048,2880,2712,2560,2416,2280,2152,2032,1920,1812,
    1712,1616,1524,1440,1356,1280,1208,1140,1076,1016, 960, 906,
     856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
     428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
     214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113,
};

int Nbr_Blocks[4];
LPDAT_BLOCK Tmp_Blocks = NULL;
LPDAT_BLOCK Blocks[4];
int There_Was_Error = FALSE;

unsigned int mt_tags[] =
{
    '1CHN', '2CHN', '3CHN', '4CHN',
    '5CHN', '6CHN', '7CHN', '8CHN',
    '9CHN', '10CH', '11CH', '12CH',
    '13CH', '14CH', '15CH', '16CH'
};

// -------------------------------------------------
// Display an error message
void Print_Error(int Err_Number)
{
    There_Was_Error = TRUE;
    printf("Error: %s", Errors_Msg[Err_Number]);
}

// -------------------------------------------------
// Free allocated memory & close opened files
void Free_Stuff(int Split_Samples)
{
    if(Serv.Input_Mem) free(Serv.Input_Mem);
    if(Input) fclose(Input);
    if(Serv.Output_PTV) fclose(Serv.Output_PTV);
    if(Split_Samples) if(Serv.Output_SMP) fclose(Serv.Output_SMP);
}

// -----------------------------------------------------------------------
// Replace_FileName_Extension() method
char *Replace_FileName_Extension(char *FileName, char *NewExtension)
{
	int i;

	i = strlen(FileName);
	while(i--)
    {
		if(FileName[i] == '.') break;
	}
	if(i > 0) FileName[i] = 0;
	strcat(FileName, ".");
	strcat(FileName, NewExtension);
    return(FileName);
}

// -------------------------------------------------
// Check if a file exists
int File_Exist(char *Filename)
{
    FILE *f = fopen(Filename, "rb");
    if(f)
    {
        fclose(f);
        return(TRUE);
    }
    return(FALSE);
}

// -------------------------------------------------
// Load the Future composer file into memory
int Load_Input_File(char *FileName)
{
    Serv.Pos_In_Data = 0;
    
    Input = fopen(FileName, "rb");
    if(!Input)
    {
        Print_Error(ERR_LOADFILE);
        return(FALSE);
    }
    // Get the filesize
    fseek(Input, 0, SEEK_END);
	Serv.Input_Size = ftell(Input);
    fseek(Input, 0, SEEK_SET);

    Serv.Input_Mem = (BYTE *) malloc(Serv.Input_Size);
    if(!Serv.Input_Mem)
    {
        Print_Error(ERR_MEMORY);
        return(FALSE);
    }
    if(fread(Serv.Input_Mem, 1, Serv.Input_Size, Input) != (size_t) Serv.Input_Size)
    {
        Print_Error(ERR_LOADFILE);
        return(FALSE);
    }
    return(TRUE);
}

// -------------------------------------------------
// Write data
int Write_WORD_SWAP(WORD Data)
{
    WORD Data_Swap;

#ifndef HOST_BIG_ENDIAN
    Data_Swap = (Data & 0xff) << 8;
    Data_Swap |= (Data & 0xff00) >> 8;
#else
    Data_Swap = Data;
#endif

    return(fwrite(&Data_Swap, 1, 2, Serv.Output_PTV) == 2);
}

int Write_DWORD_SWAP(DWORD Data)
{
    DWORD Data_Swap;

#ifndef HOST_BIG_ENDIAN
    Data_Swap = (Data & 0xff) << 24;
    Data_Swap |= (Data & 0xff00) << 8;
    Data_Swap |= (Data & 0xff0000) >> 8;
    Data_Swap |= (Data & 0xff000000) >> 24;
#else
    Data_Swap = Data;
#endif

    return(fwrite(&Data_Swap, 1, 4, Serv.Output_PTV) == 4);
}

int Write_BYTE(BYTE Data)
{
    return(fwrite(&Data, 1, 1, Serv.Output_PTV) == 1);
}

int Write_SIZE(FILE *File, DWORD Data)
{
    DWORD Data_Swap;

#ifndef HOST_BIG_ENDIAN
    Data_Swap = (Data & 0xff) << 24;
    Data_Swap |= (Data & 0xff00) << 8;
    Data_Swap |= (Data & 0xff0000) >> 8;
    Data_Swap |= (Data & 0xff000000) >> 24;
#else
    Data_Swap = Data;
#endif

    return(fwrite(&Data_Swap, 1, 4, File) == 4);
}

int Write_ARRAY(FILE *File, BYTE *Data, int Size)
{
    return((int) fwrite(Data, 1, Size, File) == Size);
}

// -------------------------------------------------
// Retrieve Data from the input file
DWORD Get_DWORD()
{
    DWORD Dat = Serv.Input_Mem[Serv.Pos_In_Data] << 24;
    Dat |= Serv.Input_Mem[Serv.Pos_In_Data + 1] << 16;
    Dat |= Serv.Input_Mem[Serv.Pos_In_Data + 2] << 8;
    Dat |= Serv.Input_Mem[Serv.Pos_In_Data + 3];
    Serv.Pos_In_Data += 4;
    return(Dat);
}

WORD Get_WORD()
{
    WORD Dat = Serv.Input_Mem[Serv.Pos_In_Data] << 8;
    Dat |= Serv.Input_Mem[Serv.Pos_In_Data + 1];
    Serv.Pos_In_Data += 2;
    return(Dat);
}

int Swap_DWORD()
{
    DWORD Dat = Get_DWORD();

    Serv.Input_Mem[Serv.Pos_In_Data + 3 - 4] = (BYTE) (Dat >> 24);
    Serv.Input_Mem[Serv.Pos_In_Data + 2 - 4] = (BYTE) (Dat >> 16);
    Serv.Input_Mem[Serv.Pos_In_Data + 1 - 4] = (BYTE) (Dat >> 8);
    Serv.Input_Mem[Serv.Pos_In_Data - 4] = (BYTE) (Dat & 0xff);
    return(Dat);
}

int Swap_WORD()
{
    DWORD Dat = Get_WORD();

    Serv.Input_Mem[Serv.Pos_In_Data + 1 - 2] = (BYTE) (Dat >> 8);
    Serv.Input_Mem[Serv.Pos_In_Data - 2] = (BYTE) (Dat & 0xff);
    return(Dat);
}

void Get_ARRAY(BYTE *Array, int Len)
{
    int i = 0;
    while(Len)
    {
        Array[i] = Serv.Input_Mem[Serv.Pos_In_Data];
        Len--;
        i++;
        Serv.Pos_In_Data++;
    }
}

BYTE Get_BYTE()
{
    Serv.Pos_In_Data++;
    return(Serv.Input_Mem[Serv.Pos_In_Data - 1]);
}

void Set_Mem_Ptr(int Position)
{
    Serv.Pos_In_Data = Position;
}

int Get_Mem_Ptr()
{
    return(Serv.Pos_In_Data);
}

void Inc_Mem_Ptr(int Value)
{
    Serv.Pos_In_Data += Value;
}

void Dec_Mem_Ptr(int Value)
{
    Serv.Pos_In_Data -= Value;
}

// -------------------------------------------------
// Pack a sample
int PackSample(char *Source, int length, int pack, int split)
{
    int Dest_Size;
    char *Pack_Buf;
    char *Empty_Buf;
    FILE *hFile;
    char Command[1024];
    int i;
    BYTE wDatum;

    Pack_Buf = (char *) malloc(length * 2);
    if(!Pack_Buf)
    {
        return(FALSE);
    }
    Empty_Buf = (char *) malloc(length * 2);
    if(!Empty_Buf)
    {
        free(Pack_Buf);
        return(FALSE);
    }
    memset(Empty_Buf, 0, length * 2);
    memset(Pack_Buf, 0, length * 2);
    // Needed for some shitty software
    Source[0] = 0;
    Source[1] = 0;
    if(!pack)
    {
        memcpy(Pack_Buf, Source, length);
        Dest_Size = length;
    }
    else
    {
        hFile = fopen("sample.raw", "wb");
        if(hFile)
        {
            for(i = 0; i < length; i++)
            {
                wDatum = Source[i];
                fwrite(&wDatum, 1, 2, hFile);
            }
            fclose(hFile);
            // Pack it
            sprintf(Command, "tools" SEPARATOR "lame -r -t -m m --signed -q 0 -b %d -h sample.raw sample.mp3", Compression_Kbps);
            if(system(Command) != 0)
            {
                free(Pack_Buf);
                free(Empty_Buf);
                return(FALSE);
            }
            hFile = fopen("sample.mp3", "rb");
            if(hFile)
            {
                fseek(hFile, 0, SEEK_END);
                Dest_Size = ftell(hFile);
                fseek(hFile, 0, SEEK_SET);
                fread(Pack_Buf, 1, Dest_Size, hFile);
                fclose(hFile);
            }
            else
            {
                free(Pack_Buf);
                free(Empty_Buf);
                return(FALSE);
            }
            remove("sample.raw");
            remove("sample.mp3");
        }
        else
        {
            free(Pack_Buf);
            free(Empty_Buf);
            return(FALSE);
        }
    }
    if(split)
    {
        if(pack)
        {
            Write_SIZE(Serv.Output_SMP, Dest_Size);
        }
        Write_ARRAY(Serv.Output_SMP, (LPBYTE) Pack_Buf, Dest_Size);
    }
    else
    {
        if(pack)
        {
            Write_SIZE(Serv.Output_PTV, Dest_Size);
        }
        Write_ARRAY(Serv.Output_PTV, (LPBYTE) Pack_Buf, Dest_Size);
    }
    free(Pack_Buf);
    free(Empty_Buf);
    return(TRUE);
}

// -------------------------------------------------
// Pack a module
int main(int argc, const char *argv[])
{
    int Use_Packed_Samples = FALSE;
    int Split_Samples = FALSE;
    int Remap_Fx;
    int i;
    int j;
    int k;
    int l;
    int Nbr_Positions;
    int Nbr_Positions_Even;
    int Restart_Pos;
    int Nbr_Samples = 0;
    int Real_Sample_Length;
    int Real_Sample_Loop_Length;
    LPSAMPLE_INFOS Samples_Infos = NULL;
    int Samples_Used[31];
    BYTE *Positions;
    char *Samples_Envelope = NULL;
    int Note_Dat;
    int Track_Dat;
    char Module_Name[21];
    char Instr_Name[31][24];
    DWORD ModId;
    int Used_Fx[16];
    int Used_Sub_Fx[16];
    int Used_FineTune[16];
    unsigned char Cmd_Data;
    unsigned char Cmd_Hi;
    unsigned char Cmd_Lo;
    int Len_Source_FileName;
    int Cur_Length;
    char Source_FileName[MAX_PATH];
    char *Mod_Extension;
    int Extension_Pos;
    int Nbr_Patterns;
    int Nbr_Patterns_Real;
    int Nbr_Channels;
    int Pos_Args;
    int Phony_Pos;
 
    printf("ptvpack v1.3c\n");
    printf("Written by hitchhikr of Neural\n");

    memset(Used_Fx, 0, sizeof(Used_Fx));
    memset(Used_Sub_Fx, 0, sizeof(Used_Sub_Fx));
    memset(Used_FineTune, 0, sizeof(Used_FineTune));

    if(argc < 2)
    {
Return_Usage:
        printf("\nUsage: ptvpack [-s] [-p <kbps>] <Input file.mod>\n\n");
        printf("       -s: split module into 2 files (patterns / samples)\n");
        printf("       -p <kbps>: pack samples with MP3\n");
        return(0);
    }

    Pos_Args = 1;
    argc--;
    while((argc > 0) && argv[Pos_Args][0] == '-')
    {
        switch(toupper(argv[Pos_Args][1]))
        {
            case 'P':
                Pos_Args++;
                argc--;
                if(argc <= 0) break;
                Compression_Kbps = atoi(argv[Pos_Args]);
                Use_Packed_Samples = TRUE;
                break;
            case 'S':
                Split_Samples = TRUE;
                break;
            default:
                goto Return_Usage;
        }
        argc--;
        Pos_Args++;
    }
    if(argc == 1)
    {
        strcpy(Source_FileName, argv[Pos_Args]);

        // Devise the executable name
        memset(Dest_FileName, 0, MAX_PATH);
        Len_Source_FileName = strlen(Source_FileName);
        if(Len_Source_FileName > 4)
        {
            if(Source_FileName[Len_Source_FileName - 4] == '.')
            {
                memcpy(Dest_FileName, Source_FileName, Len_Source_FileName - 4);
            }
            else
            {
                // mod. style
                if(Source_FileName[3] == '.')
                {
                    memcpy(Dest_FileName, Source_FileName + 4, Len_Source_FileName - 4);
                }
                else
                {
                    // Complete path (like with drag'n'drop)
                    strcpy(Dest_FileName, Source_FileName);
                    Mod_Extension = strchr(Dest_FileName, '.');
                    if(Mod_Extension)
                    {
                        Extension_Pos = (Mod_Extension - Dest_FileName) + 1;
                        while(Dest_FileName[Len_Source_FileName - 1] != '\\' && Len_Source_FileName)
                        {
                            Len_Source_FileName--;
                        }
                        strcpy(&Dest_FileName[Len_Source_FileName], &Dest_FileName[Extension_Pos]);
                    }
                }
            }
        }
        else
        {
            memcpy(Dest_FileName, argv[Pos_Args], Len_Source_FileName);
        }
        strcat(Dest_FileName, ".ptv");
    }
    else
    {
        goto Return_Usage;
    }

    if(Split_Samples)
    {
        memcpy(Dest_FileName_Smp, Dest_FileName, MAX_PATH);
        Replace_FileName_Extension(Dest_FileName_Smp, "smp");
    }

    if(Load_Input_File(Source_FileName))
    {
        if(Split_Samples)
        {
            printf("\nConverting to %s and %s...\n", Dest_FileName, Dest_FileName_Smp);
        }
        else
        {
            printf("\nConverting to %s...\n", Dest_FileName);
        }
        Serv.Output_PTV = fopen(Dest_FileName, "wb");
        if(Serv.Output_PTV)
        {
            if(Split_Samples)
            {
                Serv.Output_SMP = fopen(Dest_FileName_Smp, "wb");
            }
            else
            {
                Serv.Output_SMP = (FILE *) -1;      // Phony handle
            }
            if(Serv.Output_SMP)
            {
                Set_Mem_Ptr(1080);
                ModId = Get_DWORD();
                Nbr_Channels = 0;
                
                for(i = 0; i < sizeof(mt_tags) / sizeof(unsigned int); i++)
                {
                    if(ModId == 'M.K.')
                    {
                        Nbr_Channels = 4;
                        break;
                    }
                    if(mt_tags[i] == ModId)
                    {
                        Nbr_Channels = i + 1;
                        break;
                    }
                }
                if(Nbr_Channels)
                {
                    // Take the name of the module
                    Set_Mem_Ptr(0);
                    for(i = 0; i < 20; i++)
                    {
                        Module_Name[i] = Get_BYTE();
                    }

                    Samples_Infos = (LPSAMPLE_INFOS) malloc(31 * sizeof(SAMPLE_INFOS));
                    memset(Samples_Infos, 0, 31 * sizeof(SAMPLE_INFOS));
                    memset(Samples_Used, 0, 31 * sizeof(int));
                    Set_Mem_Ptr(20 + 22);

                    // Samples infos
                    for(i = 0; i < 31; i++)
                    {
                        Cur_Length = Get_WORD();
                        memcpy(&Instr_Name[i][0], &Serv.Input_Mem[Serv.Pos_In_Data - 2 - 22], 22);
                        Samples_Infos[i].On = TRUE;
                        Samples_Infos[i].Length = Cur_Length;
                        Samples_Infos[i].FineTune = Get_BYTE();
                        Used_FineTune[Samples_Infos[i].FineTune] = TRUE;
                        Samples_Infos[i].Volume = Get_BYTE();
                        Samples_Infos[i].Repeat_Start = Get_WORD();
                        Samples_Infos[i].Repeat_Length = Get_WORD();
                        // Needed for some shitty software
                        if(Samples_Infos[i].Repeat_Length == 0)
                        {
                            Samples_Infos[i].Repeat_Length = 1;
                        }
                        Inc_Mem_Ptr(22);
                    }
                    Set_Mem_Ptr(950);
                    Nbr_Positions = Get_BYTE();
                    Restart_Pos = Get_BYTE();                     // Restart
                    Nbr_Patterns = -1;
                    Nbr_Patterns_Real = -1;

                    Positions = (BYTE *) malloc(Nbr_Positions * sizeof(BYTE));
                    memset(Positions, 0, Nbr_Positions * sizeof(BYTE));

                    // Positions
                    for(i = 0; i < 128; i++)
                    {
                        if(i < Nbr_Positions)
                        {
                            Positions[i] = Get_BYTE();
                            if(Positions[i] > Nbr_Patterns) Nbr_Patterns = Positions[i];
                            if(Positions[i] > Nbr_Patterns_Real) Nbr_Patterns_Real = Positions[i];
                        }
                        else
                        {
                            // This is or malformed modules w more patterns than reported positions :(
                            Phony_Pos = Get_BYTE();
                            if(Phony_Pos > Nbr_Patterns_Real) Nbr_Patterns_Real = Phony_Pos;
                        }
                    }

                    Set_Mem_Ptr(1084);
                    Nbr_Patterns++;
                    Nbr_Patterns_Real++;

                    Patterns = (LPTRACKS) malloc(Nbr_Patterns * sizeof(TRACKS));
                    memset(Patterns, 0, Nbr_Patterns * sizeof(TRACKS));

                    // Patterns
                    for(i = 0; i < Nbr_Patterns; i++)
                    {
                        for(j = 0; j < 64; j++)
                        {
                            for(k = 0; k < Nbr_Channels; k++)
                            {
                                Note_Dat = Get_WORD();
                                Patterns[i].Rows[j].Channel[k].Note = Note_Dat & 0xfff;
                                Track_Dat = Get_WORD();
                                Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_INSTR] = ((Track_Dat & 0xf000) >> 12) | ((Note_Dat & 0xf000) >> 8);
                                if(Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_INSTR])
                                {
                                    if(Samples_Infos[Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_INSTR] - 1].Length >= 2)
                                    {
                                        Samples_Used[Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_INSTR] - 1] = TRUE;
                                    }
                                }
                                Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_FX] = (Track_Dat & 0xf00) >> 8;
                                Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_Data] = (Track_Dat & 0xff);
                            }
                        }
                    }

                    // Samples
                    int Pos_module = (Nbr_Patterns_Real * 64 * 4 * Nbr_Channels) + 1084;
                    Set_Mem_Ptr(Pos_module);
                    for(i = 0; i < 31; i++)
                    {
                        if(Samples_Used[i])
                        {
                            Nbr_Samples++;
                            if(Samples_Infos[i].Length)
                            {
                                Samples_Infos[i].Data = (char *) malloc((Samples_Infos[i].Length * 2) * sizeof(char));
                                memset(Samples_Infos[i].Data, 0, (Samples_Infos[i].Length * 2) * sizeof(char));
							    for(j = 0; j < (Samples_Infos[i].Length * 2); j++)
                                {
                                    Samples_Infos[i].Data[j] = Get_BYTE(); 
                                }
                            }
                            else
                            {
                                // Such small sample would probably be used as a loop
                                // so if there's no loop the instrument was used in the patterns
                                // but there's no waveform
                                if(Samples_Infos[i].Repeat_Length >= 2)
                                {
                                    // 2 bytes sample
                                    Samples_Infos[i].Length = 8;
                                    Samples_Infos[i].FineTune = 0;
                                    Samples_Infos[i].Volume = 0;
                                    Samples_Infos[i].Data = (char *) malloc((8 * 2) * sizeof(char));
                                    memset(Samples_Infos[i].Data, 0, (8 * 2) * sizeof(char));
                                }
                            }
                        }
                        Pos_module += (Samples_Infos[i].Length * 2);
                        Set_Mem_Ptr(Pos_module);
                    }

                    // --------------------------------------------
                    // Create the fx constants file
                    int E_Used = FALSE;
                    char *table_used_fx[16] = 
                    {
                        "PTV_ARPEGGIO",
                        "PTV_PORTAMENTOUP",
                        "PTV_PORTAMENTODOWN",
                        "PTV_TONEPORTAMENTO",
                        "PTV_VIBRATO",
                        "PTV_TONEPLUSVOLSLIDE",
                        "PTV_VIBRATOPLUSVOLSLIDE",
                        "PTV_TREMOLO",
                        "PTV_SETSYNCHRO",
                        "PTV_SAMPLEOFFSET",
                        "PTV_VOLUMESLIDE",
                        "PTV_POSITIONJUMP",
                        "PTV_VOLUMECHANGE",
                        "PTV_PATTERNBREAK",
                        "",
                        "PTV_SETSPEED"
                    };

                    char *table_used_finetune[16] = 
                    {
                        "", 
                        "PTV_FINETUNE_1",
                        "PTV_FINETUNE_2",
                        "PTV_FINETUNE_3",
                        "PTV_FINETUNE_4",
                        "PTV_FINETUNE_5",
                        "PTV_FINETUNE_6",
                        "PTV_FINETUNE_7",
                        "PTV_FINETUNE_M8",
                        "PTV_FINETUNE_M7",
                        "PTV_FINETUNE_M6",
                        "PTV_FINETUNE_M5",
                        "PTV_FINETUNE_M4",
                        "PTV_FINETUNE_M3",
                        "PTV_FINETUNE_M2",
                        "PTV_FINETUNE_M1"
                    };

                    char *table_used_sub_fx[16] = 
                    {
                        "PTV_EFX_FILTERONOFF",
                        "PTV_EFX_FINEPORTAUP",
                        "PTV_EFX_FINEPORTADOWN",
                        "PTV_EFX_SETGLISSCONTROL",
                        "PTV_EFX_SETVIBRATOCONTROL",
                        "PTV_EFX_SETFINETUNE",
                        "PTV_EFX_JUMPLOOP",
                        "PTV_EFX_SETTREMOLOCONTROL",
                        "PTV_EFX_KARPLUSTRONG",
                        "PTV_EFX_RETRIGNOTE",
                        "PTV_EFX_VOLUMEFINEUP",
                        "PTV_EFX_VOLUMEFINEDOWN",
                        "PTV_EFX_NOTECUT",
                        "PTV_EFX_NOTEDELAY",
                        "PTV_EFX_PATTERNDELAY",
                        "PTV_EFX_FUNKIT"
                    };

                    // Write the fx numbers
                    for(k = 0; k < Nbr_Channels; k++)
                    {
                        for(i = 0; i < Nbr_Patterns; i++)
                        {
                            for(j = 0; j < 64; j++)
                            {
                                Remap_Fx = Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_FX];
                                if(Remap_Fx == 0)
                                {
                                    // Arpeggios used
                                    if(Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_Data])
                                    {
                                        Used_Fx[Remap_Fx] = TRUE;
                                    }
                                }
                                else
                                {
                                    if(Remap_Fx != 0xe)
                                    {
                                        Used_Fx[Remap_Fx] = TRUE;
                                        switch(Remap_Fx)
                                        {
                                            case 5:
                                                Used_Fx[3] = TRUE;
                                                Used_Fx[0xa] = TRUE;
                                                break;

                                            case 6:
                                                Used_Fx[4] = TRUE;
                                                Used_Fx[0xa] = TRUE;
                                                break;

                                            case 0xb:
                                                Cmd_Data = Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_Data];
                                                Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_Data] = Cmd_Data - 1;
                                                break;

                                            case 0xd:
                                                // Transform the index to hexa
                                                Cmd_Data = Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_Data];
                                                Cmd_Hi = (Cmd_Data >> 4);
                                                Cmd_Lo = Cmd_Data - (Cmd_Hi << 4);
                                                Cmd_Data = (Cmd_Hi * 10) + Cmd_Lo;
                                                if(Cmd_Data > 63) Cmd_Data = 0;
                                                Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_Data] = Cmd_Data;
                                                break;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Write the fx Data
                    for(k = 0; k < Nbr_Channels; k++)
                    {
                        for(i = 0; i < Nbr_Patterns; i++)
                        {
                            for(j = 0; j < 64; j++)
                            {
                                if(Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_FX] == 0xe)
                                {
                                    E_Used = TRUE;
                                    Remap_Fx = Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_Data] >> 4;
                                    // Need volume slides
                                    if(Remap_Fx == 0xa) Used_Fx[0xa] = TRUE;
                                    if(Remap_Fx == 0xb) Used_Fx[0xa] = TRUE;

                                    // Use global ports
                                    if(Remap_Fx == 1) Used_Fx[Remap_Fx] = TRUE;
                                    if(Remap_Fx == 2) Used_Fx[Remap_Fx] = TRUE;
                                    Used_Sub_Fx[Remap_Fx] = TRUE;
                                    // Set fine tune
                                    if(Remap_Fx == 5)
                                    {
                                        Used_FineTune
                                            [
                                                Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_Data] & 0xf
                                            ] = TRUE;
                                    }
                                    // Use retrig stuff for notes delay too
                                    if(Remap_Fx == 0xd) Used_Sub_Fx[0x9] = TRUE;
                                }
                            }
                        }
                    }

                    // Generate the constants file
                    char Dat[2048];
                    sprintf(Dat, "constants.inc");

                    FILE *constout = fopen(Dat, "w");
                    if(constout)
                    {
                        if(E_Used) fprintf(constout, "PTV_EXTEND equ 1\n");
                        if(Use_Packed_Samples) fprintf(constout, "PTV_PACKED_SMP equ 1\n");
                        for(i = 0; i < 16; i++)
                        {
                            if(Used_Fx[i])
                            {
                                if(strlen(table_used_fx[i]))
                                {
                                    fprintf(constout, "%s equ 1\n", table_used_fx[i]);
                                }
                            }
                        }
                        for(i = 0; i < 16; i++)
                        {
                            if(Used_Sub_Fx[i])
                            {
                                if(strlen(table_used_sub_fx[i]))
                                {
                                    fprintf(constout, "%s equ 1\n", table_used_sub_fx[i]);
                                }
                            }
                        }
                        // no finetune index 0
                        for(i = 1; i < 16; i++)
                        {
                            if(Used_FineTune[i])
                            {
                                if(strlen(table_used_finetune[i]))
                                {
                                    fprintf(constout, "%s equ 1\n", table_used_finetune[i]);
                                }
                            }
                        }
                        fclose(constout);
                    }
                    // -----------------------------------------

                    Nbr_Positions_Even = 0;
                    if(Nbr_Positions & 1) Nbr_Positions_Even = 1;
              
                    // Change the instruments numbers in the patterns if necessary
                    for(i = 31 - 1; i >= 0; i--)
                    {
                        if(!Samples_Used[i])
                        {
                            for(l = 0; l < Nbr_Channels; l++)
                            {
                                for(j = 0; j < Nbr_Patterns; j++)
                                {
                                    for(k = 0; k < 64; k++)
                                    {
                                        if((Patterns[j].Rows[k].Channel[l].Row_Dat[REF_BLOCK_INSTR] - 1) > i)
                                        {
                                            Patterns[j].Rows[k].Channel[l].Row_Dat[REF_BLOCK_INSTR]--;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    int Found_Note;

                    // Transform the Notes
                    for(k = 0; k < Nbr_Channels; k++)
                    {
                        for(i = 0; i < Nbr_Patterns; i++)
                        {
                            for(j = 0; j < 64; j++)
                            {
                                Found_Note = FALSE;
                                // 5 * 12 = number of notes in table
                                for(l = 0; l < (5 * 12); l++)
                                {
                                    if(Patterns[i].Rows[j].Channel[k].Note == mt_periods[l])
                                    {
                                        Found_Note = TRUE;
                                        break;
                                    }
                                }
                                l++;
                                if(!Found_Note) l = 0;
                                Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_NOTES] = l;
                            }
                        }
                    }

                    // Amount of channels
                    // 0
                    Write_WORD_SWAP(Nbr_Channels);
                    // Positions offset
                    // 0
                    // *16 for each sample infos
                    // +12 for the 3 dword pointers below
                    // +10 for 2 bytes + 2 dword below
                    Write_DWORD_SWAP((Nbr_Samples * 16) + 12 + 10);
                    // Patterns offset
                    // 4
                    Write_DWORD_SWAP(((Nbr_Samples * 16) + (Nbr_Positions + Nbr_Positions_Even)) + 12 + 10);
                    // Samples offset
                    // 8
                    // *4 for the 4 bytes of a pattern's track
                    Write_DWORD_SWAP(((Nbr_Samples * 16) + (Nbr_Positions + Nbr_Positions_Even) +
                                     (Nbr_Patterns * 64 * 4 * Nbr_Channels)) + 12 + 10);
                    // 12
                    Write_BYTE(Nbr_Samples - 1);
                    // 13
                    Write_BYTE(Nbr_Positions);
                    // Size of a pattern chunk
                    // 14
                    Write_DWORD_SWAP(Nbr_Patterns * 64);
                    // Size of a all columns of patterns
                    // 18
                    Write_DWORD_SWAP(Nbr_Patterns * 64 * Nbr_Channels);

                    // Write the packed samples infos
                    // 16
                    for(i = 0; i < 31; i++)
                    {
                        if(Samples_Used[i])
                        {
                            Real_Sample_Length = Samples_Infos[i].Length;
                            Real_Sample_Loop_Length = (Samples_Infos[i].Repeat_Start + Samples_Infos[i].Repeat_Length);
                            if(Real_Sample_Loop_Length >= 2) if(Real_Sample_Loop_Length < Real_Sample_Length) Real_Sample_Length = Real_Sample_Loop_Length;

                            Write_DWORD_SWAP(Real_Sample_Length * (Use_Packed_Samples ? 1 : 1));
                            Write_BYTE(Samples_Infos[i].FineTune);
                            Write_BYTE(Samples_Infos[i].Volume);
                            if(Samples_Infos[i].Repeat_Length == 1)
                            {
                                Write_DWORD_SWAP(0);
                            }
                            else
                            {
                                Write_DWORD_SWAP(Samples_Infos[i].Repeat_Start * (Use_Packed_Samples ? 1 : 1));
                            }
                            Write_DWORD_SWAP(Samples_Infos[i].Repeat_Length * (Use_Packed_Samples ? 1 : 1));
                            // Pad to 16 bytes
                            Write_WORD_SWAP(0);
                        }
                    }

                    // Write the positions
                    for(i = 0; i < Nbr_Positions; i++)
                    {
                        Write_BYTE((BYTE) Positions[i]);
                    }

                    // Make sure everything is aligned
                    if(Nbr_Positions_Even)
                    {
                        Write_BYTE(0);
                    }
                    
                    // Patterns Data
                    for(k = 0; k < Nbr_Channels; k++)
                    {
                        for(i = 0; i < Nbr_Patterns; i++)
                        {
                            for(j = 0; j < 64; j++)
                            {
                                Write_BYTE(Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_NOTES]);
                            }
                        }
                    }

                    // Write the instruments numbers
                    for(k = 0; k < Nbr_Channels; k++)
                    {
                        for(i = 0; i < Nbr_Patterns; i++)
                        {
                            for(j = 0; j < 64; j++)
                            {
                                Write_BYTE(Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_INSTR]);
                            }
                        }
                    }

                    // Write the fx numbers
                    for(k = 0; k < Nbr_Channels; k++)
                    {
                        for(i = 0; i < Nbr_Patterns; i++)
                        {
                            for(j = 0; j < 64; j++)
                            {
                                Remap_Fx = Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_FX];
                                Write_BYTE(Remap_Fx);
                            }
                        }
                    }
                    // Write the fx Data
                    for(k = 0; k < Nbr_Channels; k++)
                    {
                        for(i = 0; i < Nbr_Patterns; i++)
                        {
                            for(j = 0; j < 64; j++)
                            {
                                Write_BYTE(Patterns[i].Rows[j].Channel[k].Row_Dat[REF_BLOCK_Data]);
                            }
                        }
                    }

                    if(Use_Packed_Samples)
                    {
                        printf("done.\n");
                        printf("Packing samples...\n");
                    }
    			    // Pack the samples
                    for(i = 0; i < 31; i++)
                    { 
                        if(Samples_Used[i])
                        {
                            Real_Sample_Length = Samples_Infos[i].Length;
                            if(Real_Sample_Length >= 2)
                            {
                                Real_Sample_Loop_Length = (Samples_Infos[i].Repeat_Start + Samples_Infos[i].Repeat_Length);
                                if(Real_Sample_Loop_Length >= 2)
                                {
                                    if(Real_Sample_Loop_Length < Real_Sample_Length) Real_Sample_Length = Real_Sample_Loop_Length;
                                }
                                Samples_Infos[i].Length = Real_Sample_Length;
                                // Convert to bytes
                                Real_Sample_Length *= 2;
                                if(PackSample(Samples_Infos[i].Data, Real_Sample_Length, Use_Packed_Samples, Split_Samples) == FALSE)
                                {
                                    break;
                                }
                            }
                        }
                    }
                }
                else
                {
                    Print_Error(ERR_UNKNOWN_FORMAT);
                }

                free(Blocks[REF_BLOCK_NOTES]);
                free(Blocks[REF_BLOCK_INSTR]);
                free(Blocks[REF_BLOCK_FX]);
                free(Blocks[REF_BLOCK_Data]);
                free(Samples_Envelope);

                for(i = 0; i < 31; i++)
                {
                    if(Samples_Infos[i].Data)
                    {
                        free(Samples_Infos[i].Data);
                    }
                }
                free(Positions);
                free(Patterns);
            }
        }
        else
        {
            Print_Error(ERR_CREATEFILE);
        }
    }
    Free_Stuff(Split_Samples);
    if(There_Was_Error) return(1);
    else printf("done.\n");
    return(0);
} 
