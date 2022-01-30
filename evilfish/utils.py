import os
import sys


def get_file_path(name, near=False):
    return os.path.join(os.path.dirname(sys.argv[0]) if near else os.path.dirname(__file__), name)

# def get_folder_path(name, near=True):
#     return os.path.join(os.path.dirname(sys.argv[0]) if near else os.path.dirname(__file__), name)
