HERE            = $(shell pwd)
PACKAGE         = cranix-clone
DESTDIR         = /
DATE            = $(shell date "+%Y%m%d")
INSTUSER	= 
REPO		= /home/OSC/home:varkoly:CRANIX-4-2/

install:
	#configure tftp boot template service
	mkdir -p $(DESTDIR)/usr/share/cranix/templates
	install -m 444 $(INSTUSER)  config/pxeboot.in            $(DESTDIR)/usr/share/cranix/templates/pxeboot.in
	install -m 444 $(INSTUSER)  config/efiboot.in            $(DESTDIR)/usr/share/cranix/templates/efiboot.in

	#configure tftp service
	mkdir -p       $(DESTDIR)/srv/tftp/{clone,boot,pxelinux.cfg}
	install -m 444 $(INSTUSER)  tftp/german.kbd               $(DESTDIR)/srv/tftp/
	install -m 444 $(INSTUSER)  tftp/linuxrc.config*          $(DESTDIR)/srv/tftp/
	install -m 444 $(INSTUSER)  tftp/bootlogo                 $(DESTDIR)/srv/tftp/bootlogo
	install -m 444 $(INSTUSER)  tftp/bootmenu                 $(DESTDIR)/srv/tftp/bootmenu
	install -m 444 $(INSTUSER)  tftp/chain.c32                $(DESTDIR)/srv/tftp/chain.c32
	install -m 444 $(INSTUSER)  tftp/clouds.jpg               $(DESTDIR)/srv/tftp/clouds.jpg
	install -m 444 $(INSTUSER)  tftp/font.fnt                 $(DESTDIR)/srv/tftp/font.fnt
	install -m 444 $(INSTUSER)  tftp/german.kbd               $(DESTDIR)/srv/tftp/german.kbd
	install -m 444 $(INSTUSER)  tftp/gfxboot.c32              $(DESTDIR)/srv/tftp/gfxboot.c32
	install -m 444 $(INSTUSER)  tftp/menu.c32                 $(DESTDIR)/srv/tftp/menu.c32
	install -m 444 $(INSTUSER)  tftp/pxelinux.0               $(DESTDIR)/srv/tftp/pxelinux.0
	install -m 444 $(INSTUSER)  tftp/linuxrc.config*          $(DESTDIR)/srv/tftp/
	install -m 444 $(INSTUSER)  tftp/pxelinux.cfg/default.in  $(DESTDIR)/srv/tftp/pxelinux.cfg/default.in
	rsync -aAv tftp/efi/                                       $(DESTDIR)/srv/tftp/efi/

	#Install the kernel and initrd from installation-images-OSS or from the local provided clone directory
	if [ -d clone ];  then \
		cp clone/* $(DESTDIR)/srv/tftp/clone/; \
	else \
		install -m 444 $(INSTUSER)  /SuSE/OSS/CD1/boot/x86_64/loader/initrd  $(DESTDIR)/srv/tftp/clone/; \
		install -m 444 $(INSTUSER)  /CD1/boot/x86_64/loader/linux            $(DESTDIR)/srv/tftp/clone/; \
	fi
	#configure itool service
	mkdir -p -m 2750 $(DESTDIR)/srv/itool/config
	mkdir -p -m 2770 $(DESTDIR)/srv/itool/images/manual
	mkdir -p -m 2770 $(DESTDIR)/srv/itool/hwinfo
	mkdir -p -m 2775 $(DESTDIR)/srv/itool/ROOT/root
	
	mkdir -p $(DESTDIR)/etc/xinetd.d/
	mkdir -p $(DESTDIR)/srv/itool/config
	mkdir -p $(DESTDIR)/srv/ftp/itool/scripts
	install -m 444 $(INSTUSER) config/xinetd.d.tftp.in $(DESTDIR)/etc/xinetd.d/tftp.in
	install -m 444 $(INSTUSER) config/*templ           $(DESTDIR)/srv/itool/config
	install -m 400 $(INSTUSER) config/clonetool.id_rsa $(DESTDIR)/srv/itool/config
	install -m 755 $(INSTUSER) scripts/*               $(DESTDIR)/srv/ftp/itool/scripts
	
	#copy windows cleanup script 
	install -m 755 $(INSTUSER) Win10_clean.ps1 $(DESTDIR)/home/software/oss/
	#configure some executables
	mkdir -p $(DESTDIR)/usr/sbin
	install -m 755 $(INSTUSER) bin/*           $(DESTDIR)/usr/sbin/

cranix-initrd:
	cd cranix-initrd; tar cjf ../cranix-initrd.tar.bz2 *;
	for i in $(OSCDIRS); do \
	   if [ -d $$i/installation-images ]; then \
	      cd $$i/installation-images; osc up; cd $(HERE); \
	      cp cranix-initrd.tar.bz2 $$i; \
	      cd $$i/installation-images; \
	      osc vc; \
	      osc ci -m "New Build Version"; \
	   fi; \
	done 

dist:
	if [ -e $(PACKAGE) ]; then rm -rf $(PACKAGE); fi
	mkdir $(PACKAGE)
	cp -rp Makefile bin config scripts tftp $(PACKAGE)
	sed -i "s/@DATE@/$(DATE)/"       $(PACKAGE)/scripts/clone.sh
	if [ -d clone ]; then cp -rp clone $(PACKAGE) ; fi
	tar jcpf $(PACKAGE).tar.bz2 $(PACKAGE)
	xterm -e git log --raw &
	if [ -d $(REPO)/$(PACKAGE) ] ; then \
            cd $(REPO)/$(PACKAGE); osc up; cd $(HERE);\
            mv $(PACKAGE).tar.bz2 $(REPO)/$(PACKAGE); \
            cd $(REPO)/$(PACKAGE); \
            osc vc; \
            osc ci -m "New Build Version"; \
        fi
	rm -rf $(PACKAGE)

