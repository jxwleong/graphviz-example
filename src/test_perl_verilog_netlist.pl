use strict;
use warnings;

use Verilog::Netlist;
use Verilog::Getopt;
use Getopt::Long;
use JSON;
use Tie::IxHash;
use File::Basename;
use File::Find;
use File::Spec;
use Data::Dumper;
use Cwd;

# === Setup paths ===
my $script_path = Cwd::abs_path(__FILE__);
my $script_dir = dirname($script_path);
my $root_dir = dirname($script_dir);
my $example_dir = File::Spec->catfile($root_dir, "examples");

# === Parse options ===
my $opt = Verilog::Getopt->new(filename_expansion => 1);
@ARGV = $opt->parameter(@ARGV);

# === Print command-line arguments ===
print "Include Directories:\n";
print "  $_\n" for @{$opt->incdir};

print "Module Search Paths (-y):\n";
print "  $_\n" for @{$opt->module_dir};

print "Defines:\n";
for my $name ($opt->define_names_sorted) {
    my $val = $opt->defvalue_nowarn($name);
    print "  $name = ", (defined $val ? $val : '(undef)'), "\n";
}

# === Get top file ===
my $top_file;
GetOptions("top=s" => \$top_file);
die "Error: Please specify a top file using --top <file.v>\n" unless $top_file;
print "Top module file: $top_file\n";

# === Resolve file path ===
my $resolved = $opt->file_path($top_file, "module");
print "Resolved '$top_file' to: $resolved\n" if defined $resolved;

# === Extract top module name ===
my $top_module_name;
open my $fh, '<', $top_file or die "Cannot open $top_file: $!";
while (<$fh>) {
    if (/^\s*module\s+(\w+)/) {
        $top_module_name = $1;
        last;
    }
}
close $fh;
die "Could not find top module in file!\n" unless $top_module_name;

# === Netlist preparation ===
my $netlist = Verilog::Netlist->new(
    keep_comments => 1,
    options       => $opt,
);
$netlist->read_file(filename => $top_file);
$netlist->link();
$netlist->exit_if_error();

# === Locate top module ===
my $top_module = $netlist->find_module($top_module_name)
    or die "Top module '$top_module_name' not found in netlist.\n";

my @instances;
my @cells = $top_module->cells_sorted;

unless (@cells) {
    warn <<"MSG";
Top module ($top_file) has no submodule instantiations.
Skipping parsing.
MSG
    exit;
}

# === Collect instance data ===
foreach my $cell (@cells) {
    my $inst_name = $cell->name;
    my $submod    = $cell->submodname;
    next if $inst_name =~ /^__unnamed_instance/;

    print "Module: ", $cell->module->name, "\n";
    print "  Instance: $inst_name ($submod)\n";

    my (@inputs, @outputs);

    for my $pin ($cell->pins_sorted) {
        my %pin_data = (
            pin => $pin->name,
            net => $pin->netname,
        );

        my $dir = $pin->port->direction;
        push @{ $dir eq 'in' ? \@inputs : \@outputs }, \%pin_data;

        print "$_: $pin_data{$_}\n" for keys %pin_data;
    }

    tie my %inst_data, 'Tie::IxHash';
    %inst_data = (
        instance         => $inst_name,
        instance_module  => $submod,
        input            => \@inputs,
        output           => \@outputs
    );
    push @instances, \%inst_data;
}

# === Map output pins to nets ===
my %output_net_map;
for my $inst (@instances) {
    my $name = $inst->{instance};
    my @mapped;
    for my $pin (@{ $inst->{output} }) {
        push @mapped, {
            net => $pin->{net},
            pin => $pin->{pin},
            ref => "$name.$pin->{net}"
        };
    }
    $output_net_map{$name} = \@mapped;
}

# === Create connection references ===
for my $inst (@instances) {
    for my $input (@{ $inst->{input} }) {
        my $input_net = $input->{net};
        (my $clean_input = $input_net) =~ s/\[\d+:\d+\]//;

        for my $other (keys %output_net_map) {
            for my $out (@{ $output_net_map{$other} }) {
                (my $clean_output = $out->{net}) =~ s/\[\d+:\d+\]//;
                if ($clean_input eq $clean_output) {
                    $input->{connection} = $out->{ref};
                }
            }
        }
    }
}

# === Dump connection map (for debugging) ===
#print Dumper(\%output_net_map);

# === Write JSON output ===
my $base = basename($top_file);
$base =~ s/\.\w+$//;
my $json_file = "$base.json";

open my $out_fh, '>', $json_file or die "Cannot write to $json_file: $!";
print $out_fh to_json(\@instances, { pretty => 1 });
close $out_fh;

print "Output written to $json_file\n";
