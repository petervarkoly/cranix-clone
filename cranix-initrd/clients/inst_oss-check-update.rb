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
	else
		Popup.LongMessage("Bitte beachten Sie für die Migration: auch wenn der Prozeß sorgfältig getestet wurde, können wir keine Garantie für die Übernahme aller Daten übernehmen. " +
				"Der Migrations-Prozeß kann nur Daten übernehmen, die von einem richtig gepflegten und aktualisierten OSS 3 stammen.<br>" +
				"Daten von installierter Fremdsoftware oder OSS Daten, die von Fremdsoftware angepaßt und angereichert wurden, können ggf. nicht korrekt übernommen werden. " +
				"Wenn Sie in Ihrem OSS Fremdsoftware installiert haben, dann wird diese aller Voraussicht nach deinstalliert oder wird nicht mehr korrekt funktionieren.<br><br>" +
				"Aus Umstellung zur Active-Directory Server Kompatibilität und der daraus resultierenden Notwendigkeit der Eindeutigkeit von Objekt-Namen ergibt sich die Besonderheit, " +
				"dass bei Benutzer, Gruppen und Workstation-Accounts mit identischen Namen nur das Benutzerkonto migriert wird. " +
				"Die Dateien der Gruppe bleiben dann zwar erhalten, die Gruppe selbst wird jedoch nicht migriert. ")
	end
        :next
    end
  end
end

Yast::InstOssCheckUpdate.new.main

