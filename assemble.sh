# Warning: this script DELETES files. Run at your own risk.
asm6 clock.asm clock.nes
rm -f *.gz
gzip -k --best *.nes
