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
#my $opt = {
#    link_read_nonfatal => 1,  # Set to true to ignore missing modules instead of causing an error
#    parameter => [
#        "-y", "/home/jason/graphviz-example/examples/riscv_cpu_example"
#    ]
#};

   my $opt = new Verilog::Getopt;
   $opt->parameter( "+incdir+/home/jason/graphviz-example/examples/riscv_cpu_example",
             "-y /home/jason/graphviz-example/examples/riscv_cpu_example",
             );

$Verilog::Netlist::Debug = 1;
# Prepare netlist
my $nl = new Verilog::Netlist(
   #include_open_nonfatal => 1,
   #link_read_nonfatal    => 1,
   keep_comments         => 1,
   options  => $opt
   );

my $file = '/home/jason/graphviz-example/examples/riscv_cpu_example/CPU.v';
$nl->read_file(filename => $file);
my $filename = basename($file);
my ($name, $ext) = split /\./, $filename;
my $output_filename = $name . ".json";

# Read in any sub-modules
$nl->link();
# $nl->lint();  # Optional, see docs; probably not wanted
$nl->exit_if_error();

# Create a structure to hold the module information

=comment
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
=cut

my @modules_array;

foreach my $mod ($nl->modules_sorted_level) {
    my $module_name = $mod->name;

    foreach my $cell ($mod->cells_sorted) {
        my @inputs;
        my @outputs;
        my %cell_data;
        my $inst_name = $cell->name;
        my $submod    = $cell->submodname;  # The instantiated module type 
        my $mod_name  = $cell->module->name;
        print "Module: $mod_name\n";
        print "  Instance: $inst_name ($submod)\n";

        $cell_data{instance} = $inst_name;
        $cell_data{instance_module} = $submod;
        foreach my $pin ($cell->pins_sorted) {
            my %pin_data;
            
            my $pin_name = $pin->name;        # Port name of submodule
            my $net_name  = $pin->netname;     # The signal connected to it
            my $port     = $pin->port;

            my $port_name = $port->name;
            my $pin_direction = $port->direction;
            #print "    $pin_name ($pin_direction) => $net_name\n";

            $pin_data{pin_name} = $pin_name;
            #$pin_data{pin_direction} = $pin_direction;
            $pin_data{pin_net} = $net_name;
            while (my ($key, $value) = each %pin_data) {
                print "$key: $value\n";
            }

            # \%pin_data the "\" is to keep the actual hash
            # otherwise it will break the element down and become array instead
            if ($pin_direction eq 'in') {
                push @inputs,  \%pin_data;
            } elsif ($pin_direction eq 'out') {
                push @outputs, \%pin_data;
            }
        }
        # Tie an ordered hash for clean output
        tie my %ordered_data, 'Tie::IxHash';
        %ordered_data = (
            instance => $inst_name,
            instance_module => $submod,
            input  => \@inputs,
            output => \@outputs
        );

        # Push the hashref into the array
        push @modules_array, \%ordered_data;

    }

}


# Output to JSON
open my $fh, '>', 'modules_all.json' or die $!;
print $fh to_json(\@modules_array, { pretty => 1 });
close $fh;