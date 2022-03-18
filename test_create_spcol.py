"""Test create_spec_coll.py
"""

import run_create_spcol
import getpass
import os
import tempfile
from unittest.mock import patch, call
import json
import pytest


USER_ID = os.getlogin()

CONFIG_DICT = {
    "email_to": f"{USER_ID}@scharp.org",
    "email_from": f"{USER_ID}@scharp.org",
    "sas_program": "create_spcol.sas",
    "path_code": "./",
    "path_protocol_macros": "./macros/",
    "path_protocol_config": "./protocol_specimen_config/",
    "path_log": "/scharp/devel/testing/ldo_testing/test_create_spcol/log/",
    "path_outdata": "/scharp/devel/testing/ldo_testing/test_create_spcol/output/",
    "path_fmtlib": "/trials/LabDataOps/common/sas_formats/",
    "protocol_configs": {
        "idcrc": {
            "21_0012": {
                "parameters": {
                    "enrds": "enr_idcrc_003",
                    "retds": "exp_idrcr_003",
                }
            }
        },
        "covpn": {
            "5001": {
                "parameters": {
                    "enrds": "enr_covpn_5001",
                    "retds": "exp_covpn_5001",
                }
            },
        },
        "hvtn": {
            "123": {
                "parameters": {
                    "enrds": "enr_hvtn_123",
                    "retds": "exp_hvtn_123",
                }
            },
        },
        "mtn": {
            "034": {
                "parameters": {
                    "enrds": "enr_mtn_034",
                    "retds": "ret_mtn_034",
                }
            },
        },
    },
}


class TestMain:
    def test_run_create_spcol(self):
        RUN_PROTOCOL_DICT = run_create_spcol.read_json_config(
            "./test_spcol_config.json"
        )
        CONFIG_DICT["protocol_configs"] = RUN_PROTOCOL_DICT
        run_create_spcol.main(CONFIG_DICT)
        for net in CONFIG_DICT["protocol_configs"]:
            for prot in CONFIG_DICT["protocol_configs"][net]:
                spcol_dataset_name = f"spec_{net}_{prot}.sas7bdat"
                spcol_log_name = f"spec_{net}_{prot}.log"

                assert (
                    os.path.exists(
                        f"{CONFIG_DICT['path_outdata']}/{spcol_dataset_name}"
                    )
                    == True
                )

                with open(f"{CONFIG_DICT['path_log']}/{spcol_log_name}") as f:
                    assert not "ERROR:" in f.read()

    def test_files_created(self):
        """Check for creation of specimen collection sas datasets"""

        with tempfile.TemporaryDirectory() as tempdir:

            spcol_file_names = []
            for net in CONFIG_DICT["protocol_configs"]:
                for prot in CONFIG_DICT["protocol_configs"][net]:
                    spcol_file_names += [f"spec_{net}_{prot}.sas7bdat"]

            CONFIG_DICT["path_outdata"] = tempdir
            run_create_spcol.main(CONFIG_DICT)

            for spec_file in spcol_file_names:
                filepath_spcol = os.path.join(tempdir, spec_file)

                assert os.path.isfile(filepath_spcol)


class TestJsonOutput:
    def test_read_json_config_type(self, tmpdir):
        filepath = os.path.join(tmpdir, "sample.json")
        with open(filepath, "w") as sample_json_file:
            json.dump(CONFIG_DICT, sample_json_file)
        output = run_create_spcol.read_json_config(filepath)
        assert isinstance(output, dict)

    def test_read_json_config_output(self, tmpdir):
        filepath = os.path.join(tmpdir, "sample.json")
        with open(filepath, "w") as sample_json_file:
            json.dump(CONFIG_DICT, sample_json_file)
        output = run_create_spcol.read_json_config(filepath)

        assert output == CONFIG_DICT


class TestJsonNotExist:
    def test_json_config_filedonotexist(self, tmpdir):
        with pytest.raises(
            FileNotFoundError,
            match=r"\[Errno 2\] No such file or directory\: '\.\/donotexist.json'",
        ):
            run_create_spcol.read_json_config("./donotexist.json")


class TestEmail:

    email_addr = "fakeid@scharp.org"

    @patch(
        "smtplib.SMTP.sendmail",
        return_value=None,
    )
    def test_status_email(self, mock_smtplib):
        output = run_create_spcol.send_status_email(
            email_to=TestEmail.email_addr,
            email_from=TestEmail.email_addr,
            email_subject="import_ldms - Program Output",
            email_body="testing",
        )

        mock_smtplib.assert_called_once_with(
            "fakeid@scharp.org",
            "fakeid@scharp.org",
            (
                'Content-Type: text/plain; charset="us-ascii"\nMIME-Version: 1.0\nCon'
                "tent-Transfer-Encoding: 7bit\nSubject: import_ldms - Program "
                "Output\nFrom: fakeid@scharp.org\nTo: fakeid@scharp.org\n\ntesting"
            ),
        )
