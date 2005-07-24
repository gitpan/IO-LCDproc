use 5.008001;

our $VERSION = '0.01';

####################################
package IO::LCDproc::Client;

use Carp;
use Fcntl;
use IO::Socket::INET;

sub new {
	my $proto 		= shift;
	my $class 		= ref($proto) || $proto;
	my %params	 	= @_;
	croak "No name for Client: $!" unless($params{name});
	my $self  		= {};
	$self->{name} 	= $params{name} if($params{name});
	$self->{cmd}	= "client_set name {$self->{name}}\n";
	$self->{screen}	= undef;
   bless ($self, $class);
   return $self;
}

sub add {
	my $self = shift;
	$self->{screen} = shift;
}

sub connect {
	my $self = shift;
	$self->{lcd}	= IO::Socket::INET->new(
		Proto => "tcp", PeerAddr => "localhost", PeerPort => 13666
	) or die "Cannot connect to LCDproc port: $!";
	$self->{lcd}->autoflush();
	sleep 1;
}

sub initialize {
	my $self = shift;
	my $fh = *{$self->{lcd}};
	print $fh "hello\n";
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

sub new {
	my $proto			= shift;
	my $class			= ref($proto) || $proto;
	my %params			= @_;
	croak "No name for Screen: $!" unless($params{name});
	my $self			= {};
	$self->{client}		= $params{client} || die "No Client: $!";
	$self->{name}		= $params{name} if($params{name});
	$self->{heartbeat}	= $params{heartbeat} || "on";
	$self->{cmd}		= "screen_add $self->{name}\n";
	$self->{set}		= "screen_set $self->{name} name {$self->{client}->{name}}\n";
	$self->{set}	   .= "screen_set $self->{name} heartbeat $self->{heartbeat}\n";
	$self->{widgets}	= undef;
	bless ($self, $class);
	return $self;
}

sub add {
	my $self = shift;
	foreach (@_){
		push @{$self->{widgets}}, $_;
	}
}

######################
package IO::LCDproc::Widget;

use Carp;

sub new {
	my $proto		= shift;
	my $class		= ref($proto) || $proto;
	my %params		= @_;
	croak "No name for Widget: $!" unless($params{name});
	my $self			= {};
	$self->{screen}	= $params{screen} || die "No Screen: $!";
	$self->{name}	= $params{name} if($params{name});
	$self->{align}	= $params{align} || "left";
	$self->{type}	= $params{type}  || "string";
	$self->{xPos}	= $params{xPos} || "";
	$self->{yPos}	= $params{yPos} || "";
	$self->{cmd}	= "widget_add $self->{screen}->{name} $self->{name} $self->{type}\n";
	bless ($self, $class);
	return $self;
}

sub set {
	my $self = shift;
	my $fh = *{$self->{screen}->{client}->{lcd}};
	print $fh "widget_set $self->{screen}->{name} $self->{name} $self->{xPos} $self->{yPos} {" .
		($self->{align} =~ /center/ ? $self->center($_[0]) : $_[0]) . "}\n";
}

sub center {
	my $self = shift;
	return ( " " x (10 - ( length ( $_[0] ) / 2) ) . $_[0]);
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

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

  $title->set("This is the title");
  $first->set("First Line");
  $second->set("Second line");
  $third->set("Third Line");


=head1 DESCRIPTION

Follow the example above. Pretty straight forward. You create a client, assign a screen,
add widgets, and then set the widgets.

=over 

=head2 IO::LCDproc::Client

It is the back engine of the module. It generates the connection to a ready listening server.

=back

=over

=head2 IO::LCDproc::Screen

This is the middleman between the Client and the Widgets.

=back

=over

=head2 IO::LCDproc::Widget

These are what we create to send info to the server.

=back

=head1 Methods



=head1 SEE ALSO

  LCDd L<>

=head1 AUTHOR

Juan C. Müller, E<lt>sputnik@nonetE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Juan C. Müller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
