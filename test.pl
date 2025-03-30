package MyParser;
use Verilog::Parser;
@ISA = qw(Verilog::Parser);

# parse, parse_file, etc are inherited from Verilog::Parser
sub new {
    my $class = shift;
    #print "Class $class\n";
    my $self = $class->SUPER::new();
    bless $self, $class;
    return $self;
}

sub symbol {
    my $self = shift;
    my $token = shift;
    $self->{symbols}{$token}++;
}
sub report {
    my $self = shift;
    foreach my $sym (sort keys %{$self->{symbols}}) {
printf "Symbol %-30s occurs %4d times\n",
$sym, $self->{symbols}{$sym};
    }
}

package main;

my $verilog_file = 'verilog.v'; # Replace with your Verilog file

# Create a parser object
my $parser = MyParser->new();

# Parse the Verilog file
$parser->parse_file($verilog_file);
$parser->report();


