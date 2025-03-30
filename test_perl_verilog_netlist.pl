use Verilog::Netlist;
use Verilog::Getopt;
use JSON;  # Import the JSON module

# Setup options so files can be found
my $opt = new Verilog::Getopt;
$opt->parameter("+incdir+verilog", "-y", "verilog");

# Prepare netlist
my $nl = new Verilog::Netlist(options => $opt);

foreach my $file ('/home/jason/graphviz-example/verilog.v') {
    $nl->read_file(filename => $file);
}

# Read in any sub-modules
$nl->link();
# $nl->lint();  # Optional, see docs; probably not wanted
$nl->exit_if_error();

# Create a structure to hold the module information
my $modules_info = {};

foreach my $mod ($nl->top_modules_sorted) {
    my $module_name = $mod->name;
    $modules_info->{$module_name} = [];

    foreach my $sig ($mod->ports_sorted) {
        # Add port information (name and direction) to the module
        push @{ $modules_info->{$module_name} }, {
            name => $sig->name,
            direction => $sig->direction
        };
    }
   show_hier($mod, "  ", "", "");

}

# Convert the structure to JSON and write it to a file
open my $fh, '>', 'module_ports.json' or die "Cannot open file for writing: $!";
print $fh to_json($modules_info, { pretty => 1 });
close $fh;

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
