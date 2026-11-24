import subprocess
import sys


def test_running_main_module_prints_greeting():
    result = subprocess.run(
        [sys.executable, "-m", "src.main"], capture_output=True, text=True, check=True
    )

    assert result.stdout == "Hello from python-template\n"
