import subprocess
import datetime
import plistlib
import os


def write_to_info(version):
    path = os.path.join(os.path.abspath(os.path.dirname(os.path.dirname(__file__))), "Info.plist")

    with open(path, 'rb') as f:
        contents = plistlib.load(f)

    if not contents:
        exit(-1)
    
    branch = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"]).strip().decode()
    commit = subprocess.check_output(["git", "describe", "--always"]).strip().decode()

    contents["coreVersion"] = version
    contents["gitBranch"] = branch
    contents["gitCommit"] = commit
    contents["buildTime"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    with open(path, 'wb') as f:
        plistlib.dump(contents, f, sort_keys=False)
