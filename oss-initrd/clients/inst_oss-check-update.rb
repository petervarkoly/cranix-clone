# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2017 Dipl. Ing. Peter Varkoly, Nuernberg, Germany.
Yast.import 'Popup'
module Yast
  class InstOssCheckUpdate < Client
    def main
	if !File.exist?("/mnt/home/archiv/migrate-to-4-0/SAMBA/passdb.tdb")
                Popup.LongError("Das Script oss-prepare-migration.pl wurde nicht oder nicht erfolgreich ausgeführt. " +
                                "Sie können nicht mit der Migration fortfahren. " +
                                " Bitte starten Sie den alten OSS neu und führen Sie das Migrationscript aus oder kontaktieren Sie support@extis.de." +
                                "<br><br>" +
                                "The script oss-prepare-migration.pl was not executed or this was not succesfully.<br>" +
                                "You can not continue the migration. Restart the old OSS system an start the migration script or contact support@extis.de.<br>"
                                )
		return :abort
	end
        :next
    end
  end
end

Yast::InstOssCheckUpdate.new.main

