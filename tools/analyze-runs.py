#!/usr/bin/env python3
"""Read a run file or folder with the strict independent recording reader."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"verification/lib"))
import run_reader
if __name__=="__main__":
    raise SystemExit(run_reader.main(sys.argv[1:]))
