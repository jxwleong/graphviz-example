use Verilog::Netlist;
use Verilog::Getopt;
use JSON;  # Import the JSON module
use Tie::IxHash;    # To preserve key order in the hash
use File::Basename;

# Setup options so files can be found
#my $opt = {
#    link_read_nonfatal => 1,  # Set to true to ignore missing modules instead of causing an error
#    parameter => [
#        "+incdir+verilog",  # Equivalent to -y verilog
#        "-y", "verilog"     # Verilog directory to include
#    ]
#};
my $opt = {
    link_read_nonfatal => 1,  # Set to true to ignore missing modules instead of causing an error
};


# Prepare netlist
my $nl = new Verilog::Netlist(
   include_open_nonfatal => 1,
   link_read_nonfatal    => 1,
   keep_comments         => 1
   );

my $file = '/home/jason/graphviz-example/examples/cpu.v';
$nl->read_file(filename => $file);
my $filename = basename($file);
my ($name, $ext) = split /\./, $filename;
my $output_filename = $name . ".json";

# Read in any sub-modules
$nl->link();
# $nl->lint();  # Optional, see docs; probably not wanted
$nl->exit_if_error();

# Create a structure to hold the module information

foreach my $mod ($nl->top_modules_sorted) {
    my $module_name = $mod->name;

    my @inputs;
    my @outputs;

    # https://metacpan.org/pod/Verilog::Netlist::Module#$self-%3Eports_ordered
    # Different ordering of the ports, this ordering is for same as the verilog file
    foreach my $sig ($mod->ports_ordered) {
        my $dir = $sig->direction;
        my $name = $sig->name;
        my $data_type = $sig->data_type; # Basically it shows the width if declared
        $sig->dump;

        # If it started with [ end with ]
        # For width
        # In cases with input or output reg, it will be "reg [7:0]"
        #if ($data_type =~ /^\[.*\]$/) {
        #    $name = join '', $name, $data_type;
        #}

        if ($dir eq 'in') {
            push @inputs, $name;
        } elsif ($dir eq 'out') {
            push @outputs, $name;
        }
        # You could also add `elsif ($dir eq 'inout')` if needed
    }
    my $modules_data =  {
        module => $module_name,
        input  => \@inputs,
        output => \@outputs
    };

    # Tie a hash to preserve order
    tie my %ordered_data, 'Tie::IxHash';

    %ordered_data = (
    module => $modules_data->{module},
    input  => $modules_data->{input},
    output => $modules_data->{output}
);

# Convert to JSON without sorting keys alphabetically
my $json = JSON->new->pretty->encode(\%ordered_data);

# Write JSON with enforced order
    # Convert the structure to JSON and write it to a file
    open my $fh, '>', $output_filename or die "Cannot open file for writing: $!";
    print $fh $json;
    close $fh;

    show_hier($mod, "  ", "", "");

}



# Subroutine to display hierarchy (same as your original code)
sub show_hier {
    my $mod = shift;
    my $indent = shift;
    my $hier = shift;
    my $cellname = shift;
    
    if (!$cellname) {
        $hier = $mod->name;  # top modules get the design name
    } else {
        $hier .= ".$cellname";  # append the cellname
    }

    # You can also optionally print the module and its ports here if you like:
    printf("%-45s %s\n", $indent."Module ".$mod->name);
    foreach my $sig ($mod->ports_sorted) {
        printf($indent."      %sput %s\n", $sig->direction, $sig->name);  # Optional
    }
    foreach my $cell ($mod->cells_sorted) {
        #printf($indent. "    Cell %s\n", $cell->name);  # Optional
        foreach my $pin ($cell->pins_sorted) {
            #printf($indent."     .%s(%s)\n", $pin->name, $pin->netname);  # Optional
        }
        show_hier($cell->submod, $indent."        ", $hier, $cell->name) if $cell->submod;
    }
}
