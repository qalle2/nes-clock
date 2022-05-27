# Warning: this script DELETES files. Run at your own risk.
rm -f *.gz *.nes
asm6 clock.asm clock.nes
python3 hexdump.py > hexdump.txt
gzip -k --best clock.nes
