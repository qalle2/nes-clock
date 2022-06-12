# Warning: this script DELETES files. Run at your own risk.
rm -f *.bin *.gz
python3 ../nes-util/nes_chr_encode.py chr.png chr.bin
asm6 clock.asm clock.nes
gzip -k --best *.bin *.nes
