package Net::Connection;

use 5.006;
use strict;
use warnings;
use Net::DNS;

=head1 NAME

Net::Connection - Represents a network connection as a object.

=head1 VERSION

Version 0.0.0

=cut

our $VERSION = '0.0.0';


=head1 SYNOPSIS

=head1 Methods

=head2 new

This initiates a new connection object.

One argument is taken is taken 

    local_host
    local_port
    foreign_host
    foreign_port
    proto
    state

=head3 keys

=head4 foreign_host

The local host of the connection.

This can either be a IP or hostname. Max utility is achieved via a
IP though as that allows PTR lookup to be done.

If appears to be a hostname, it is copied to local_ptr and even
if asked to resolve PTRs it won't attempt to.

=head4 foreign_port

This is the foreign port of the connection.

For best utility, using numeric here is best.

If ports is true it will attempt to resolve it,
including reverse resolving if it is a port name instead.

If ports is false or not set and this value is
non-numeric, it will be copied to foreign_port_name.

=head4 foreign_port_name

This is the name of foreign port, if one exists in the
service records.

=head4 foreign_ptr

This is the PTR address for foreign_host.

If ptrs is not true and foreign_host appears to be
a hostname, then it is set to the same as foreign_host.

=head4 local_port

This is the local port of the connection.

For best utility, using numeric here is best.

If ports is true it will attempt to resolve it,
including reverse resolving if it is a port name instead.

If ports is false or not set and this value is
non-numeric, it will be copied to local_port_name.

=head4 local_port_name

This is the name of local port, if one exists in the
service records.

=head4 local_ptr

This is the PTR address for local_host.

If ptrs is not true and local_host appears to be
a hostname, then it is set to the same as local_host.

=head4 pid

This is the pid for a connection.

If defined, it needs to be numeric.

=head4 ports

If true, it will attempt to resolve the port names.

=head4 proto

This is the protocol type.

This needs to be defined, but unfortunately no real checking is done
as of currently as various OSes uses varrying capitalizations and slightly
different forms of TCP, TCP4, tcp4, tcpv4, and the like.

=head4 ptrs

If is true, then 

=head4 recvq

This is the recieve queue size.

If set, it must be numeric.

=head4 sendq

This is the send queue size.

If set, it must be numeric.

=head4 state

This is the current state of the connection.

This needs to be defined, but unfortunately no real checking is
done as of currently as there are minor naming differences between
OSes as well as some including states that are not found in others.

=head4 uid

The UID is the of the user the has the connection open.

This must be numeric.

If uid_resolve is set to true then the UID will be resolved
and stored in username.

If this is not defined, uid_resolve is true, and username is defined
then it will attempt to resolve the UID from the username.

=head4 uid_resolve

If set to true and uid is given, then a attempt will be made to
resolve the UID to a username.

=head4 username

This is the username for a connection.

If uid_resolve is true and uid is defined, then this
will attempt to be automatically contemplated.

If uid_resolve is true and uid is defined, then this
will attempt to be automatically contemplated.

=cut

sub new{
	my %args;
	if(defined($_[1])){
		%args= %{$_[1]};
	};

	# make sure we got the required bits
	if (
		(!defined( $args{'foreign_host'}) ) ||
		(!defined( $args{'local_host'}) ) ||
		(!defined( $args{'foreign_port'}) ) ||
		(!defined( $args{'local_port'}) ) ||
		(!defined( $args{'state'}) ) ||
		(!defined( $args{'proto'}) )
		){
		die "One or more of the required arguments is not defined";
	}

	# PID must be numeric if given
	if (
		defined( $args{'pid'} ) &&
		( $args{'pid'} !~ /^[0-9]+$/ )
		){
		die '$args{"pid"} is not numeric';
	}

	# UID must be numeric if given
	if (
		defined( $args{'uid'} ) &&
		( $args{'uid'} !~ /^[0-9]+$/ )
		){
		die '$args{"uid"} is not numeric';
	}

	# set the sendq/recvq and make sure they are numeric if given
	if (
		defined( $args{'sendq'} ) &&
		( $args{'sendq'} !~ /^[0-9]+$/ )
		){
		die '$args{"sendq"} is not numeric';
	}
	if (
		defined( $args{'recvq'} ) &&
		( $args{'recvq'} !~ /^[0-9]+$/ )
		){
		die '$args{"recvq"} is not numeric';
	}

	my $self={
			  'foreign_host' => $args{'foreign_host'},
			  'local_host' => $args{'local_host'},
			  'foreign_port' => $args{'foreign_port'},
			  'foreign_port_name' => $args{'foreign_port_name'},
			  'local_port' => $args{'local_port'},
			  'local_port_name' => $args{'local_port_name'},
			  'sendq' => undef,
			  'recvq' => undef,
			  'pid' => undef,
			  'uid' => undef,
			  'state' => $args{'state'},
			  'proto' => $args{'proto'},
			  'local_ptr' => undef,
			  'foreign_ptr' => undef,
			  };

	# Set these if defined
	if (defined( $args{'sendq'} )){
		$self->{'sendq'}=$args{'sendq'};
	}
	if (defined( $args{'recvq'} )){
		$self->{'recvq'}=$args{'recvq'};
	}
	if (defined( $args{'local_ptr'} )){
		$self->{'local_ptr'}=$args{'local_ptr'};
	}
	if (defined( $args{'foreign_ptr'} )){
		$self->{'foreign_ptr'}=$args{'foreign_ptr'};
	}
	if (defined( $args{'uid'} )){
		$self->{'uid'}=$args{'uid'};
	}
	if (defined( $args{'pid'} )){
		$self->{'pid'}=$args{'pid'};
	}
	if (defined( $args{'username'} )){
		$self->{'username'}=$args{'username'};
	}

	# resolve port names if asked to
	if ( $args{ports} ){
		# If the port is non-numeric, set the name and attempt to resolve it.
		if ( $self->{'local_port'} =~ /[A-Za-z]/ ){
			$self->{'local_port_name'}=$self->{'local_port'};
			my $service=getservbyname($self->{'local_port_name'}, undef);
			if (defined( $service )){
				$self->{'local_port'}=$service;
			}
		}
		if ( $self->{'foreign_port'} =~ /[A-Za-z]/	){
			$self->{'foreign_port_name'}=$self->{'foreign_port'};
			my $service=getservbyname($self->{'foreign_port_name'}, undef);
			if (defined( $service )){
				$self->{'foreign_port'}=$service;
			}
		}
	}else{
		# If the port is non-numeric, set it as the port name
		if ( $self->{'local_port'} =~ /[A-Za-z]/ ){
			$self->{'local_port_name'}=$self->{'local_port'};
		}
		if ( $self->{'foreign_port'} =~ /[A-Za-z]/	){
			$self->{'foreign_port_name'}=$self->{'foreign_port'};
		}
	}

	my $dns=Net::DNS::Resolver->new;

	# resolve PTRs if asked to
	if (
		defined( $args{ptrs} ) &&
		$args{ptrs}
		){
		# process foreign_host
		if (
			( $self->{'foreign_host'} =~ /[A-Za-z]/ ) &&
			( $self->{'foreign_host'} !~ /\:/ )
			){
			# appears to be a hostname already
			$self->{'foreign_ptr'}=$self->{'foreign_host'};
		}else{
			# attempt to resolve it
			eval{
				my $answer=$dns->search( $self->{'foreign_host'} );
				if ( defined( $answer->{answer}[0] ) &&
					 ( ref( $answer->{answer}[0] ) eq 'Net::DNS::RR::PTR' )
					){
					$self->{'foreign_ptr'}=lc($answer->{answer}[0]->ptrdname);
				}
			}
		}
		# process local_host
		if (
			( $self->{'local_host'} =~ /[A-Za-z]/ ) &&
			( $self->{'local_host'} !~ /\:/ )
			){
			# appears to be a hostname already
			$self->{'local_ptr'}=$self->{'local_host'};
		}else{
			# attempt to resolve it
			eval{
				my $answer=$dns->search( $self->{'local_host'} );
				if ( defined( $answer->{answer}[0] ) &&
					 ( ref( $answer->{answer}[0] ) eq 'Net::DNS::RR::PTR' )
					){
					$self->{'local_ptr'}=lc($answer->{answer}[0]->ptrdname);
				}
			}
		}
	}else{
		# We are not doing auto PTR resolving...
		# just set them if it appears to be a hostname
		if (
			( $self->{'foreign_host'} =~ /[A-Za-z]/ ) &&
			( $self->{'foreign_host'} !~ /\:/ )
			){
			$self->{'foreign_ptr'}=$self->{'foreign_host'};
		}
		if (
			( $self->{'local_host'} =~ /[A-Za-z]/ ) &&
			( $self->{'local_host'} !~ /\:/ )
			){
			$self->{'local_ptr'}=$self->{'local_host'};
		}
	}

	# resolve the UID/username if asked
	if (
		defined( $args{'uid_resolve'} ) &&
		$args{'uid_resolve'} &&
		defined( $self->{'uid'} )
		){
		if ( $self->{'uid'} =~ /^[0-9]+$/ ){
			eval{
				my @pwline=getpwuid( $self->{'uid'} );
				if ( defined( $pwline[0] ) ){
					$self->{'username'}=$pwline[0];
				}
			}
		}
	}elsif (
			defined( $args{'uid_resolve'} ) &&
			$args{'uid_resolve'} &&
			defined( $self->{'username'} ) &&
			( ! defined( $self->{'uid'} ) )
		){
		if ( $self->{'uid'} =~ /^[0-9]+$/ ){
			eval{
				my @pwline=getpwnam( $self->{'username'} );
				if ( defined( $pwline[2] ) ){
					$self->{'username'}=$pwline[2];
				}
			}
		}
	}

	return $self;
}

=head2 foreign_host

Returns the foreign host.

    my $f_host=$conn->foreign_host;

=cut

sub foreign_host{
	return $_[0]->{'foreign_host'};
}

=head2 foreign_port

This returns the foreign port.

    my $f_port=$conn->foreign_port;

=cut

sub foreign_port{
	return $_[0]->{'foreign_port'};
}

=head2 foreign_port_name

This returns the foreign port name.

This may potentially return undef if one is
not set/unknown.

    my $f_port=$conn->foreign_port;

=cut

sub foreign_port_name{
	return $_[0]->{'foreign_port_name'};
}

=head2 foreign_ptr

This returns the PTR for the foreign host.

If one was not supplied or if it could not be found
if resolving was enabled then undef will be returned.

    my $f_ptr=$conn-<foreign_ptr;

=cut

sub foreign_ptr{
	return $_[0]->{'foreign_ptr'};
}

=head2 local_host

Returns the local host.

    my $l_host=$conn->local_host;

=cut

sub local_host{
	return $_[0]->{'local_host'};
}

=head2 local_port

This returns the local port.

    my $l_port=$conn->local_port;

=cut

sub local_port{
	return $_[0]->{'local_port'};
}

=head2 foreign_port_name

This returns the local port name.

This may potentially return undef if one is
not set/unknown.

    my $l_port=$conn->local_port;

=cut

sub local_port_name{
	return $_[0]->{'local_port_name'};
}

=head2 proto

Returns the protocol in use by the connection.

Please note this value with vary slightly between OSes.

    my $proto=$conn->proto;

=cut

sub proto{
	return $_[0]->{'proto'};
}

=head2 state

Returns the state the connection is currently in.

Please note this value with vary slightly between OSes.

    my $state=$conn->state;

=cut

sub state{
	return $_[0]->{'state'};
}

=head2 uid

Returns the UID that has the connection.

This may not be if it was not set. Please see new
for more information.

    my $uid=$conn->uid;

=cut

sub uid{
	return $_[0]->{'uid'};
}

=head2 username

Returns the username that has the connection.

This may not be if it was not set. Please see new
for more information.

    my $username=$conn->username;

=cut

sub username{
	return $_[0]->{'username'};
}

=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-connection at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Connection>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Connection


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-Connection>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-Connection>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Net-Connection>

=item * Search CPAN

L<https://metacpan.org/release/Net-Connection>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2019 by Zane C. Bowers-Hadley.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

1; # End of Net::Connection
