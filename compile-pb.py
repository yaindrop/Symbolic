#!/usr/bin/env python3

import os
import subprocess

proto_dir = './protobuf/'
output_dir = 'Symbolic/Protobuf/Generated/'


def clean_up_files(directory, extension):
    for filename in os.listdir(directory):
        if filename.endswith(extension):
            file_path = os.path.join(directory, filename)
            os.remove(file_path)
            print(f"Removed: {file_path}")


os.makedirs(output_dir, exist_ok=True)

clean_up_files(output_dir, '.pb.swift')

for filename in os.listdir(proto_dir):
    if not filename.endswith('.proto'):
        continue
    proto_file = os.path.join(proto_dir, filename)

    command = [
        'protoc',
        f'--swift_opt=FileNaming=DropPath',
        f'--swift_out={output_dir}',
        proto_file
    ]

    result = subprocess.run(command, capture_output=True, text=True)

    if result.returncode == 0:
        print(f"Successfully processed {filename}")
    else:
        print(f"Error processing {filename}")
        print(result.stderr)
