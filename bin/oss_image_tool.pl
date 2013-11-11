#!/usr/bin/perl
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use POSIX;
use oss_base;
use oss_utils;

#Parse parameter
my $ip   = shift;
my $auto = shift;

if( defined $auto && $auto !~ /AUTO=\d/ )
{
  die "Not allowed auto format";
}

#Global Variable
my $DEBUG  = 0;
my $dn     = '';
my $HW     = '';
my $SW     = '';

my $OSConf = {
		WinNT => {
				TargetPath => '\WINNT',
				DistFolder => 'C:\\sysprep\\i386',
				DistShare  => 'win2000dist'

			 },
		Win2k => {
				TargetPath => '\WINNT',
				DistFolder => 'C:\\sysprep\\i386',
				DistShare  => 'win2000dist'
			 },
		WinXP => {
				TargetPath => '\WINNT',
				DistFolder => 'C:\\sysprep\\i386',
				DistShare  => 'win2000dist'
			 }
	    };


# Make LDAP Connection
my $oss = oss_base->new();

$dn            = $oss->get_workstation($ip);
my $hwaddress  = $oss->get_attribute($dn,'dhcpHWAddress');
$hwaddress =~ s/ethernet //;
$hwaddress =  uc($hwaddress);
$hwaddress =~ tr/:/-/;

# Get my own configuration
my $SW       = $oss->get_config_value('SW',$dn);
my $HW       = $oss->get_config_value('HW',$dn);
my $MASTER   = $oss->get_config_value('MASTER',$dn) || 'no';
my %HDS      = ( 'ATA'    => '/dev/hda',
		 'SATA'   => '/dev/sda',
		 'SCSI'   => '/dev/sda'
		);


#Get the software configuration of the room if neccessary
if( ! $SW )
{
  $SW  = $oss->get_config_value('SW',get_parent_dn($dn));
}
my $name          = get_name_of_dn($dn);
if( ! $SW )
{
  print "No software configuration for $name\n";
  exit;
}

my $o             = $oss->get_attribute('uid=admin,'.$oss->{SYSCONFIG}->{USER_BASE},'o');
my $OS            = $oss->get_computer_config_value('OS',$SW)   || 'WinXP' ;
my $JOIN          = $oss->get_computer_config_value('JOIN',$SW) || 'Domain' ;
# we calculate the count of sectors (512 Bytes)
my $SZ_SWAP_PART  = $oss->get_computer_config_value('SZ_SWAP_PART',$HW)  * 2 * 1024        || -1;
my $SZ_SYS_PART   = $oss->get_computer_config_value('SZ_SYS_PART',$HW)   * 2 * 1024 * 1024 || -1;
my $SZ_CACHE_PART = $oss->get_computer_config_value('SZ_CACHE_PART',$HW) * 2 * 1024 * 1024 || -1;

my $HD            = $HDS{$oss->get_computer_config_value('Harddisk',$HW)};
my $imDN          = $oss->get_image($HW,$SW);
if( ! $imDN )
{
  print "No image for $name\n";
  exit;
}
my $PATH          = "$HW/$SW";
my $READONLY      = $oss->get_config_value('READONLY',$imDN) || 'no';
my $Monitor       = $oss->get_computer_config_value('Monitor',$HW);
$Monitor          =~ /.*:([0-9]+)X([0-9]+)@([0-9]+)HZ/;

my $XResolution = $1;
my $YResolution = $2;
my $Vrefresh    = $3;
#print "$HW,$SW,$imDN"; exit;

my $sysprep = ";SetupMgrTag
[Unattended]
    OemSkipEula=Yes
    InstallFilesPath=C:\\sysprep\\i386

[GuiUnattended]
    AdminPassword=*
    OEMSkipRegional=1
    TimeZone=110
    OemSkipWelcome=1

[UserData]
    FullName=\"$o\"
    OrgName=\"$o\"
    ComputerName=$name
    ProductID=".$oss->get_computer_config_value('ProductID',$SW)."

[Display]
    BitsPerPel=32
    XResolution=$XResolution
    YResolution=$YResolution
    Vrefresh=$Vrefresh

[TapiLocation]
    CountryCode=49

[RegionalSettings]
    LanguageGroup=1
    Language=00000407
";

if( $JOIN eq 'Domain' )
{
$sysprep .= "
[Identification]
    JoinDomain=".$oss->{SYSCONFIG}->{SCHOOL_WORKGROUP}."
    DomainAdmin=register
    DomainAdminPassword=register
";
}
else
{
$sysprep .= "
[Identification]
    JoinWorkgroup=".$oss->{SYSCONFIG}->{SCHOOL_WORKGROUP}."
";
}

$sysprep .= "
[Networking]
    InstallDefaultComponents=Yes

[Proxy]
    Proxy_Enable=1
    Use_Same_Proxy=1

[URL]
    AutoConfig=1
    AutoConfigJSURL=http://admin/proxy.pac
";

#Make sysprep windows readable
$sysprep =~ s/\n/\r\n/mg;

write_file('/srv/itool/config/'.$hwaddress.'.inf',$sysprep);

my $conf = "MASTER;IMAGE;HD;SZ_CACHE_PART;SZ_SYS_PART;SZ_SWAP_PART;READONLY;OS
$MASTER;$PATH;$HD;$SZ_CACHE_PART;$SZ_SYS_PART;$SZ_SWAP_PART;$READONLY;$OS";

write_file('/srv/itool/config/'.$hwaddress.'_conf.csv',$conf);

if( defined $auto )
{
  $conf = "default		itool
timeout		5

LABEL itool
    kernel itool/linux.krn
    append initrd=itool/initrd ramdisk_size=8192 root=/dev/ram0 FTP=install $auto 
";

 write_file('/srv/tftp/pxelinux.cfg/01-'.$hwaddress.'_conf.csv',$conf);
  
}

print "Succesfull written configuration for $name\n";

