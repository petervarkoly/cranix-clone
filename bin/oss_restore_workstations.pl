#!/usr/bin/perl
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Data::Dumper;
use oss_utils;
use oss_base;
my $oss;
my $mesg;
my $room         = '*';
my $hw           = undef;
my $partitions   = 'all';
my @workstations = ();
my @rooms        = ();
my $MULTICAST    = 0;

sub get_partitions_of_hw
{
   my $hwconf  	  = shift;
   my @partitions = ();
   my $hw 	  = $oss->get_entry('configurationKey='.$hwconf.','.$oss->{SYSCONFIG}->{COMPUTERS_BASE});
   foreach ( @{$hw->{configurationvalue}} )
   {
      if( /^PART_(.*)_OS=/ )
      {
          push @partitions, $1; 
      }
   }
   return \@partitions;
}

sub write_host_pxe_config
{
   my $dn  	  = shift;
   my $partitions = shift || 'all' ;

   if( $partitions eq 'all' )
   {
       my $hw = $oss->get_config_value($dn,'HW');
       $partitions = join ',',@{get_partitions_of_hw($hw)};
   }
   my $mac     = $oss->get_attribute($dn,'dhcpHWAddress');
   $mac =~ s/ethernet //;
   $mac =~ s/:/-/g;
   $mac = "01-".lc($mac);
   my $pxeboot = get_file("/usr/share/oss/templates/pxeboot");
   $pxeboot =~ s/#PARTITIONS#/$partitions/;
   if( !$MULTICAST )
   {
       $pxeboot =~ s/ MULTICAST=1//;
   }    
   write_file('/srv/tftp/pxelinux.cfg/'.$mac,$pxeboot);
   my $eliloboo = get_file("/usr/share/oss/templates/eliloboot");
   $pxeboot =~ s/#PARTITIONS#/$partitions/;
   if( !$MULTICAST )
   {
       $pxeboot =~ s/ MULTICAST=1//;
   }    
   write_file('/srv/tftp/.cfg/'.uc($mac).'.conf',$pxeboot);
}

# Initialisierung
$oss = oss_base->new();

my $DEBUG               = 0;
if( $oss->get_school_config('SCHOOL_DEBUG') eq 'yes' )
{ 
  $DEBUG = 1;
}

open(OUT,">/tmp/get_workstation") if ($DEBUG);
while(<STDIN>)
{
	print OUT if ($DEBUG);
	# Clean up the line!
	chomp; s/^\s+//; s/\s+$//;
	my ( $key, $value ) = split / /,$_,2;

	if( $key eq 'room' )
	{
	      push @rooms,$value;
	}
	elsif ( $key eq 'hw' )
	{
	      $hw = $value;
	}
	elsif ( $key eq 'partitions' )
	{
	      $partitions = $value;
	}
	elsif ( $key eq 'multicast' )
	{
	      $MULTICAST = 1;
	}
	elsif ( $key eq 'workstation' )
	{
	      push @workstations,$value;
	}
}
close OUT if ($DEBUG);


#-----------------------------------------------------------------------------
if( !scalar @rooms && !scalar @workstations && ! defined  $hw )
{
	my $result = $oss->{LDAP}->search(  base    => $oss->{SYSCONFIG}->{DHCP_BASE},
                                    scope   => 'sub',
                                    filter  => "(&(description=*)(objectClass=schoolRoom))"
                           );
	foreach my $entry ( $result->entries )
	{
		my $ws = $oss->get_workstations($entry->dn);
		push @workstations , keys(%{$ws});
	}
}
else
{
	foreach my $room (@rooms)
	{
		if( ! /$oss->{SYSCONFIG}->{DHCP_BASE}/ )
		{
			my $result = $oss->{LDAP}->search(  base    => $oss->{SYSCONFIG}->{DHCP_BASE},
					    scope   => 'sub',
					    filter  => "(&(|(description=$room)(cn=$room))(objectClass=schoolRoom))"
				   );
			if( $result->code || ! $result->count )
			{
				next;
			}
			$room = $result->entry(0)->dn;
		}
		my $ws = $oss->get_workstations($room);
		push @workstations , keys(%{$ws});
	}
	if( defined  $hw )
	{
	    my $result = $oss->{LDAP}->search(  base    => $oss->{SYSCONFIG}->{DHCP_BASE},
                                    scope   => 'sub',
                                    filter  => "(&(Objectclass=SchoolWorkstation)(configurationValue=HW=$hw))"
                           );
	   
		foreach my $entry ( $result->entries )
		{
			push @workstations, $entry->dn;
		}
	}
}
foreach my $dn ( @workstations )
{
	write_host_pxe_config($dn,$partitions);
}

exit;
