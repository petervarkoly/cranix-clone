DESTDIR         = /
DATE            = $(shell date "+%Y%m%d")
XMLFILES        = $(shell cd xml; ls *.templ)
INSTUSER	= 

install:
	#configure ftp service
	mkdir -p $(DESTDIR)/etc/xinetd.d
	mkdir -p $(DESTDIR)/srv/www/htdocs
	mkdir -p $(DESTDIR)/srv/ftp/akt/CD{1,2,3,4,5,6}
	mkdir -p $(DESTDIR)/srv/ftp/xml
	mkdir -p $(DESTDIR)/usr/share/oss/templates
	install -m 444 $(INSTUSER)  config/vsftpd.conf.in        $(DESTDIR)/etc/vsftpd.conf.in
	install -m 444 $(INSTUSER)  config/xinetd.d.vsftpd.in    $(DESTDIR)/etc/xinetd.d/vsftpd.in
	install -m 444 $(INSTUSER)  config/pxeboot.in            $(DESTDIR)/usr/share/oss/templates/pxeboot.in

	#configure tftp service
	mkdir -p $(DESTDIR)/srv/tftp/{clone,boot,pxelinux.cfg}
	install -m 444 $(INSTUSER)  config/xinetd.d.tftp.in       $(DESTDIR)/etc/xinetd.d/tftp.in
	install -m 444 $(INSTUSER)  tftp/german.kbd               $(DESTDIR)/srv/tftp/
	install -m 444 $(INSTUSER)  tftp/linuxrc.config*          $(DESTDIR)/srv/tftp/
	install -m 444 $(INSTUSER)  tftp/bootlogo                 $(DESTDIR)/srv/tftp/bootlogo
	install -m 444 $(INSTUSER)  tftp/chain.c32                $(DESTDIR)/srv/tftp/chain.c32
	install -m 444 $(INSTUSER)  tftp/clouds.jpg               $(DESTDIR)/srv/tftp/clouds.jpg
	install -m 444 $(INSTUSER)  tftp/font.fnt                 $(DESTDIR)/srv/tftp/font.fnt
	install -m 444 $(INSTUSER)  tftp/german.kbd               $(DESTDIR)/srv/tftp/german.kbd
	install -m 444 $(INSTUSER)  tftp/gfxboot.c32              $(DESTDIR)/srv/tftp/gfxboot.c32
	install -m 444 $(INSTUSER)  tftp/menu.c32                 $(DESTDIR)/srv/tftp/menu.c32
	install -m 444 $(INSTUSER)  tftp/pxelinux.0               $(DESTDIR)/srv/tftp/pxelinux.0  
	install -m 444 $(INSTUSER)  tftp/pxelinux.cfg/autoyast.in $(DESTDIR)/srv/tftp/pxelinux.cfg/autoyast.in
	install -m 444 $(INSTUSER)  tftp/pxelinux.cfg/autoyast64.in $(DESTDIR)/srv/tftp/pxelinux.cfg/autoyast64.in
	install -m 444 $(INSTUSER)  tftp/pxelinux.cfg/default.in  $(DESTDIR)/srv/tftp/pxelinux.cfg/default.in
	install -m 444 $(INSTUSER)  tftp/boot/*			  $(DESTDIR)/srv/tftp/boot/
	install -m 444 $(INSTUSER)  tftp/clone/*		  $(DESTDIR)/srv/tftp/clone/
	#configure itool service
	mkdir -p -m 2750 $(DESTDIR)/srv/itool/config
	mkdir -p -m 2770 $(DESTDIR)/srv/itool/images/manual
	mkdir -p -m 2770 $(DESTDIR)/srv/itool/hwinfo
	mkdir -p -m 2775 $(DESTDIR)/srv/itool/ROOT/root

	install -m 444 config/*templ           $(DESTDIR)/srv/itool/config
	install -m 444 config/*bat             $(DESTDIR)/srv/itool/config
	install -m 400 config/clonetool.id_rsa $(DESTDIR)/srv/itool/config

	#configure autoyast2 enviroment
	(cd xml; \
	   install -m 644 $(INSTUSER) $(XMLFILES) $(DESTDIR)/srv/ftp/xml/ \
	)
	#configure some executables
	mkdir -p $(DESTDIR)/usr/sbin
	install -m 755 $(INSTUSER) bin/*           $(DESTDIR)/usr/sbin/


