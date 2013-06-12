#
# Main make file for Patmos
#

# cleanup
EXTENSIONS=class rbf rpt sof pin summary ttf qdf dat wlf done qws

#
#	Set USB to true for an FTDI chip based board (dspio, usbmin, lego)
#
USB=false
# COM port for downloader
COM_PORT=/dev/ttyUSB0

# Assembler files
APP=ALU
# Altera FPGA configuration cable
#BLASTER_TYPE=ByteBlasterMV
BLASTER_TYPE=USB-Blaster

# Is there an intention to continue to support the Cycore board?
# Maybe the BeMicro is a better substitution
ifeq ($(WINDIR),)
	USBRUNNER=./USBRunner
	S=:
else
	USBRUNNER=USBRunner.exe
	S=\;
endif

# The VHDL project for Quartus
QPROJ=dspio
QPROJ=altde2-70

all: directories tools rom
	make patmos

directories:
	-mkdir -p tmp
	-mkdir -p rbf

patsim:
	-mkdir -p simulator/build
	cd simulator/build && cmake ..
	cd simulator/build && make
	-mkdir -p bin
	cp simulator/build/src/pa* bin

emulator:
	-mkdir -p chisel/build
	$(MAKE) -C chisel BUILDDIR=$(CURDIR)/chisel/build emulator
	-mkdir -p bin
	cp chisel/build/emulator bin

elf2vhdl:
	-mkdir -p ctools/build
	cd ctools/build && cmake ..
	cd ctools/build && make
	-mkdir -p bin
	cp ctools/build/src/elf2vhdl bin

tools:
	make patsim
	make elf2vhdl
	-rm -rf java/classes
	-rm -rf java/lib
	-rm -rf java/src/patmos/asm/generated
	mkdir java/classes
	mkdir java/lib
	mkdir java/src/patmos/asm/generated
	javac -classpath lib/java-binutils-0.1.0.jar:lib/jssc.jar -d java/classes java/src/patserdow/*.java
	java -classpath lib/antlr-3.3-complete.jar org.antlr.Tool \
		-fo java/src/patmos/asm/generated java/src/grammar/PatGram.g
	javac -classpath lib/antlr-3.3-complete.jar \
		-d java/classes java/src/patmos/asm/generated/*.java \
		java/src/patmos/asm/*.java
	javac java/src/simulator/*.java \
		-d java/classes
	javac java/src/util/*.java \
		-d java/classes
	cd java/classes && jar cf ../lib/patmos-tools.jar *

# Assemble a program
tmp/%.bin: asm/%.s
	-mkdir -p $(dir $@)
	bin/paasm $< $@

# Assemble a program and generate the instruction memory VHDL table
rom:
	-rm -rf vhdl/generated
	mkdir vhdl/generated
	-mkdir -p tmp/$(dir $(APP))
	bin/paasm asm/$(APP).s tmp/$(APP).bin
	java -cp java/lib/patmos-tools.jar \
		patmos.asm.Bin2Vhdl -s tmp -d vhdl/generated $(APP).bin

# Compile a C program and download to FPGA
capp:
#	todo:Add bootloader compilation here
	-mkdir -p tmp
	cd c; make bootable-$(APP)
	mv c/$(APP) tmp/$(APP)
	make download APP=tmp/$(APP) 

# Compile a C program, the Patmos compiler must be in the path
comp:
	-mkdir -p tmp
	cd c; make $(APP)
	mv c/$(APP) tmp/$(APP)
	make crom

# Generate the instruction memory VHDL table from an ELF file	
crom:
	-rm -rf vhdl/generated
	mkdir vhdl/generated
	-mkdir -p tmp
	bin/elf2vhdl tmp/$(APP) tmp/$(APP).bin
	java -cp java/lib/patmos-tools.jar \
		patmos.asm.Bin2Vhdl -s tmp -d vhdl/generated $(APP).bin

old_rom: tools
	-rm -rf vhdl/generated
	mkdir vhdl/generated
	java -cp java/lib/patmos-tools.jar$(S)lib/antlr-3.3-complete.jar \
		patmos.asm.PatAsm -s asm -d vhdl/generated $(APP).s

# ModelSim
sim:
	cd modelsim; make

# VHDL simulation in batch mode
bsim:
	cd modelsim; make batch

# High-level pasim simulation
hsim:
	bin/pasim --debug --debug-fmt=short tmp/$(APP).bin

# C simulation of the Chisel version of Patmos
csim:
	$(MAKE) -C chisel test APP=$(APP)

# Testing
test:
	testsuite/run.sh
test-vhdl:
	testsuite/run.sh vhdl
test-chsl:
	testsuite/run.sh chsl
.PHONY: test test-vhdl test-chsl

# Compile Patmos and download
patmos:
	make synth
	make config

# configure the FPGA
config:
ifeq ($(USB),true)
	make config_usb
else
ifeq ($(XFPGA),true)
	make config_xilinx
else
	make config_byteblaster
endif
endif

synth:
	make vsynth
	make csynth

# This is ugly, but I don't have Quartus under OSX
# and I don't have cmake/paasm under cygwin
# Tools in Java would be easier...

csynth:
	$(MAKE) -C chisel qsyn APP=$(APP) QPROJ=$(QPROJ)

vsynth:
	@echo $(QPROJ)
	for target in $(QPROJ); do \
		make qsyn -e QBT=$$target || exit; \
	done

#
#	Quartus build process
#		called by jopser, jopusb,...
#
qsyn:
	echo "building $(QBT)"
	-rm -rf quartus/$(QBT)/db
	-rm -f quartus/$(QBT)/patmos.sof
	-rm -f jbc/$(QBT).jbc
	-rm -f rbf/$(QBT).rbf
	quartus_map quartus/$(QBT)/patmos
	quartus_fit quartus/$(QBT)/patmos
	quartus_asm quartus/$(QBT)/patmos
	quartus_sta quartus/$(QBT)/patmos

config_byteblaster:
	cd quartus/$(QPROJ) && quartus_pgm -c $(BLASTER_TYPE) -m JTAG patmos.cdf

config_usb:
	cd rbf && ../$(USBRUNNER) $(QPROJ).rbf

download: 
	java -cp lib/*:java/classes/ patserdow.Main $(COM_PORT) $(APP)

# TODO: no Xilinx Makefiles available yet
config_xilinx:
	cd xilinx/$(XPROJ) && make config

clean:
	for ext in $(EXTENSIONS); do \
		find `ls` -name \*.$$ext -print -exec rm -r -f {} \; ; \
	done
	-find `ls` -name patmos.pof -print -exec rm -r -f {} \;
	-find `ls` -name db -print -exec rm -r -f {} \;
	-find `ls` -name incremental_db -print -exec rm -r -f {} \;
	-find `ls` -name patmos_description.txt -print -exec rm -r -f {} \;
	-rm -rf asm/generated
	-rm -f vhdl/*.vhd
	-rm -rf $(TOOLS)/dist
	-rm -rf $(PCTOOLS)/dist
	-rm -rf $(TARGET)/dist
	-rm -rf modelsim/work
	-rm -rf modelsim/transcript
	-rm -rf modelsim/gaisler
	-rm -rf modelsim/grlib
	-rm -rf modelsim/techmap
