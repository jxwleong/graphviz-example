import re

class VerilogParser:
    def __init__(self, file_path):
        self.file_path = file_path
        self.module_name = None
        self.inputs = []
        self.outputs = []

    def strip_comments(self, line):
        return line.split('//')[0].strip()

    def parse_ports(self, line):
        parts = line.split()
        # parts[-1] means the last element in the list
        port_name = parts[-1].rstrip(',')
        return {
            'type': parts[0],
            'name': port_name
        }

    def parse_file(self):
        with open(self.file_path, 'r') as file:
            for line in file:
                line = self.strip_comments(line)
                if line.startswith('module'):
                    self.module_name = line.split()[1].split('(')[0]
                elif line.startswith('input') or line.startswith('output'):
                    port_info = self.parse_ports(line)
                    if line.startswith('input'):
                        self.inputs.append(port_info)
                    elif line.startswith('output'):
                        self.outputs.append(port_info)

    def get_module_name(self):
        return self.module_name

    def get_ports(self):
        return {
            'inputs': self.inputs,
            'outputs': self.outputs
        }


# Example usage
verilog_parser = VerilogParser('verilog.v')  # Replace 'verilog.v' with your file path
verilog_parser.parse_file()

print("Module Name:", verilog_parser.get_module_name())
print("Ports:", verilog_parser.get_ports())
