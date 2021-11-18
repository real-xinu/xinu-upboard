cp xinu.elf isodir/boot/
grub-mkrescue -d /usr/lib/grub/x86_64-efi -o xinu.iso isodir
