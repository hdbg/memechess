import os
import sys

from evilfish import state


def get_file_path(name, near=False):
    if state.debug:
        return name

    return os.path.join(os.path.dirname(sys.argv[0]) if near else os.path.dirname(__file__), name)

# def get_folder_path(name, near=True):
#     return os.path.join(os.path.dirname(sys.argv[0]) if near else os.path.dirname(__file__), name)
