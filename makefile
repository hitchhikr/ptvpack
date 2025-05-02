CC = gcc
EXENAME = ptvpack

LIBS = 

FLAGS = -fsigned-char -fno-strict-aliasing -Ofast -fno-rtti -fpermissive -Wno-write-strings -Wno-multichar -fno-exceptions
     
EXEOBJS = main.o packer.o

all: $(EXENAME)

clean: RemObj

RemObj:
	-rm -f $(EXEOBJS)

ptvpack: $(EXEOBJS)
	$(CC) -o ./$(EXENAME) $(FLAGS) $(EXEOBJS) $(LIBS)
	
main.o: src/main.cpp
	$(CC) -c -o $(@) $(FLAGS) $<

packer.o: src/packer.cpp
	$(CC) -c -o $(@) $(FLAGS) $<
