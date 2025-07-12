use Verilog::Netlist;
use Verilog::Getopt;
use Getopt::Long;

use JSON;  # Import the JSON module
use Tie::IxHash;    # To preserve key order in the hash
use File::Basename;
use File::Find;
use Data::Dumper; # To print out the hash or array
use Cwd;


my $this_file_full_path = Cwd::abs_path(__FILE__);
my $this_file_parent_dir = dirname($this_file_full_path);
my $root_dir =  dirname($this_file_parent_dir);
my $example_dir_full_path = File::Spec->catfile($root_dir, "examples");


# Skip files matching certain patterns
@verilog_files = grep {
    $_ !~ /CHIP\.v$/     # skip testbench.v
    && $_ !~ /VCPU\.v$/ 
    && $_ !~ /WIN\.v$/  
    && $_ !~ /WIN_syn\.v$/  
    #&& $_ !~ /riscv_xilinx_2r1w\.v$/  
    #&& $_ !~ /riscv_regfile\.v$/  

} @verilog_files;



my $opt = Verilog::Getopt->new(filename_expansion => 1);
# Process command-line arguments (e.g., -f file, +incdir, -y, etc.)
@ARGV = $opt->parameter(@ARGV);

# Show include directories
print "Include Directories:\n";
print "  $_\n" for @{$opt->incdir};

# Show module directories
print "Module Search Paths (-y):\n";
print "  $_\n" for @{$opt->module_dir};

# Show defined macros
print "Defines:\n";
for my $name ($opt->define_names_sorted) {
    my $val = $opt->defvalue_nowarn($name);
    print "  $name = ", (defined $val ? $val : '(undef)'), "\n";
}


# Need to move here otherwise the verilog argument will be eaten and wont work
# Example test: try to resolve "CPU.v"
my $resolved = $opt->file_path("CPU.v", "module");
print "\nResolved 'CPU.v' to: $resolved\n" if defined $resolved;


# Need to move down here otherwise it wont 
my $user_specified_file;
my $top_module_file;

GetOptions("top=s" => \$user_specified_file);
$top_module_file = $user_specified_file; 
#|| File::Spec->catfile($example_dir_full_path, "riscv_cpu_example", "CPU.v");
#$top_module_file = File::Spec->catfile($example_dir_full_path, "riscv_cpu_example", "CPU.v");
print "TOP module file: $top_module_file\n";



#$Verilog::Netlist::Debug = 1;  # Enables debug output globally

# Prepare netlist
my $nl = new Verilog::Netlist(
   #include_open_nonfatal => 1,
   #link_read_nonfatal    => 1,
   keep_comments         => 1,
   options  => $opt
   );


my $top_module_name;
open my $fh, '<', $top_module_file or die $!;
while (<$fh>) {
    if (/^\s*module\s+(\w+)/) {
        $top_module_name = $1;
        last;
    }
}
close $fh;



$nl->read_file(filename => $top_module_file);
my $filename = basename($top_module_file);
my ($name, $ext) = split /\./, $filename;
my $output_filename = $name . ".json";

# Read in any sub-modules
$nl->link();
# $nl->lint();  # Optional, see docs; probably not wanted
$nl->exit_if_error();

# --- Find the top module object ---
my $top_mod = $nl->find_module($top_module_name);
die "Top module '$top_module_name' not found!\n" unless $top_mod;

my @modules_array;

my @cells = $top_mod->cells_sorted;
if (!@cells) {
    print <<"END_MESSAGE";
Top module ($top_module_file) has no submodule instantiations (standalone).
This parsing is currently not supported.
Parsing is skipped.
END_MESSAGE

    exit;  # Exits the program immediately with status 0 (success)
}

foreach my $cell ($top_mod->cells_sorted) {
    my $inst_name = $cell->name;
    my $submod    = $cell->submodname;  # The instantiated module type 
    my $mod_name  = $cell->module->name;
    print "Module: $mod_name\n";
    print "  Instance: $inst_name ($submod)\n";

    # Skip auto-generated unnamed instances
    next if $inst_name =~ /^__unnamed_instance/;

    my @inputs;
    my @outputs;

    foreach my $pin ($cell->pins_sorted) {
        my %pin_data;
        my $pin_name = $pin->name;        # Port name of submodule
        my $net_name = $pin->netname;     # The signal connected to it
        my $port     = $pin->port;

        my $port_name = $port->name;
        my $pin_direction = $port->direction;

        $pin_data{"pin"} = $pin_name;
        $pin_data{"net"} = $net_name;
        while (my ($key, $value) = each %pin_data) {
            print "$key: $value\n";
        }

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

    push @modules_array, \%ordered_data;
}


# Mapping out the connections of the pins of each instance
# First we create a mapping of output pins associated to each instances
# Then we loop through the @modules_array to map the input and output pins together
# and create the "connection" hash.

# First step - Mapping the output pin with associated net
my %inst_output_pins_net;

for my $inst (@modules_array) {

    my @mapped_output_pins;
    my $inst_name = $inst->{"instance"};

    for my $output_pin (@{ $inst->{"output"} }) {
        my $net = $output_pin->{"net"};
       
        push @mapped_output_pins, {
            net => $net,
            pin => $output_pin->{"pin"},
            ref => join "" , $inst_name, ".", $net
        };
    }
    $inst_output_pins_net{$inst_name} = \@mapped_output_pins;
    
}
#print Dumper(%inst_output_pins_net);

# Second step - Create the "connection" between different pins of respective instances
for my $inst (@modules_array) {
    for my $input_pin (@{ $inst->{"input"} }) {
        my $input_net = $input_pin->{"net"};
        my $inst_name = $inst->{"instance"};
        
        # Looping through the output mapping
        for my $mapped_inst (keys %inst_output_pins_net) {
            for my $output_pin (@{ $inst_output_pins_net{$mapped_inst} }) {
                    my $output_net = $output_pin->{"net"};
                    my $connection_ref = $output_pin->{"ref"};

                    # Remove the data width in the name of input and output net
                    # for compare
                    (my $input_net_clean = $input_net) =~ s/\[\d+:\d+\]//;
                    (my $output_net_clean = $output_net) =~ s/\[\d+:\d+\]//;
                    if ($input_net_clean eq $output_net_clean) {
                        my %pin_connection;
                        # Need to use "->" because the $input_pin is just a reference
                        $input_pin->{"connection"} = $connection_ref;
                    }               
            }
        }
    } 
}

print Dumper(%inst_output_pins_net);

# Output to JSON
open my $fh, '>', $output_filename or die $!;
print $fh to_json(\@modules_array, { pretty => 1 });
close $fh;