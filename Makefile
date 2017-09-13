VERSION         = $(shell cat VERSION)
RELEASE         = $(shell cat RELEASE)
NRELEASE        = $(shell echo $(RELEASE) + 1 | bc )
HERE            = $(shell pwd)
PACKAGE         = oss-clone
DESTDIR         = /
DATE            = $(shell date "+%Y%m%d")
INSTUSER	= 
OSCDIRS		= /home/OSC/home:varkoly:OSS-4-0:openleap-42-3/installation-images/

install:
	#configure tftp boot template service
	mkdir -p $(DESTDIR)/usr/share/oss/templates
	install -m 444 $(INSTUSER)  config/pxeboot.in            $(DESTDIR)/usr/share/oss/templates/pxeboot.in
	install -m 444 $(INSTUSER)  config/eliloboot.in          $(DESTDIR)/usr/share/oss/templates/eliloboot.in

	#configure tftp service
	mkdir -p $(DESTDIR)/srv/tftp/{clone,boot,pxelinux.cfg}
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
	install -m 444 $(INSTUSER)  tftp/elilo*                   $(DESTDIR)/srv/tftp/
	install -m 444 $(INSTUSER)  tftp/boot/*			  $(DESTDIR)/srv/tftp/boot/
	install -m 444 $(INSTUSER)  tftp/clone/*		  $(DESTDIR)/srv/tftp/clone/
	install -m 444 $(INSTUSER)  tftp/pxelinux.cfg/default.in  $(DESTDIR)/srv/tftp/pxelinux.cfg/default.in
	
	#configure itool service
	mkdir -p -m 2750 $(DESTDIR)/srv/itool/config
	mkdir -p -m 2770 $(DESTDIR)/srv/itool/images/manual
	mkdir -p -m 2770 $(DESTDIR)/srv/itool/hwinfo
	mkdir -p -m 2775 $(DESTDIR)/srv/itool/ROOT/root
	
	mkdir -p $(DESTDIR)/etc/xinetd.d/
	mkdir -p $(DESTDIR)/srv/itool/config/
	install -m 444 $(INSTUSER) config/xinetd.d.tftp.in $(DESTDIR)/etc/xinetd.d/tftp.in
	install -m 444 $(INSTUSER) config/*templ           $(DESTDIR)/srv/itool/config
	install -m 444 $(INSTUSER) config/*bat             $(DESTDIR)/srv/itool/config
	install -m 444 $(INSTUSER) config/*ps1             $(DESTDIR)/srv/itool/config
	install -m 644 $(INSTUSER) config/*sh              $(DESTDIR)/srv/itool/config
	install -m 400 $(INSTUSER) config/clonetool.id_rsa $(DESTDIR)/srv/itool/config
	
	#configure some executables
	mkdir -p $(DESTDIR)/usr/sbin
	install -m 755 $(INSTUSER) bin/*           $(DESTDIR)/usr/sbin/

oss-initrd:
	cd oss-initrd; tar cjf ../oss-initrd.tar.bz2 *;
	for i in $(OSCDIRS); do \
	   if [ -d $$i ]; then \
	      cd $$i; osc up; cd $(HERE); \
	      cp oss-initrd.tar.bz2 $$i; \
	      cd $$i; \
	      osc vc; \
	      osc ci -m "New Build Version"; \
	   fi; \
	done 

dist:
	if [ -e $(PACKAGE) ]; then rm -rf $(PACKAGE); fi
	mkdir $(PACKAGE)
	cp -rp Makefile bin config tftp $(PACKAGE)
	tar jcpf $(PACKAGE).tar.bz2 $(PACKAGE)
	sed "s/@VERSION@/$(VERSION)/" $(PACKAGE).spec.in > $(PACKAGE).spec
	sed -i "s/@RELEASE@/$(NRELEASE)/"  $(PACKAGE).spec
	if [ -d /data1/OSC/home\:openschoolserver/$(PACKAGE) ] ; then \
	        cd /data1/OSC/home\:openschoolserver/$(PACKAGE); osc up; cd $(HERE);\
	        cp $(PACKAGE).tar.bz2  $(PACKAGE).spec /data1/OSC/home\:openschoolserver/$(PACKAGE); \
	        cd /data1/OSC/home\:openschoolserver/$(PACKAGE); \
	        osc vc; \
		osc addremove; \
	        osc ci -m "New Build Version"; \
	fi 
	echo $(NRELEASE) > RELEASE
	git commit -a -m "New release"
	git push
	rm -rf $(PACKAGE)


