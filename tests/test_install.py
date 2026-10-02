import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('doctor_installer',Path(__file__).resolve().parents[1]/'install.py')
installer=importlib.util.module_from_spec(spec);spec.loader.exec_module(installer)

class InstallTests(unittest.TestCase):
    def test_activation_failure_retains_receipt_and_backup(self):
        with tempfile.TemporaryDirectory() as folder:
            home=Path(folder);dest=home/'plugins/nixfred.doctor';state=home/'state'
            config=home/'.config/omarchy/shell.json';config.parent.mkdir(parents=True);config.write_text('{"version":1}')
            def run(args,**kwargs):
                if args[0]=='omarchy-shell':raise subprocess.CalledProcessError(1,args)
                return subprocess.CompletedProcess(args,0)
            with patch.object(sys,'argv',['install.py','--destination',str(dest),'--enable']),patch.object(Path,'home',return_value=home),patch.dict('os.environ',{'XDG_STATE_HOME':str(state)}),patch.object(installer.subprocess,'run',side_effect=run),patch.object(installer.shutil,'which',return_value='/fake/tool'),contextlib.redirect_stdout(io.StringIO()):
                code=installer.main()
            receipt=json.loads((state/'omarchy-doctor/installation.json').read_text())
            self.assertEqual(code,1)
            self.assertFalse(receipt['enabled'])
            self.assertTrue((Path(receipt['backup'])/'shell.json').exists())
            self.assertTrue((dest/'Doctor.qml').exists())

    def test_refuses_unrelated_nonempty_directory(self):
        with tempfile.TemporaryDirectory() as folder:
            dest=Path(folder)/'unrelated';dest.mkdir();file=dest/'keep.txt';file.write_text('keep')
            with patch.object(sys,'argv',['install.py','--destination',str(dest)]),contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):installer.main()
            self.assertEqual(file.read_text(),'keep')

if __name__=='__main__':unittest.main()
