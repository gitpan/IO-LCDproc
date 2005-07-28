use 5.008001;

our $VERSION = '0.03';
package IO::LCDproc;

=head1 NAME

	IO::LCDproc - Perl extension to connect to an LCDproc ready display.

=head1 SYNOPSIS

	use IO::LCDproc;

	my $client	= IO::LCDproc::Client->new(name => "MYNAME");
	my $screen	= IO::LCDproc::Screen->new(name => "screen", client => $client);
	my $title 	= IO::LCDproc::Widget->new(
			name => "date", type => "title", screen => $screen
			);
	my $first	= IO::LCDproc::Widget->new(
			name => "first", align => "center", screen => $screen, xPos => 1, yPos => 2
			);
	my $second	= IO::LCDproc::Widget->new(
			name => "second", align => "center", screen => $screen, xPos => 1, yPos => 3
			);
	my $third	= IO::LCDproc::Widget->new(
			name => "third", screen => $screen, xPos => 1, yPos => 4
			);
	$client->add( $screen );
	$screen->add( $title, $first, $second, $third );
	$client->connect() or die "cannot connect: $!";
	$client->initialize();

	$title->set( data => "This is the title" );
	$first->set( data => "First Line" );
	$second->set( data => "Second line" );
	$third->set( data => "Third Line" );

=head1 DESCRIPTION

	Follow the example above. Pretty straight forward. You create a client, assign a screen,
	add widgets, and then set the widgets.

=head2 IO::LCDproc::Client

	It is the back engine of the module. It generates the connection to a ready listening server.

=head3 METHODS

=cut

####################################
package IO::LCDproc::Client;

use Carp;
use Fcntl;
use IO::Socket::INET;

=item new( name => 'Client_Name' [, host => $MYHOSTNAME] [, port => $MYPORTNUMBER] )

	Constructor. Takes the following possible arguments (arguments must be given in key => value form):
	C<host>, C<port>, and C<name>. C<name> is required.

=cut

sub new {
	my $proto 		= shift;
	my $class 		= ref($proto) || $proto;
	my %params	 	= @_;
	croak "No name for Client: $!" unless($params{name});
	my $self  		= {};
	$self->{name} 	= $params{name};
	$self->{host}	= $params{host} || "localhost";
	$self->{port}	= $params{port} || "13666";
	$self->{cmd}	= "client_set name {$self->{name}}\n";
	$self->{screen}	= undef;
   bless ($self, $class);
   return $self;
}

=item add( I<SCREENREF> )

	Adds the screen that will be attached to this client.

=cut
	
sub add {
	my $self = shift;
	$self->{screen} = shift;
}

=item connect()

	Establishes connection to LCDproc server (LCDd).

=cut

sub connect {
	my $self = shift;
	$self->{lcd}	= IO::Socket::INET->new(
		Proto => "tcp", PeerAddr => "$self->{host}", PeerPort => "$self->{port}"
	) or croak "Cannot connect to LCDproc port: $!";
	$self->{lcd}->autoflush();
	sleep 1;
}

=item initialize()

	Initializes client, screen and all the widgets  with the server.

=cut

sub initialize {
	my $self = shift;
	my $fh = $self->{lcd};
	my $msgs;
	print $fh "hello\n";
	$msgs = <$fh>;
	if($msgs =~ /lcd.+wid\s+(\d+)\s+hgt\s+(\d+)/){
		$self->{width}  = $1;
		$self->{height} = $2;
	} else {
		croak "No stats reported...: $!";
	}
	fcntl( $fh, F_SETFL, O_NONBLOCK );

	print $fh $self->{cmd};
	print $fh $self->{screen}->{cmd};
	print $fh $self->{screen}->{set};
	foreach(@{$self->{screen}->{widgets}}){
		print $fh $_->{cmd};
	}
}

#####################3
package IO::LCDproc::Screen;

use Carp;

=head2 IO::LCDproc::Screen

=head3 METHODS

=item new( name => 'MYNAME', client => $CLIENTREF )

	Constructor. Allowed options:
	C<heartbeat>.
	
=cut

sub new {
	my $proto			= shift;
	my $class			= ref($proto) || $proto;
	my %params			= @_;
	croak "No name for Screen: $!" unless($params{name});
	my $self				= {};
	$self->{client}	= $params{client} || croak "No Client: $!";
	$self->{name}		= $params{name};
	$self->{heartbeat}= $params{heartbeat} || "on";
	$self->{cmd}		= "screen_add $self->{name}\n";
	$self->{set}		= "screen_set $self->{name} name {$self->{client}->{name}}\n";
	$self->{set}	  .= "screen_set $self->{name} heartbeat $self->{heartbeat}\n";
	$self->{widgets}	= undef;
	bless ($self, $class);
	return $self;
}

=item add( @WIDGETS )
	
	Adds the given widgets to this screen.

=cut

sub add {
	my $self = shift;
	foreach (@_){
		push @{$self->{widgets}}, $_;
	}
}

######################
package IO::LCDproc::Widget;

use Carp;

=head2 IO::LCDproc::Widget

=head3 METHODS

=item new( name => 'MYNAME', screen => $SCREENREF )

	Constructor. Allowed arguments:
	C<align>, C<type> (string, title, vbar, hbar, ...), C<xPos>, C<yPos>, C<data>

=cut

sub new {
	my $proto		= shift;
	my $class		= ref($proto) || $proto;
	my %params		= @_;
	croak "No name for Widget: $!" unless($params{name});
	my $self			= {};
	$self->{screen}	= $params{screen} || croak "No Screen: $!";
	$self->{name}	= $params{name};
	$self->{align}	= $params{align} || "left";
	$self->{type}	= $params{type}  || "string";
	$self->{xPos}	= $params{xPos}  || "";
	$self->{yPos}	= $params{yPos}  || "";
	$self->{data}	= $params{data} if( $params{data} );
	$self->{cmd}	= "widget_add $self->{screen}->{name} $self->{name} $self->{type}\n";
	bless ($self, $class);
	return $self;
}

=item set()

	Sets the widget to the spec'd args. They may be given on the function call or the may be
	pre specified.
	C<xPos>, C<yPos>, C<data>

=cut

sub set {
	my $self = shift;
	my %params = @_;
	$self->{xPos} = $params{xPos} if($params{xPos});
	$self->{yPos} = $params{yPos} if($params{yPos});
	$self->{data} = $params{data} if($params{data});
	my $fh = $self->{screen}->{client}->{lcd};
	print $fh "widget_set $self->{screen}->{name} $self->{name} $self->{xPos} $self->{yPos} {" .
		($self->{align} =~ /center/ ? $self->_center($self->{data}) : $self->{data}) . "}\n";
}

sub _center {
	my $self = shift;
	return ( " " x ( ($self->{screen}->{client}->{width} - length ( $_[0] ) ) / 2 ) . $_[0]);
}

=item save()

	Saves current data to be user later.

=cut

sub save {
	my $self = shift;
	$self->{saved} = $self->{data};
}

=item restore()

	Restore previously saved data.

=cut

sub restore {
	my $self = shift;
	$self->{data} = $self->{saved};
}

1;
__END__


=head1 SEE ALSO

  L<LCDd>

=head1 AUTHOR

Juan C. Muller, E<lt>jcmuller@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Juan C. Muller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
