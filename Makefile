.PHONY: all

MIRROR="http://gaming.jhu.edu/mirror/archlinux/"
PKGBUILDS=PKGBUILDS/rxvt-unicode-better-wheel-scrolling/PKGBUILD PKGBUILDS/jhux-install-scripts/PKGBUILD PKGBUILDS/live-system-openbox/PKGBUILD
ISO_LABEL="JH_UX"
ISO_FILE="jhux.iso"
REPO:=$(shell pwd)/repo
pkgbuilddir=$(shell dirname $(pkgbuild))
pkgbuildage=$(shell stat -c '%Y' $(pkgbuild))
packageage=$(shell stat -c '%Y' "packages")
fileage=$(shell stat -c '%Y' $(file))
dbage=$(shell stat -c '%Y' $(REPO)/archiso.db.tar.gz)

all: iso

iso: fs
	cp /usr/lib/initcpio/hooks/archiso work/root-image/usr/lib/initcpio/hooks
	cp /usr/lib/initcpio/install/archiso work/root-image/usr/lib/initcpio/install
	install -Dm 644 filesystem/mkinitcpio-archiso.conf work/root-image/etc/
	install -d work/root-image/boot/x86_64
	mkarchiso -C pacman.conf -r "mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/x86_64/archiso.img" run
	install -d work/iso/arch/boot/x86_64
	mv work/root-image/boot/vmlinuz-linux work/iso/arch/boot/x86_64/vmlinuz
	mv work/root-image/boot/x86_64/archiso.img work/iso/arch/boot/x86_64/archiso.img
	install -d work/iso/arch/boot/syslinux
	sed s/ISO_LABEL/$(ISO_LABEL)/ filesytem/syslinux.cfg.in > work/iso/arch/boot/syslinux/syslinux.cfg
	cp work/root-image/usr/lib/syslinux/menu.c32 work/iso/arch/boot/syslinux/
	install -d work/iso/isolinux
	cp work/root-image/usr/lib/syslinux/isolinux.bin work/iso/isolinux/
	cp work/root-image/usr/lib/syslinux/isohdpfx.bin work/iso/isolinux/
	install -Dm 644 filesystem/isolinux.cfg work/iso/isolinux/isolinux.cfg
	install -Dm 644 fileystem/aitab work/iso/arch/aitab
	if [ -f out/$(ISO_FILE) ]; then \
		rm out/$(ISO_FILE); \
	fi
	mkarchiso -C pacman.conf prepare
	mkarchiso -C pacman.conf -L $(ISO_NAME) iso $(ISO_FILE)
	@touch iso

fs: packagelist.txt installerpackages.txt packages
	cp /etc/pacman.conf .
	printf "\n[archiso]\nServer = file://$(REPO)\n" >> pacman.conf
	false
	if [ -d work ]; then \
		rm -r work; \
	fi
	mkarchiso -C pacman.conf init
	$(foreach pkg, $(shell cat packagelist.txt installerpackages.txt),\
		mkarchiso -C pacman.conf -p $(pkg) install; \
	)
	echo "Server = $(MIRROR)\$$\repo/os/\$$arch" >> work/root-image/etc/pacman.d/mirrorlist
	printf "\n[archiso]\nServer = file:///usr/share/jhux-installer/repo\n" >> work/root-image/etc/pacman.conf
	cp packagelist.txt work/root-image/usr/share/jhux-installer
	cp -R repo work/root-image/usr/share/jhux-installer/
	@touch fs

packages: $(PKGBUILDS)
	if [ ! -d $(REPO) ]; then \
		mkdir $(REPO); \
	fi
	$(foreach pkgbuild, $(PKGBUILDS), \
		cd $(pkgbuilddir); \
		if [ ! -f ../../packages ]; then \
			PKGDEST=$(REPO) makepkg -f; \
		elif [[ $(pkgbuildage) -gt $(packageage) ]]; then \
			PKGDEST=$(REPO) makepkg -f; \
		fi ; \
		cd ../.. ; \
	)
	if [ -f ${REPO}/archiso.db.tar.gz ]; then \
		$(foreach file, $(shell ls ${REPO}/*.pkg.tar.xz), \
			if [ $(fileage) -gt $(dbage) ]; then \
				repo-add ${REPO}/archiso.db.tar.gz ${file} || true; \
			fi; \
		) \
	else \
		repo-add ${REPO}/archiso.db.tar.gz ${REPO}/*.pkg.tar.xz; \
	fi
	@touch packages

packages-force:
	if [ ! -d $(REPO) ]; then \
		mkdir $(REPO); \
	fi
	$(foreach pkgbuild, $(PKGBUILDS), \
		cd $(pkgbuilddir); \
		PKGDEST=$(REPO) makepkg -f; \
		cd ../.. ; \
	)
	if [ -f ${REPO}/archiso.db.tar.gz ]; then \
		$(foreach file, $(shell ls ${REPO}/*.pkg.tar.xz), \
			if [ $(fileage) -gt $(dbage) ]; then \
				repo-add ${REPO}/archiso.db.tar.gz ${file} || true; \
			fi; \
		) \
	else \
		repo-add ${REPO}/archiso.db.tar.gz ${REPO}/*.pkg.tar.xz; \
	fi
	@touch packages
