HERE            = $(shell pwd)
PACKAGE         = cranix-clone
DESTDIR         = /
DATE            = $(shell date "+%Y%m%d")
INSTUSER	=
REPO		= ~/OSC/home:pvarkoly:CRANIX/

install:
	#configure tftp boot template service
	mkdir -p $(DESTDIR)/usr/share/cranix/templates
	install -m 444 $(INSTUSER)  config/pxeboot.in            $(DESTDIR)/usr/share/cranix/templates/pxeboot.in
	install -m 444 $(INSTUSER)  config/efiboot.in            $(DESTDIR)/usr/share/cranix/templates/efiboot.in
	#copy windows cleanup script
	install -m 755 $(INSTUSER)  config/Win10_clean.ps1       $(DESTDIR)/usr/share/cranix/templates/

	#configure tftp service
	mkdir -p       $(DESTDIR)/srv/tftp/{boot,pxelinux.cfg}
	rsync -aAv tftp/ $(DESTDIR)/srv/tftp/

	#configure itool service
	mkdir -p -m 2750 $(DESTDIR)/srv/itool/config
	mkdir -p -m 2770 $(DESTDIR)/srv/itool/images/manual
	mkdir -p -m 2770 $(DESTDIR)/srv/itool/hwinfo
	mkdir -p -m 2775 $(DESTDIR)/srv/itool/ROOT/root
	mkdir -p -m 2775 $(DESTDIR)/srv/ftp/boot/

	mkdir -p $(DESTDIR)/etc/xinetd.d/
	mkdir -p $(DESTDIR)/srv/itool/config
	mkdir -p $(DESTDIR)/srv/ftp/itool/scripts
	install -m 444 $(INSTUSER) config/xinetd.d.tftp.in $(DESTDIR)/etc/xinetd.d/tftp.in
	install -m 444 $(INSTUSER) config/*templ           $(DESTDIR)/srv/itool/config
	install -m 400 $(INSTUSER) config/clonetool.id_rsa $(DESTDIR)/srv/itool/config
	install -m 755 $(INSTUSER) scripts/*               $(DESTDIR)/srv/ftp/itool/scripts
	
	#configure some executables
	mkdir -p $(DESTDIR)/usr/sbin
	install -m 755 $(INSTUSER) bin/*           $(DESTDIR)/usr/sbin/

dist:
	if [ -e $(PACKAGE) ]; then rm -rf $(PACKAGE); fi
	mkdir $(PACKAGE)
	cp -rp Makefile bin config scripts tftp $(PACKAGE)
	sed -i "s/#DATE#/$(DATE)/"       $(PACKAGE)/scripts/login
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

